--!strict
-- Client actions are requests only; the server owns every resulting state change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local businessAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction")

local ClientActions = {}

function ClientActions.request(request)
	return businessAction:InvokeServer(request)
end

print("[ChristmasMarket2] Client booted")

return ClientActions
