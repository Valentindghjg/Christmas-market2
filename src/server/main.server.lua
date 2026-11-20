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

task.spawn(function()
	while true do
		task.wait(config.AutosaveSeconds)
		local saved, failures = companies:autosaveAll()
		if not saved then
			warn(string.format("[ChristmasMarket2] autosave failed for %d company sessions", failures))
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(config.CustomerVisitIntervalSeconds)
		local saved, _, failures = companies:simulateCustomerVisits()
		if not saved then
			warn(string.format("[ChristmasMarket2] customer-sale save failed for %d company sessions", failures))
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(config.CustomerVisitIntervalSeconds)
		local saved, _, failures = companies:reconcileDeliveriesAll()
		if not saved then
			warn(
				string.format(
					"[ChristmasMarket2] delivery reconciliation save failed for %d company sessions",
					failures
				)
			)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(config.CustomerVisitIntervalSeconds)
		local saved, _, failures = companies:autoUnloadDeliveriesAll()
		if not saved then
			warn(string.format("[ChristmasMarket2] lot-worker unload save failed for %d company sessions", failures))
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(config.AutoPricingIntervalSeconds)
		local saved, _, failures = companies:applyAutoPricingAll()
		if not saved then
			warn(string.format("[ChristmasMarket2] automatic pricing save failed for %d company sessions", failures))
		end
	end
end)

local function loadPlayer(player: Player)
	local state, errorCode = companies:loadPersonalCompany(player.UserId)
	if state then
		local plotId, plotError = plots:claim(player.UserId)
		if plotId then
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
		else
			companies:unloadCompany("personal:" .. tostring(player.UserId))
			player:SetAttribute("CompanyReady", false)
			player:SetAttribute("CompanyLoadError", plotError)
		end
	else
		player:SetAttribute("CompanyReady", false)
		player:SetAttribute("CompanyLoadError", errorCode)
		warn(string.format("[ChristmasMarket2] company load failed for %d: %s", player.UserId, tostring(errorCode)))
	end
end

Players.PlayerAdded:Connect(loadPlayer)
Players.PlayerRemoving:Connect(function(player)
	local companyId = "personal:" .. tostring(player.UserId)
	local ok, errorCode = companies:unloadCompany(companyId)
	if not ok then
		warn(string.format("[ChristmasMarket2] company unload failed for %d: %s", player.UserId, tostring(errorCode)))
	end
	plots:release(player.UserId)
end)

businessAction.OnServerInvoke = function(player, request)
	if player:GetAttribute("CompanyReady") ~= true then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	local response = companies:handle("personal:" .. tostring(player.UserId), player.UserId, request)
	if response.ok and request.action == Protocol.Actions.ProgressionBuyHQ then
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" then
			WorldService.applyHQVisual(plotId, response.data)
		end
	elseif response.ok and request.action == Protocol.Actions.ProgressionBuyLotExpansion then
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" and type(response.data) == "number" then
			WorldService.applyLotExpansionVisual(plotId, response.data)
		end
	elseif response.ok and request.action == Protocol.Actions.ProgressionBuyParking then
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" and type(response.data) == "number" then
			WorldService.applyParkingVisual(plotId, response.data)
		end
	elseif response.ok and (request.action == Protocol.Actions.InventoryPlace or request.action == Protocol.Actions.InventoryPickup) then
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" then
			local placements = companies:getPlacements("personal:" .. tostring(player.UserId))
			if placements then
				WorldService.syncDisplayedTrees(plotId, placements)
			end
		end
	end
	return response
end

for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		companies:unloadCompany("personal:" .. tostring(player.UserId))
	end
end)

print(string.format("[ChristmasMarket2] Server booted. Starting cash: %d", config.StartingCash))
