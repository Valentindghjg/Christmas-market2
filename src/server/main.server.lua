--!strict
-- Server bootstrap. Every business mutation enters through the validated RemoteFunction
-- or a server-side ProximityPrompt that is checked exactly like a remote call.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))
local PersistenceService = require(script.Parent.Services:WaitForChild("PersistenceService"))
local CompanyStateService = require(script.Parent.Services:WaitForChild("CompanyStateService"))
local PlotService = require(script.Parent.Services:WaitForChild("PlotService"))
local WorldService = require(script.Parent.Services:WaitForChild("WorldService"))

local LOAD_ATTEMPTS = 5
local SHUTDOWN_WAIT_SECONDS = 25

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local businessAction = remotes:FindFirstChild("BusinessAction") or Instance.new("RemoteFunction")
businessAction.Name = "BusinessAction"
businessAction.Parent = remotes

-- One-way, server-to-client notices; clients cannot send anything through it.
local notify = remotes:FindFirstChild("Notify") or Instance.new("RemoteEvent")
notify.Name = "Notify"
notify.Parent = remotes

local function tell(player: Player, key: string, ...: number)
	notify:FireClient(player, { key = key, args = { ... } })
end

-- Studio playtests can force customer conversions and fast-forward the business clock
-- through StudioTestHook (below). Outside Studio both stay at their neutral values.
local clockOffset = 0
local forcedRolls = 0

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

local function companyIdFor(userId: number): string
	return "personal:" .. tostring(userId)
end

local function userIdFromCompanyId(companyId: string): number?
	return tonumber(string.match(companyId, "^personal:(%d+)$"))
end

local function effectiveParking(spaces: number): number
	return math.max(config.Customers.BaseParkingSpaces, spaces)
end

-- Displayed trees follow authoritative placements, including NPC sales.
companies:setPlacementsChangedHandler(function(companyId: string, placements, mediumPrices)
	local userId = userIdFromCompanyId(companyId)
	local plotId = userId and plots:getPlotForUser(userId)
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
	local userId = userIdFromCompanyId(companyId)
	local plotId = userId and plots:getPlotForUser(userId)
	if plotId then
		WorldService.syncCustomerOrders(plotId, summary, orderCallbacks)
	end
	local player = userId and Players:GetPlayerByUserId(userId)
	if player then
		syncCarriedVisual(player, summary)
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
	if not orderReachAllowed(player, action, payload) then
		tell(player, "outOfReach")
		return
	end
	-- Request IDs are persisted, so they must stay unique across servers and restarts.
	local response = companies:handle(companyIdFor(player.UserId), player.UserId, {
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
		local orderNumber = companies:getCarriedOrderNumber(companyIdFor(player.UserId), player.UserId)
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

local function isInGame(player: Player): boolean
	return player.Parent == Players
end

local function loadPlayer(player: Player)
	local companyId = companyIdFor(player.UserId)
	local state, errorCode
	for attempt = 1, LOAD_ATTEMPTS do
		state, errorCode = companies:loadPersonalCompany(player.UserId)
		-- SessionBusy: this server is still saving the player's previous session.
		if state or errorCode ~= "SessionBusy" or not isInGame(player) then
			break
		end
		task.wait(attempt)
	end
	if not isInGame(player) then
		-- The player left while the load yielded; PlayerRemoving found nothing to unload.
		if state then
			companies:unloadCompany(companyId)
		end
		return
	end
	if not state then
		player:SetAttribute("CompanyReady", false)
		player:SetAttribute("CompanyLoadError", errorCode)
		warn(string.format("[ChristmasMarket2] company load failed for %d: %s", player.UserId, tostring(errorCode)))
		return
	end
	local plotId, plotError = plots:claim(player.UserId)
	if not plotId then
		companies:unloadCompany(companyId)
		player:SetAttribute("CompanyReady", false)
		player:SetAttribute("CompanyLoadError", plotError)
		return
	end
	WorldService.applyHQVisual(plotId, state.progression.hqTier)
	WorldService.applyLotExpansionVisual(plotId, state.progression.lotExpansion)
	WorldService.applyParkingVisual(plotId, effectiveParking(state.progression.parkingSpaces))
	WorldService.syncDisplayedTrees(plotId, state.layout.placements, state.mediumPrices)
	WorldService.syncCustomerOrders(plotId, companies:getCustomerOrders(companyId), orderCallbacks)
	player:SetAttribute("CompanyReady", true)
	player:SetAttribute("CompanyLoadError", nil)
	player:SetAttribute("PlotId", plotId)
	player.CharacterAdded:Connect(function(character)
		-- A respawn drops the carried tree back at the pickup spot.
		companies:releaseCarried(companyId, player.UserId)
		spawnAtClaimedPlot(player, character)
	end)
	if player.Character then
		task.spawn(spawnAtClaimedPlot, player, player.Character)
	end
end

local function clearPlotVisuals(plotId: string)
	WorldService.applyHQVisual(plotId, nil)
	WorldService.applyLotExpansionVisual(plotId, 0)
	WorldService.applyParkingVisual(plotId, 0)
	WorldService.syncDisplayedTrees(plotId, {})
	WorldService.syncCustomerOrders(plotId, nil, nil)
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
	local ok, errorCode = companies:unloadCompany(companyIdFor(player.UserId))
	if not ok then
		warn(string.format("[ChristmasMarket2] company unload failed for %d: %s", player.UserId, tostring(errorCode)))
	end
	companies:forgetUser(player.UserId)
	local plotId = plots:getPlotForUser(player.UserId)
	if plotId then
		-- The next claimant must not inherit the previous owner's stand, lot or trees.
		clearPlotVisuals(plotId)
	end
	plots:release(player.UserId)
end)

local ORDER_REACH_ACTIONS = {
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
}

businessAction.OnServerInvoke = function(player, request)
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
	local response = companies:handle(companyIdFor(player.UserId), player.UserId, request)
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

-- Studio-only test instrument for reproducible playtests (docs/TEST_PLAN.md). It is
-- never created on live servers, and clients cannot reach a ServerStorage BindableFunction.
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "StudioTestHook"
	hook.OnInvoke = function(command: string, value: number?)
		if command == "forceCustomer" and type(value) == "number" and value >= 1 then
			-- The next arriving customer has profile `value` and always converts.
			companies:setCustomerSequence(math.floor(value) - 1)
			forcedRolls = 1
			return true
		elseif command == "advanceClock" and type(value) == "number" and value > 0 and value <= 3600 then
			clockOffset += value
			return clockOffset
		elseif command == "customerOrders" and type(value) == "number" then
			return companies:getCustomerOrders(companyIdFor(value))
		end
		return nil
	end
	hook.Parent = game:GetService("ServerStorage")
end

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

game:BindToClose(function()
	-- Unload in parallel: sequential saves with retry backoff can exceed the shutdown budget.
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			pcall(companies.unloadCompany, companies, companyIdFor(player.UserId))
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < SHUTDOWN_WAIT_SECONDS do
		waited += task.wait(0.1)
	end
end)

print(string.format("[ChristmasMarket2] Server booted. Starting cash: %d", config.StartingCash))
