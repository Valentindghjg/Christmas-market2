--!strict
-- Server bootstrap. Every business mutation enters through the validated RemoteFunction
-- or a server-side ProximityPrompt that is checked exactly like a remote call.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))
local SaveProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SaveProfile"))
local PersistenceService = require(script.Parent.Services:WaitForChild("PersistenceService"))
local CompanyStateService = require(script.Parent.Services:WaitForChild("CompanyStateService"))
local InviteCodeService = require(script.Parent.Services:WaitForChild("InviteCodeService"))
local PlotService = require(script.Parent.Services:WaitForChild("PlotService"))
local SaveLocatorService = require(script.Parent.Services:WaitForChild("SaveLocatorService"))
local SaveSlotService = require(script.Parent.Services:WaitForChild("SaveSlotService"))
local WorldService = require(script.Parent.Services:WaitForChild("WorldService"))

local SHUTDOWN_WAIT_SECONDS = 25

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local businessAction = remotes:FindFirstChild("BusinessAction") or Instance.new("RemoteFunction")
businessAction.Name = "BusinessAction"
businessAction.Parent = remotes

-- Save-slot actions (CM2-S1): validated and rate-limited by SaveSlotService.
local saveAction = remotes:FindFirstChild("SaveAction") or Instance.new("RemoteFunction")
saveAction.Name = "SaveAction"
saveAction.Parent = remotes

-- One-way, server-to-client notices; clients cannot send anything through it.
local notify = remotes:FindFirstChild("Notify") or Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes

local function tell(player: Player, key: string, ...: number)
	notify:FireClient(player, { key = key, args = { ... } })
end

-- Studio playtests can force customer conversions, fast-forward the business clock and
-- pause random customers through StudioTestHook (below). Outside Studio all three stay
-- at their neutral values.
local clockOffset = 0
local forcedRolls = 0
local customersPaused = false

local function businessClock(): number
	return os.time() + clockOffset
end

local function businessRoll(): number
	if forcedRolls > 0 then
		forcedRolls -= 1
		return 0
	end
	return math.random()
end

local persistence = PersistenceService.new()
local companies = CompanyStateService.new(persistence, businessClock, businessRoll)
local plots = PlotService.new(config.PersonalPlotIds)
WorldService.build()

-- Save IDs: `<userId>_<16 lowercase hex>` (GUID chars 17-32), at most 36 chars, so every
-- save key fits the 50-char DataStore key limit (CM2-S1 Fix round 2, R1).
local function newSaveId(userId: number): string
	return SaveProfile.newSaveId(userId, HttpService:GenerateGUID(false))
end

-- Names are filtered at submission; the broadcast result must equal the name.
local function filterName(userId: number, text: string): (boolean, string?)
	if not Players:GetPlayerByUserId(userId) then
		return false, "FilterUnavailable"
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(filtered) ~= "string" then
		return false, "FilterUnavailable"
	end
	return true, filtered
end

local function teleportForFreePlot(userId: number, data): (boolean, string?)
	if RunService:IsStudio() then
		return false, "TeleportUnavailable"
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return false, "NoPlayer"
	end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ cm2NoFreePlot = data })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

-- One server per save (CM2-S3): the save-to-server map. Studio uses its own map, so Studio
-- entries never mix with live ones.
local locatorMap = MemoryStoreService:GetHashMap(
	if RunService:IsStudio() then config.Saves.LocatorMapName .. "_Studio" else config.Saves.LocatorMapName
)
local locator = SaveLocatorService.new(
	locatorMap,
	if game.JobId ~= "" then game.JobId else "studio",
	game.PlaceId,
	os.time,
	task.wait
)

-- Players sent to another server by Save.Teleport; TeleportInitFailed tells them apart from
-- the S1 no-free-plot teleport.
local joinTeleports: { [number]: boolean } = {}
local teleportErrorSeq = 0

-- Moves a player into the public server (JobId) that plays a save. Studio cannot teleport.
local function teleportToServer(userId: number, placeId: number, jobId: string, data): (boolean, string?)
	if RunService:IsStudio() then
		return false, "TeleportUnavailable"
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return false, "TeleportFailed"
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = jobId
	options:SetTeleportData({ cm2Join = data })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, { player }, options)
	if not ok then
		warn(string.format("[ChristmasMarket2] teleport to %s failed for %d: %s", jobId, userId, tostring(err)))
		return false, "TeleportFailed"
	end
	joinTeleports[userId] = true
	return true, nil
end

-- Invite codes for co-op saves (CM2-S2): 5 digits without a leading zero.
local rng = Random.new()
local invites = InviteCodeService.new(
	DataStoreService:GetDataStore(InviteCodeService.STORE_NAME),
	os.time,
	task.wait,
	function()
		return rng:NextInteger(config.Saves.InviteCodeMin, config.Saves.InviteCodeMax)
	end
)

-- Roblox usernames for co-op views (they need no text filter). A failed lookup is cached as
-- false, so it is not retried for every request.
local userNames: { [number]: string | false } = {}
local function userName(userId: number): string?
	local player = Players:GetPlayerByUserId(userId)
	if player then
		userNames[userId] = player.Name
		return player.Name
	end
	local cached = userNames[userId]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and type(name) == "string" then
		userNames[userId] = name
		return name
	end
	userNames[userId] = false
	return nil
end

local saveSlots = SaveSlotService.new({
	profileStore = DataStoreService:GetDataStore(SaveSlotService.PROFILE_STORE_NAME),
	persistence = persistence,
	companies = companies,
	plots = plots,
	invites = invites,
	userName = userName,
	-- Real time, so business-clock offsets never bypass the save-action rate limits.
	clock = os.time,
	wait = task.wait,
	newSaveId = newSaveId,
	filterName = filterName,
	teleport = teleportForFreePlot,
	locator = locator,
	teleportToServer = teleportToServer,
})

-- Teammate finder (CM2-S3): open finder panels refetch when the listings change.
saveSlots:setFinderHandler(function()
	local revision = ReplicatedStorage:GetAttribute("FinderRevision")
	ReplicatedStorage:SetAttribute("FinderRevision", (if type(revision) == "number" then revision else 0) + 1)
end)

local function companyIdFor(userId: number): string?
	return saveSlots:activeCompanyId(userId)
end

local function effectiveParking(spaces: number): number
	return math.max(config.Customers.BaseParkingSpaces, spaces)
end

-- Displayed trees follow authoritative placements, including NPC sales.
companies:setPlacementsChangedHandler(function(companyId: string, placements, mediumPrices)
	local plotId = plots:getPlot(companyId)
	if plotId then
		WorldService.syncDisplayedTrees(plotId, placements, mediumPrices)
	end
end)

-- Customer orders: prompts are validated like remote calls before any mutation.
local orderCallbacks
local performOrderAction

-- The carried-tree visual follows the authoritative order state.
local function syncCarriedVisual(player: Player, summary)
	local character = player.Character
	if not character then
		return
	end
	local carried = character:FindFirstChild("CarriedTree")
	local carriedNumber = carried and carried:GetAttribute("OrderNumber")
	if carriedNumber == nil then
		return
	end
	for _, order in ipairs(if type(summary) == "table" then summary.orders else {}) do
		if order.orderNumber == carriedNumber and order.carried then
			return
		end
	end
	WorldService.detachCarriedTree(character)
end

companies:setCustomerOrdersChangedHandler(function(companyId: string, summary)
	local plotId = plots:getPlot(companyId)
	if plotId then
		WorldService.syncCustomerOrders(plotId, summary, orderCallbacks)
	end
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			syncCarriedVisual(player, summary)
		end
	end
end)

-- CM2-R3: a live save that stops accepting mutations tells its players why.
companies:setSessionFailedHandler(function(companyId: string, code: string)
	warn(string.format("[ChristmasMarket2] %s stopped: %s", companyId, code))
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("CompanyReady", false)
			player:SetAttribute("CompanyError", code)
		end
	end
end)

-- Server-side reach check for order interactions (prompts and remote calls alike).
local function withinReach(player: Player, target: BasePart?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (target and root and root:IsA("BasePart")) then
		return false
	end
	return (root.Position - target.Position).Magnitude <= config.Customers.InteractDistance
end

local function orderReachAllowed(player: Player, action: string, payload): boolean
	local plotId = player:GetAttribute("PlotId")
	if type(plotId) ~= "string" or type(payload) ~= "table" then
		return false
	end
	-- Untrusted payloads reach this check before protocol validation.
	if action == Protocol.Actions.OrderCarry then
		return type(payload.orderNumber) == "number"
			and withinReach(player, WorldService.findOrderTarget(plotId, "Tree", payload.orderNumber))
	end
	if action == Protocol.Actions.OrderLoad then
		return type(payload.carNumber) == "number"
			and withinReach(player, WorldService.findOrderTarget(plotId, "Car", payload.carNumber))
	end
	return true
end

local ORDER_ERROR_KEYS = {
	HandsFull = "handsFull",
	AlreadyCarried = "alreadyCarried",
	OutOfReach = "outOfReach",
}

local function afterOrderAction(player: Player, action: string, response, payload)
	if not response.ok then
		if response.errorCode == "WrongCar" and type(payload) == "table" then
			tell(player, "wrongCar", payload.orderNumber, payload.orderNumber)
		elseif ORDER_ERROR_KEYS[response.errorCode] then
			tell(player, ORDER_ERROR_KEYS[response.errorCode])
		end
		return
	end
	local character = player.Character
	if action == Protocol.Actions.OrderCarry and character and type(response.data) == "number" then
		WorldService.attachCarriedTree(character, response.data)
	elseif action == Protocol.Actions.OrderLoad or action == Protocol.Actions.OrderRelease then
		WorldService.detachCarriedTree(character)
		if action == Protocol.Actions.OrderLoad and type(response.data) == "table" then
			tell(player, "orderComplete", response.data.orderNumber)
		end
	end
end

performOrderAction = function(player: Player, action: string, payload)
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local companyId = companyIdFor(player.UserId)
	if companyId == nil then
		return
	end
	if not orderReachAllowed(player, action, payload) then
		tell(player, "outOfReach")
		return
	end
	-- Request IDs are persisted, so they must stay unique across servers and restarts.
	local response = companies:handle(companyId, player.UserId, {
		version = Protocol.VERSION,
		requestId = "prompt_" .. HttpService:GenerateGUID(false),
		action = action,
		payload = payload,
	})
	afterOrderAction(player, action, response, payload)
end

orderCallbacks = {
	carry = function(player: Player, orderNumber: number)
		performOrderAction(player, Protocol.Actions.OrderCarry, { orderNumber = orderNumber })
	end,
	load = function(player: Player, carNumber: number)
		-- The saved state knows which order the player carries; the car supplies its number.
		local companyId = companyIdFor(player.UserId)
		if companyId == nil then
			return
		end
		local orderNumber = companies:getCarriedOrderNumber(companyId, player.UserId)
		if orderNumber == nil then
			return
		end
		performOrderAction(player, Protocol.Actions.OrderLoad, { orderNumber = orderNumber, carNumber = carNumber })
	end,
}

local function spawnAtClaimedPlot(player: Player, character: Model)
	local plotId = player:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return
	end
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plotsFolder = world and world:FindFirstChild("Plots")
	local plot = plotsFolder and plotsFolder:FindFirstChild(plotId)
	local spawn = plot and plot:FindFirstChild("Spawn")
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if spawn and spawn:IsA("BasePart") and root and root:IsA("BasePart") then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- A failing pass is logged and retried next interval instead of killing its loop.
local function every(seconds: number, label: string, pass: () -> (boolean, number, number))
	task.spawn(function()
		while true do
			task.wait(seconds)
			local called, ok, _, failures = pcall(pass)
			if not called then
				warn(string.format("[ChristmasMarket2] %s pass errored: %s", label, tostring(ok)))
			elseif not ok then
				warn(string.format("[ChristmasMarket2] %s failed for %d company sessions", label, failures))
			end
		end
	end)
end

every(config.SaveFlushSeconds, "save flush", function()
	return companies:flushDirty()
end)
every(config.CustomerVisitIntervalSeconds, "customer visits", function()
	if customersPaused then
		return true, 0, 0
	end
	return companies:simulateCustomerVisits()
end)
every(config.CustomerVisitIntervalSeconds, "customer orders", function()
	return companies:serviceCustomerOrdersAll()
end)
every(config.CustomerVisitIntervalSeconds, "delivery reconciliation", function()
	return companies:reconcileDeliveriesAll()
end)
every(config.CustomerVisitIntervalSeconds, "lot-worker unload", function()
	return companies:autoUnloadDeliveriesAll()
end)
every(config.CustomerVisitIntervalSeconds, "supplier stock refresh", function()
	return companies:refreshSupplierStockAll()
end)
every(config.AutoPricingIntervalSeconds, "automatic pricing", function()
	return companies:applyAutoPricingAll()
end)
every(config.Saves.LocatorRenewSeconds, "save locator", function()
	return saveSlots:renewLocations()
end)

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

-- Mirrors a loaded company into its plot: stand, lot, parking, displayed trees and orders.
local function syncPlotWorld(plotId: string, companyId: string, state)
	WorldService.applyHQVisual(plotId, state.progression.hqTier)
	WorldService.applyLotExpansionVisual(plotId, state.progression.lotExpansion)
	WorldService.applyParkingVisual(plotId, effectiveParking(state.progression.parkingSpaces))
	WorldService.syncDisplayedTrees(plotId, state.layout.placements, state.mediumPrices)
	WorldService.syncCustomerOrders(plotId, companies:getCustomerOrders(companyId), orderCallbacks)
end

local function clearPlotVisuals(plotId: string)
	WorldService.applyHQVisual(plotId, nil)
	WorldService.applyLotExpansionVisual(plotId, 0)
	WorldService.applyParkingVisual(plotId, 0)
	WorldService.syncDisplayedTrees(plotId, {})
	WorldService.syncCustomerOrders(plotId, nil, nil)
end

-- A played save mirrors into its plot and marks the player ready. A player joining a live
-- shared session gets no state: its plot already shows the save.
saveSlots:setActivationHandlers(function(userId: number, companyId: string, plotId: string, state, view)
	if state then
		syncPlotWorld(plotId, companyId, state)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute("PlotId", plotId)
		player:SetAttribute("ActiveSaveId", string.match(companyId, "^save:(.+)$"))
		player:SetAttribute("ActiveSaveRole", view.role)
		player:SetAttribute("ActiveSaveSize", view.size)
		-- The save name goes to owners only (filter rule, CM2-S2).
		player:SetAttribute("ActiveSaveName", view.saveName)
		player:SetAttribute("ActiveSaveOwnerName", view.ownerName)
		player:SetAttribute("CompanyError", nil)
		player:SetAttribute("CompanyReady", true)
		if player.Character then
			task.spawn(spawnAtClaimedPlot, player, player.Character)
		end
	end
end, function(userId: number, _companyId: string, plotId: string?, plotReleased: boolean)
	if plotReleased and plotId then
		-- The next claimant must not inherit the previous owner's stand, lot or trees.
		clearPlotVisuals(plotId)
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		WorldService.detachCarriedTree(player.Character)
		player:SetAttribute("CompanyReady", false)
		player:SetAttribute("PlotId", nil)
		player:SetAttribute("ActiveSaveId", nil)
		player:SetAttribute("ActiveSaveName", nil)
		player:SetAttribute("ActiveSaveRole", nil)
		player:SetAttribute("ActiveSaveSize", nil)
		player:SetAttribute("ActiveSaveOwnerName", nil)
	end
end)

-- Co-op teams (CM2-S2): a removed member learns why; a team change refreshes open team panels.
saveSlots:setTeamHandlers(function(userId: number, _saveId: string)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player:SetAttribute("CompanyError", "RemovedFromSave")
	end
end, function(companyId: string, size: string?)
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			if size ~= nil then
				player:SetAttribute("ActiveSaveSize", size)
			end
			local revision = player:GetAttribute("TeamRevision")
			player:SetAttribute("TeamRevision", (if type(revision) == "number" then revision else 0) + 1)
		end
	end
end)

-- Untrusted `Save.*` requests from the save picker.
local function handleSaveAction(player: Player, request)
	local response = saveSlots:handle(player.UserId, request)
	local action = type(request) == "table" and request.action or nil
	if response.ok and action == Protocol.SaveActions.Rename and type(response.data) == "table" then
		if response.data.saveId == player:GetAttribute("ActiveSaveId") then
			player:SetAttribute("ActiveSaveName", response.data.name)
		end
	elseif not response.ok and action == Protocol.SaveActions.Play then
		if saveSlots:activeCompanyId(player.UserId) == nil then
			player:SetAttribute("CompanyError", response.errorCode)
		end
	end
	return response
end
saveAction.OnServerInvoke = handleSaveAction

-- A teleport for a free plot carries the save to play on arrival (validated here).
local function noFreePlotJoin(player: Player): (string?, number?)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" or joinData.SourcePlaceId ~= game.PlaceId then
		return nil, nil
	end
	local teleportData = joinData.TeleportData
	local data = type(teleportData) == "table" and teleportData.cm2NoFreePlot or nil
	if type(data) ~= "table" or not SaveProfile.isSaveId(data.saveId) then
		return nil, nil
	end
	local attempt = data.attempt
	if
		type(attempt) ~= "number"
		or attempt ~= math.floor(attempt)
		or attempt < 1
		or attempt > config.Saves.MaxPlotTeleports
	then
		return nil, nil
	end
	return data.saveId, attempt
end

-- A Save.Teleport arrival (CM2-S3). Teleport data is client-routed and untrusted: only a
-- valid save ID and an optional valid code pass, and arrive() checks both again.
local function crossServerJoin(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" or joinData.SourcePlaceId ~= game.PlaceId then
		return nil
	end
	local teleportData = joinData.TeleportData
	local data = type(teleportData) == "table" and teleportData.cm2Join or nil
	if type(data) ~= "table" or not SaveProfile.isSaveId(data.saveId) then
		return nil
	end
	if data.code ~= nil and not BusinessState.isInviteCode(data.code) then
		return nil
	end
	return { saveId = data.saveId, code = data.code }
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- A respawn drops the carried tree back at the pickup spot.
		local companyId = companyIdFor(player.UserId)
		if companyId then
			companies:releaseCarried(companyId, player.UserId)
		end
		spawnAtClaimedPlot(player, character)
	end)
	player:SetAttribute("CompanyReady", false)
	local profile, profileError = saveSlots:openProfile(player.UserId)
	if not isInGame(player) then
		return
	end
	if not profile then
		player:SetAttribute("ProfileReady", false)
		player:SetAttribute("CompanyError", profileError)
		warn(string.format("[ChristmasMarket2] profile load failed for %d: %s", player.UserId, tostring(profileError)))
		return
	end
	player:SetAttribute("ProfileReady", true)
	local arrival = crossServerJoin(player)
	if arrival then
		local arrived, arriveError = saveSlots:arrive(player.UserId, arrival)
		if not arrived and isInGame(player) then
			player:SetAttribute("CompanyError", arriveError)
		end
		return
	end
	local saveId, attempt = noFreePlotJoin(player)
	if saveId then
		local played, playError = saveSlots:play(player.UserId, saveId, { attempt = attempt })
		if not played and isInGame(player) then
			player:SetAttribute("CompanyError", playError)
		end
	end
	-- Otherwise the save picker chooses; the character uses the world spawn until then.
end

local TELEPORT_RESULT_ERRORS = {
	[Enum.TeleportResult.GameFull] = "ServerFull",
	[Enum.TeleportResult.GameEnded] = "SaveServerGone",
	[Enum.TeleportResult.GameNotFound] = "SaveServerGone",
}

TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult)
	-- Amendment A1.4: a teleport already in progress changes nothing.
	if result == Enum.TeleportResult.IsTeleporting then
		return
	end
	if joinTeleports[player.UserId] then
		joinTeleports[player.UserId] = nil
		local code = TELEPORT_RESULT_ERRORS[result] or "TeleportFailed"
		teleportErrorSeq += 1
		player:SetAttribute("SaveTeleportError", code .. ":" .. teleportErrorSeq)
		return
	end
	player:SetAttribute("CompanyError", "NoFreePlot")
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	joinTeleports[player.UserId] = nil
	local ok, errorCode = saveSlots:leave(player.UserId, true)
	if not ok then
		warn(string.format("[ChristmasMarket2] save unload failed for %d: %s", player.UserId, tostring(errorCode)))
	end
	companies:forgetUser(player.UserId)
end)

local ORDER_REACH_ACTIONS = {
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
}

local function handleBusinessAction(player: Player, request)
	if player:GetAttribute("CompanyReady") ~= true then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	-- Order interactions need the player next to the tree or car, whichever channel is used.
	local action = type(request) == "table" and request.action
	if
		type(action) == "string"
		and ORDER_REACH_ACTIONS[action]
		and not orderReachAllowed(player, action, request.payload)
	then
		return { ok = false, errorCode = "OutOfReach" }
	end
	local companyId = companyIdFor(player.UserId)
	if companyId == nil then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	local response = companies:handle(companyId, player.UserId, request)
	if not response.ok then
		return response
	end
	-- handle() succeeded, so request passed validation and is a table.
	afterOrderAction(player, request.action, response, request.payload)
	local plotId = player:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return response
	end
	if request.action == Protocol.Actions.ProgressionBuyHQ then
		WorldService.applyHQVisual(plotId, response.data)
	elseif request.action == Protocol.Actions.ProgressionBuyLotExpansion and type(response.data) == "number" then
		WorldService.applyLotExpansionVisual(plotId, response.data)
	elseif request.action == Protocol.Actions.ProgressionBuyParking and type(response.data) == "number" then
		WorldService.applyParkingVisual(plotId, effectiveParking(response.data))
	end
	return response
end
businessAction.OnServerInvoke = handleBusinessAction

-- Studio-only test instrument for reproducible playtests (docs/TEST_PLAN.md). The hook is
-- never created on live servers (the release build omits StudioTestService), and clients
-- cannot reach a ServerStorage BindableFunction.
if RunService:IsStudio() then
	local module = script.Parent.Services:FindFirstChild("StudioTestService")
	if module then
		require(module).install({
			companies = companies,
			plots = plots,
			saveSlots = saveSlots,
			orderCallbacks = orderCallbacks,
			companyIdFor = companyIdFor,
			handleBusinessAction = handleBusinessAction,
			handleSaveAction = handleSaveAction,
			persistenceStoreName = PersistenceService.STORE_NAME,
			locatorMap = locatorMap,
			locatorKey = SaveLocatorService.keyFor,
			syncPlotWorld = syncPlotWorld,
			clearPlotVisuals = clearPlotVisuals,
			businessClock = businessClock,
			advanceClock = function(seconds: number): number
				clockOffset += seconds
				return clockOffset
			end,
			setForcedRolls = function(count: number)
				forcedRolls = count
			end,
			setCustomersPaused = function(paused: boolean)
				customersPaused = paused
			end,
		})
	else
		warn("[ChristmasMarket2] StudioTestService missing; StudioTestHook not installed")
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	-- Refuse new save work first, so no save can start loading after this point.
	saveSlots:beginShutdown()
	-- Unload in parallel: sequential saves with retry backoff can exceed the shutdown budget.
	-- activeUserIds() covers every active save, including the Studio shadow player.
	for _, userId in saveSlots:activeUserIds() do
		task.spawn(pcall, saveSlots.leave, saveSlots, userId, true)
	end
	-- pendingCount() also covers final leaves already past activeUserIds() (PlayerRemoving)
	-- and every save action in flight.
	local waited = 0
	while saveSlots:pendingCount() > 0 and waited < SHUTDOWN_WAIT_SECONDS do
		waited += task.wait(0.1)
	end
end)

print(string.format("[ChristmasMarket2] Server booted. Starting cash: %d", config.StartingCash))
