--!strict
-- Server bootstrap. Every business mutation enters through the validated RemoteFunction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local PersistenceService = require(script.Parent.Services:WaitForChild("PersistenceService"))
local CompanyStateService = require(script.Parent.Services:WaitForChild("CompanyStateService"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local businessAction = remotes:FindFirstChild("BusinessAction") or Instance.new("RemoteFunction")
businessAction.Name = "BusinessAction"
businessAction.Parent = remotes

local persistence = PersistenceService.new()
local companies = CompanyStateService.new(persistence)

local function loadPlayer(player: Player)
	local state, errorCode = companies:loadPersonalCompany(player.UserId)
	if state then
		player:SetAttribute("CompanyReady", true)
		player:SetAttribute("CompanyLoadError", nil)
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
end)

businessAction.OnServerInvoke = function(player, request)
	return companies:handle("personal:" .. tostring(player.UserId), player.UserId, request)
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
