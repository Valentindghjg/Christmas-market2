--!strict
-- Bootstrap only. Gameplay services must run on the server and validate all remote requests.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
print(string.format("[ChristmasMarket2] Server booted. Starting cash: %d", config.StartingCash))
