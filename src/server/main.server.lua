--!strict
-- Server bootstrap. Every business mutation enters through the validated RemoteFunction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local persistence = PersistenceService.new()
local companies = CompanyStateService.new(persistence)
local plots = PlotService.new(config.PersonalPlotIds)
WorldService.build()

local function companyIdFor(userId: number): string
	return "personal:" .. tostring(userId)
end

local function userIdFromCompanyId(companyId: string): number?
	return tonumber(string.match(companyId, "^personal:(%d+)$"))
end

-- Displayed trees follow authoritative placements, including NPC sales.
companies:setPlacementsChangedHandler(function(companyId: string, placements)
	local userId = userIdFromCompanyId(companyId)
	local plotId = userId and plots:getPlotForUser(userId)
	if plotId then
		WorldService.syncDisplayedTrees(plotId, placements)
	end
end)

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
every(config.CustomerVisitIntervalSeconds, "delivery reconciliation", function()
	return companies:reconcileDeliveriesAll()
end)
every(config.CustomerVisitIntervalSeconds, "lot-worker unload", function()
	return companies:autoUnloadDeliveriesAll()
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
	WorldService.applyParkingVisual(plotId, state.progression.parkingSpaces)
	WorldService.syncDisplayedTrees(plotId, state.layout.placements)
	player:SetAttribute("CompanyReady", true)
	player:SetAttribute("CompanyLoadError", nil)
	player:SetAttribute("PlotId", plotId)
	player.CharacterAdded:Connect(function(character)
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

businessAction.OnServerInvoke = function(player, request)
	if player:GetAttribute("CompanyReady") ~= true then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	local response = companies:handle(companyIdFor(player.UserId), player.UserId, request)
	if not response.ok then
		return response
	end
	local plotId = player:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return response
	end
	-- handle() succeeded, so request passed validation and is a table.
	local action = request.action
	if action == Protocol.Actions.ProgressionBuyHQ then
		WorldService.applyHQVisual(plotId, response.data)
	elseif action == Protocol.Actions.ProgressionBuyLotExpansion and type(response.data) == "number" then
		WorldService.applyLotExpansionVisual(plotId, response.data)
	elseif action == Protocol.Actions.ProgressionBuyParking and type(response.data) == "number" then
		WorldService.applyParkingVisual(plotId, response.data)
	end
	return response
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
