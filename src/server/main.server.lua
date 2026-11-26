--!strict
-- Server bootstrap. Every business mutation enters through the validated RemoteFunction
-- or a server-side ProximityPrompt that is checked exactly like a remote call.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))
local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))
local SaveProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SaveProfile"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local PersistenceService = require(script.Parent.Services:WaitForChild("PersistenceService"))
local CompanyStateService = require(script.Parent.Services:WaitForChild("CompanyStateService"))
local CustomerNpcService = require(script.Parent.Services:WaitForChild("CustomerNpcService"))
local CustomerNpcWorld = require(script.Parent.Services:WaitForChild("CustomerNpcWorld"))
local InviteCodeService = require(script.Parent.Services:WaitForChild("InviteCodeService"))
local LeaderboardService = require(script.Parent.Services:WaitForChild("LeaderboardService"))
local MonetizationService = require(script.Parent.Services:WaitForChild("MonetizationService"))
local NpcAvatar = require(script.Parent.Services:WaitForChild("NpcAvatar"))
local PlotService = require(script.Parent.Services:WaitForChild("PlotService"))
local PurchaseLedgerService = require(script.Parent.Services:WaitForChild("PurchaseLedgerService"))
local SaveLocatorService = require(script.Parent.Services:WaitForChild("SaveLocatorService"))
local SaveSlotService = require(script.Parent.Services:WaitForChild("SaveSlotService"))
local StaffNpcService = require(script.Parent.Services:WaitForChild("StaffNpcService"))
local StaffNpcWorld = require(script.Parent.Services:WaitForChild("StaffNpcWorld"))
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

-- Robux shop actions (CM2-46a): validated and rate-limited by MonetizationService. Only the
-- server prompts a purchase, and never without an owner-provided ID.
local shopAction = remotes:FindFirstChild("ShopAction") or Instance.new("RemoteFunction")
shopAction.Name = "ShopAction"
shopAction.Parent = remotes

-- One-way, server-to-client notices; clients cannot send anything through it.
local notify = remotes:FindFirstChild("Notify") or Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes

local function tell(player: Player, key: string, ...: number)
	notify:FireClient(player, { key = key, args = { ... } })
end

-- Studio playtests can fast-forward the business clock and pause random customers through
-- StudioTestHook (below). Outside Studio both stay at their neutral values.
local clockOffset = 0
local customersPaused = false

local function businessClock(): number
	return os.time() + clockOffset
end

local function businessRoll(): number
	return math.random()
end

local persistence = PersistenceService.new()
local companies = CompanyStateService.new(persistence, businessClock, businessRoll, task.wait)
local plots = PlotService.new(config.PersonalPlotIds)
-- Walking customers pass through each other, lot trees and players (CM2-N1).
NpcAvatar.registerCollisionGroups()
WorldService.build()

-- Visible staff (CM2-25/26): the Cashier serves the counter, the Lot Worker loads cars and
-- restocks; both rest at the break area. No wages.
local staff = StaffNpcService.new({
	companies = companies,
	plotOf = function(companyId: string): string?
		return plots:getPlot(companyId)
	end,
	world = StaffNpcWorld.new(),
	now = os.clock,
})

-- Walking customer NPCs (CM2-N1): arrive by car, browse, pick, queue, pay, wait at the car.
local npc = CustomerNpcService.new({
	companies = companies,
	plotOf = function(companyId: string): string?
		return plots:getPlot(companyId)
	end,
	world = CustomerNpcWorld.new(),
	now = os.clock,
	staff = staff,
	-- Fewer arrivals at night (CM2-G12a).
	arrivalRate = function(companyId: string): number
		return companies:arrivalRate(companyId)
	end,
})

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

-- Robux shop (CM2-46a): receipts into the buyer's active save, passes, perks, Robux spent.
local ledger = PurchaseLedgerService.new()
local monetization = MonetizationService.new({
	companies = companies,
	ledger = ledger,
	persistence = persistence,
	activeCompanyId = function(userId: number): string?
		return saveSlots:activeCompanyId(userId)
	end,
	playersOn = function(companyId: string)
		return saveSlots:playersOn(companyId)
	end,
	isPresent = function(userId: number): boolean
		return Players:GetPlayerByUserId(userId) ~= nil
	end,
	ownsPass = function(userId: number, passId: number): boolean
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end,
	prompt = function(userId: number, kind: string, id: number)
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			error("NoPlayer")
		end
		if kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end,
	productPrice = function(kind: string, id: number): number?
		local infoType = if kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		return MarketplaceService:GetProductInfo(id, infoType).PriceInRobux
	end,
	onApplied = function(userId: number, companyId: string, product)
		if type(product.grant) == "table" and product.grant.rested == true then
			staff:restAll(companyId)
		end
		local player = Players:GetPlayerByUserId(userId)
		if player then
			tell(player, "shopThanks")
		end
	end,
	setAttribute = function(userId: number, name: string, value: any)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute(name, value)
		end
	end,
	wait = task.wait,
	clock = os.time,
})

-- Leaderboards (CM2-G12b): cached OrderedDataStore writes, published top rows, "You" rows.
local leaderboardFolder = ReplicatedStorage:FindFirstChild("Leaderboards") or Instance.new("Folder")
leaderboardFolder.Name = "Leaderboards"
leaderboardFolder.Parent = ReplicatedStorage

local orderedWrite: Enum.DataStoreRequestType = Enum.DataStoreRequestType.SetIncrementSortedAsync
do
	local ok, value = pcall(function()
		return (Enum.DataStoreRequestType :: any).OrderedWrite
	end)
	if ok and value ~= nil then
		orderedWrite = value
	end
end

local leaderboards = LeaderboardService.new({
	store = function(key: string)
		return DataStoreService:GetOrderedDataStore(LeaderboardService.storeName(key, RunService:IsStudio()))
	end,
	budget = function(): number
		return DataStoreService:GetRequestBudgetForRequestType(orderedWrite)
	end,
	userName = userName,
	clock = os.clock,
	publish = function(key: string, rows)
		leaderboardFolder:SetAttribute(key, HttpService:JSONEncode(rows))
	end,
})

-- Cash earned and reputation of a loaded save (per save, `save_<saveId>`).
local function reportCompany(companyId: string)
	local saveId = string.match(companyId, "^save:(.+)$")
	if saveId == nil then
		return
	end
	local figures = companies:leaderboardFigures(companyId)
	if figures == nil then
		return
	end
	local key = LeaderboardService.saveKey(saveId)
	leaderboards:report("CashEarned", key, figures.revenue)
	leaderboards:report("Reputation", key, figures.reputation)
end

-- Robux spent from the player's ledger; nil means the ledger was not read, so nothing is written.
local function reportRobux(userId: number)
	local spent = monetization:robuxSpent(userId)
	if type(spent) == "number" then
		leaderboards:report("RobuxSpent", LeaderboardService.playerKey(userId), spent)
	end
end

-- The viewer's value and rank per board as `Lb<Key>Value` and `Lb<Key>Rank`.
local function pushYou(player: Player)
	for _, key in config.Leaderboards.Keys do
		local value: number?, rank = nil, 0
		local entryKey: string? = nil
		if config.Leaderboards.PerSave[key] then
			local saveId = player:GetAttribute("ActiveSaveId")
			if type(saveId) == "string" then
				entryKey = LeaderboardService.saveKey(saveId)
			end
		else
			entryKey = LeaderboardService.playerKey(player.UserId)
		end
		if entryKey ~= nil then
			value, rank = leaderboards:you(key, entryKey)
		end
		player:SetAttribute("Lb" .. key .. "Value", value)
		player:SetAttribute("Lb" .. key .. "Rank", rank)
	end
end

local function collectLeaderboards(force: boolean): (number, string?)
	for _, companyId in companies:liveCompanyIds() do
		reportCompany(companyId)
	end
	for _, player in Players:GetPlayers() do
		reportRobux(player.UserId)
	end
	return leaderboards:flush(force)
end

local function refreshLeaderboards(): number
	local read = leaderboards:refresh()
	for _, player in Players:GetPlayers() do
		pushYou(player)
	end
	return read
end

-- Teammate finder (CM2-S3): open finder panels refetch when the listings change.
saveSlots:setFinderHandler(function()
	local revision = ReplicatedStorage:GetAttribute("FinderRevision")
	ReplicatedStorage:SetAttribute("FinderRevision", (if type(revision) == "number" then revision else 0) + 1)
end)

local function companyIdFor(userId: number): string?
	return saveSlots:activeCompanyId(userId)
end

-- Lot sign names (CM2-G15): the broadcast-filtered save name while its author (the owner) is
-- on this server, else the owner's username, else a default. Never the raw name. The
-- filtered text is cached per company and raw name.
local signNames: { [string]: { raw: string, text: string } } = {}

local function signName(companyId: string, view): (string, string, string?)
	local cached = signNames[companyId]
	if cached and cached.raw == view.saveName then
		return cached.text, "Filtered", nil
	end
	local ok, filtered = filterName(view.ownerUserId, view.saveName)
	if ok and type(filtered) == "string" and filtered ~= "" then
		signNames[companyId] = { raw = view.saveName, text = filtered }
		return filtered, "Filtered", nil
	end
	local name = userName(view.ownerUserId)
	if name then
		return string.format("%s's Tree Lot", name), "Owner", name
	end
	return "Tree Lot", "Default", nil
end

-- Refreshes the company's lot sign. The name may yield (text filter, username lookup), so the
-- plot and the view are read again afterwards and written without a yield in between.
local function refreshLotSign(companyId: string)
	task.spawn(function()
		local view = companies:getLotSignView(companyId)
		if view == nil then
			return
		end
		local nameText, nameSource, ownerName = signName(companyId, view)
		local plotId = plots:getPlot(companyId)
		local current = companies:getLotSignView(companyId)
		if plotId == nil or current == nil then
			return
		end
		WorldService.setLotSign(plotId, {
			nameText = nameText,
			nameSource = nameSource,
			ownerName = ownerName,
			ratingTenths = current.ratingTenths,
			reviewCount = current.reviewCount,
			likes = current.likes,
		})
	end)
end

-- Customer reviews (CM2-G15): every player of the save sees the review toast; the sign updates.
companies:setReviewsHandler(function(companyId: string, reviews: { any })
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			for _, review in ipairs(reviews) do
				tell(player, review.textKey, review.stars, review.orderNumber)
			end
		end
	end
	refreshLotSign(companyId)
end)

-- Displayed trees follow authoritative placements, including NPC sales and reservations. A
-- tree a walking customer carries stays hidden (CM2-N1).
companies:setPlacementsChangedHandler(function(companyId: string, placements, mediumPrices, reservations)
	local plotId = plots:getPlot(companyId)
	if plotId then
		WorldService.syncDisplayedTrees(
			plotId,
			placements,
			mediumPrices,
			reservations,
			npc:carriedPlacements(companyId)
		)
	end
end)

-- Receiving bays, bundles, the countdown and the delivery truck follow the bays (CM2-G14).
companies:setReceivingChangedHandler(function(companyId: string, bays)
	local plotId = plots:getPlot(companyId)
	if plotId then
		WorldService.syncReceiving(plotId, bays)
	end
end)

-- The break-area model follows Staff.MoveBreakArea (CM2-25/26 part b); staff follow it on their
-- own through the director's view.
companies:setBreakAreaChangedHandler(function(companyId: string, area)
	local plotId = plots:getPlot(companyId)
	if plotId then
		StaffNpcWorld.syncBreakArea(plotId, area)
	end
end)

-- The stand, lot pad, fence, reserve and parking follow the saved ladder (CM2-G9a): a purchase
-- by any member of the save, or the Studio test setter, updates the save's plot.
companies:setProgressionChangedHandler(function(companyId: string, progression)
	local plotId = plots:getPlot(companyId)
	if plotId then
		WorldService.applyHQVisual(plotId, progression.hqLevel)
		WorldService.applyLotExpansionVisual(plotId, progression.lotExpansion)
		WorldService.applyParkingVisual(plotId, config.Progression.Parking.tiers[progression.parkingTier].spaces)
	end
end)

-- Tutorial hints follow the save's progress (CM2-49).
companies:setTutorialChangedHandler(function(companyId: string, value: string?)
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("TutorialStep", value)
		end
	end
end)

-- The save's day clock (CM2-G12a): every player on the save gets the day and the elapsed
-- time with the server time of the write; the client extrapolates the sky from it.
local function pushDay(companyId: string)
	local view = companies:dayView(companyId)
	if view == nil then
		return
	end
	for _, userId in saveSlots:playersOn(companyId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("DayNumber", view.day)
			player:SetAttribute("DayElapsed", math.floor(view.elapsed * 10 + 0.5) / 10)
			player:SetAttribute("DaySyncAt", workspace:GetServerTimeNow())
		end
	end
end
companies:setDayChangedHandler(pushDay)

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
	-- Customers waiting for a loaded or expired order leave (CM2-N1).
	npc:onOrdersChanged(companyId, summary)
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

-- The species and size of one of the player's open orders (CM2-12W), or nil, nil.
local function orderLook(player: Player, orderNumber: number): (string?, string?)
	local companyId = companyIdFor(player.UserId)
	local summary = if companyId then companies:getCustomerOrders(companyId) else nil
	local orders = if type(summary) == "table" and type(summary.orders) == "table" then summary.orders else {}
	for _, order in ipairs(orders) do
		if order.orderNumber == orderNumber then
			return order.speciesId, order.sizeId
		end
	end
	return nil, nil
end

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
		local speciesId, sizeId = orderLook(player, response.data)
		WorldService.attachCarriedTree(character, response.data, speciesId, sizeId)
	elseif action == Protocol.Actions.OrderLoad or action == Protocol.Actions.OrderRelease then
		-- The review toast (CM2-G15, reviews handler) replaces the old orderComplete toast.
		WorldService.detachCarriedTree(character)
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

-- Manual checkout (CM2-N2): the counter prompt serves the customer at the counter. The
-- player is validated here (ready, plays this plot, interval, reach, empty hands); the price
-- comes from the reservation and company and plot from the server. No remote, no action.
local checkoutLast: { [number]: number } = {}

local function checkoutAt(player: Player, plotId: string)
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local companyId = companyIdFor(player.UserId)
	if
		companyId == nil
		or type(plotId) ~= "string"
		or plots:getPlot(companyId) ~= plotId
		or player:GetAttribute("PlotId") ~= plotId
	then
		return
	end
	local now = os.clock()
	local last = checkoutLast[player.UserId]
	if last ~= nil and now - last < config.Customers.Npc.CheckoutMinIntervalSeconds then
		return
	end
	checkoutLast[player.UserId] = now
	if not withinReach(player, WorldService.checkoutTarget(plotId)) then
		tell(player, "outOfReach")
		return
	end
	if companies:getCarriedOrderNumber(companyId, player.UserId) ~= nil then
		tell(player, "handsFull")
		return
	end
	-- The result is not shown here: the HUD and "Thanks so much!" show the sale.
	npc:checkout(companyId, plotId)
end
WorldService.setCheckoutHandler(checkoutAt)

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
-- CM2-N1: customers walk; simulateCustomerVisits stays a headless and test path only.
every(config.Customers.Npc.ArrivalIntervalSeconds, "customer arrivals", function()
	return true, npc:arrivalPass(customersPaused), 0
end)
every(config.Customers.Npc.TickSeconds, "customer npcs", function()
	npc:tick()
	return true, 0, 0
end)
every(config.Staff.TickSeconds, "staff", function()
	staff:tick()
	return true, 0, 0
end)
every(config.CustomerVisitIntervalSeconds, "customer orders", function()
	return companies:serviceCustomerOrdersAll()
end)
every(config.Receiving.DeliveryPassSeconds, "deliveries", function()
	return companies:reconcileDeliveriesAll()
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
-- Cash Rush counts down only while its save is loaded (CM2-46a, no offline time).
every(ShopConfig.BoostTickSeconds, "boosts", function()
	return companies:tickBoostsAll(ShopConfig.BoostTickSeconds)
end)
-- The save's day runs only while it is loaded (CM2-G12a); the measured wait is the step.
task.spawn(function()
	while true do
		local dt = task.wait(config.DayCycle.TickSeconds)
		local ok, err = pcall(companies.tickDayAll, companies, dt)
		if not ok then
			warn(string.format("[ChristmasMarket2] day tick errored: %s", tostring(err)))
		end
	end
end)
every(config.DayCycle.SyncSeconds, "day sync", function()
	local ids = companies:liveCompanyIds()
	for _, id in ids do
		pushDay(id)
	end
	return true, #ids, 0
end)
-- Hours played count only with an active, ready save (CM2-G12b).
every(config.Leaderboards.PlaytimeTickSeconds, "playtime", function()
	local counted = 0
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CompanyReady") == true then
			leaderboards:addPlaytime(player.UserId, config.Leaderboards.PlaytimeTickSeconds)
			counted += 1
		end
	end
	for _, player in Players:GetPlayers() do
		pushYou(player)
	end
	return true, counted, 0
end)
every(config.Leaderboards.WriteIntervalSeconds, "leaderboard writes", function()
	local written = collectLeaderboards(false)
	return true, written, 0
end)
task.spawn(function()
	task.wait(config.Leaderboards.FirstReadDelaySeconds)
	while true do
		local ok, err = pcall(refreshLeaderboards)
		if not ok then
			warn(string.format("[ChristmasMarket2] leaderboard refresh errored: %s", tostring(err)))
		end
		task.wait(config.Leaderboards.ReadIntervalSeconds)
	end
end)
task.spawn(function()
	monetization:refreshPrices()
end)

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

-- Mirrors a loaded company into its plot: stand, lot, parking, displayed trees and orders.
local function syncPlotWorld(plotId: string, companyId: string, state)
	WorldService.applyHQVisual(plotId, Progression.hqLevel(state))
	WorldService.applyLotExpansionVisual(plotId, Progression.lotLevel(state))
	WorldService.applyParkingVisual(plotId, Progression.parkingSpaces(state))
	WorldService.syncDisplayedTrees(plotId, state.layout.placements, state.mediumPrices)
	WorldService.syncCustomerOrders(plotId, companies:getCustomerOrders(companyId), orderCallbacks)
	WorldService.syncReceiving(plotId, companies:getReceivingView(companyId))
	StaffNpcWorld.syncBreakArea(plotId, state.breakArea)
end

local function clearPlotVisuals(plotId: string)
	WorldService.applyHQVisual(plotId, 1)
	WorldService.applyLotExpansionVisual(plotId, 0)
	WorldService.applyParkingVisual(plotId, 0)
	WorldService.syncDisplayedTrees(plotId, {})
	WorldService.syncCustomerOrders(plotId, nil, nil)
	WorldService.syncReceiving(plotId, nil)
	WorldService.setLotSign(plotId, nil)
	StaffNpcWorld.syncBreakArea(plotId, nil)
end

-- A played save mirrors into its plot and marks the player ready. A player joining a live
-- shared session gets no state: its plot already shows the save.
saveSlots:setActivationHandlers(function(userId: number, companyId: string, plotId: string, state, view)
	if state then
		syncPlotWorld(plotId, companyId, state)
	end
	-- Every activation refreshes the sign, so a later owner join retries the name filter.
	refreshLotSign(companyId)
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
		player:SetAttribute("TutorialStep", companies:tutorialAttribute(companyId))
		pushDay(companyId)
		player:SetAttribute("CompanyReady", true)
		if player.Character then
			task.spawn(spawnAtClaimedPlot, player, player.Character)
		end
	end
	-- Pass perks follow the players on the save (CM2-46a).
	monetization:refreshPerks(companyId)
end, function(userId: number, companyId: string, plotId: string?, plotReleased: boolean)
	if plotReleased then
		signNames[companyId] = nil
	end
	if plotReleased and plotId then
		-- The next claimant must not inherit the previous owner's stand, lot, trees or customers.
		npc:clearPlot(plotId)
		staff:clearPlot(plotId)
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
		player:SetAttribute("TutorialStep", nil)
		player:SetAttribute("DayNumber", nil)
		player:SetAttribute("DayElapsed", nil)
		player:SetAttribute("DaySyncAt", nil)
	end
	monetization:refreshPerks(companyId, userId)
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
		refreshLotSign("save:" .. response.data.saveId)
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
	-- Robux spent and game passes (CM2-46a); independent of the save picker.
	task.spawn(function()
		monetization:onPlayerJoined(player.UserId)
	end)
	-- The stored hours played (CM2-G12b), so the "You" row has a total before the first write.
	task.spawn(function()
		leaderboards:loadPlayer(player.UserId)
	end)
	player.CharacterAdded:Connect(function(character)
		CustomerNpcWorld.assignPlayerCharacter(character)
		-- A respawn drops the carried tree back at the pickup spot.
		local companyId = companyIdFor(player.UserId)
		if companyId then
			companies:releaseCarried(companyId, player.UserId)
		end
		spawnAtClaimedPlot(player, character)
	end)
	-- A character that spawned before this handler ran still joins PlayerCharacter (F6).
	if player.Character then
		CustomerNpcWorld.assignPlayerCharacter(player.Character)
	end
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
	checkoutLast[player.UserId] = nil
	local userId = player.UserId
	-- Leaderboard values while the save and the ledger record are still here (CM2-G12b).
	local companyId = companyIdFor(userId)
	if companyId then
		reportCompany(companyId)
	end
	reportRobux(userId)
	local ok, errorCode = saveSlots:leave(player.UserId, true)
	if not ok then
		warn(string.format("[ChristmasMarket2] save unload failed for %d: %s", player.UserId, tostring(errorCode)))
	end
	companies:forgetUser(player.UserId)
	monetization:forgetUser(player.UserId)
	task.spawn(function()
		leaderboards:flushUser(userId)
		leaderboards:forgetPlayer(userId)
	end)
end)

local ORDER_REACH_ACTIONS = {
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
}

-- Lot.Like (CM2-G15): validated, rate-limited, within reach of the target's sign; the liked
-- company comes from the plot claim, never from the client. Own and co-op saves are refused.
local function likeLot(player: Player, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return { ok = false, errorCode = validationError }
	end
	if not companies:allowLike(player.UserId) then
		return { ok = false, errorCode = "RateLimited" }
	end
	local plotId = request.payload.plotId
	local target = plots:holderOf(plotId)
	if target == nil then
		return { ok = false, errorCode = "LotUnavailable" }
	end
	if not withinReach(player, WorldService.lotSignTarget(plotId)) then
		return { ok = false, errorCode = "OutOfReach" }
	end
	local response = companies:likeLot(target, player.UserId)
	if response.ok then
		refreshLotSign(target)
	end
	return response
end

local function handleBusinessAction(player: Player, request)
	if player:GetAttribute("CompanyReady") ~= true then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	if type(request) == "table" and request.action == Protocol.Actions.LotLike then
		return likeLot(player, request)
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
	-- handle() succeeded, so request passed validation and is a table. Progression purchases
	-- update the plot through the progression handler (CM2-G9a).
	afterOrderAction(player, request.action, response, request.payload)
	return response
end
businessAction.OnServerInvoke = handleBusinessAction

-- Untrusted Shop.* requests (CM2-46a).
shopAction.OnServerInvoke = function(player: Player, request)
	return monetization:handle(player.UserId, request)
end

-- Developer-product receipts (CM2-46a): PurchaseGranted only after the grant, the save of the
-- company record and the ledger entry; everything else is NotProcessedYet and retried by
-- Roblox. Unknown product IDs are never granted.
MarketplaceService.ProcessReceipt = function(info)
	local called, decision = pcall(function()
		return monetization:processReceipt({
			PlayerId = info.PlayerId,
			ProductId = info.ProductId,
			PurchaseId = info.PurchaseId,
			CurrencySpent = if info.CurrencyType == Enum.CurrencyType.Robux then info.CurrencySpent else 0,
		})
	end)
	if called and decision == "PurchaseGranted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not called then
		warn(string.format("[ChristmasMarket2] ProcessReceipt errored: %s", tostring(decision)))
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Game passes bought in this session take effect at once (CM2-46a).
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	monetization:onPassPurchaseFinished(player.UserId, passId, purchased)
	if purchased then
		tell(player, "shopPassActive")
	end
end)

-- Studio-only test instrument for reproducible playtests (docs/TEST_PLAN.md). The hook is
-- never created on live servers (the release build omits StudioTestService), and clients
-- cannot reach a ServerStorage BindableFunction.
if RunService:IsStudio() then
	local module = script.Parent.Services:FindFirstChild("StudioTestService")
	if module then
		require(module).install({
			companies = companies,
			plots = plots,
			npc = npc,
			staff = staff,
			saveSlots = saveSlots,
			monetization = monetization,
			ledger = ledger,
			leaderboards = leaderboards,
			collectLeaderboards = collectLeaderboards,
			refreshLeaderboards = refreshLeaderboards,
			orderCallbacks = orderCallbacks,
			checkoutAt = checkoutAt,
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
	-- No customer survives the server: avatars, cars and carried trees go first (CM2-N1).
	npc:shutdown()
	-- Staff avatars go too (CM2-25/26).
	staff:shutdown()
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
	-- Leaderboards last, best effort: the saves come first (CM2-G12b).
	pcall(leaderboards.flush, leaderboards, true)
end)

print(string.format("[ChristmasMarket2] Server booted. Starting cash: %d", config.StartingCash))
