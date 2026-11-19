--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BusinessState = require(Shared:WaitForChild("BusinessState"))

local EmployeeService = {}

function EmployeeService.hire(state, employeeId: string)
	local definition = GameConfig.Employees[employeeId]
	if not definition then
		return false, "UnknownEmployee"
	end
	if state.staff[employeeId] >= 1 then
		return false, "AlreadyHired"
	end
	if state.cash < definition.hireCost then
		return false, "InsufficientFunds"
	end
	state.cash -= definition.hireCost
	state.spent += definition.hireCost
	state.staff[employeeId] = 1
	BusinessState.record(state, "EmployeeHired", -definition.hireCost)
	return true, employeeId
end

return EmployeeService
