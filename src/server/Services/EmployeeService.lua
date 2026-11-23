--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BusinessState = require(Shared:WaitForChild("BusinessState"))

local EmployeeService = {}

-- How many employees the save may have: Employees.BaseCapacity, or its HQ's
-- employeeCapacity once an HQ is bought (CM2-25/26 part b).
function EmployeeService.capacity(state): number
	local hqTier = if type(state.progression) == "table" then state.progression.hqTier else nil
	local hq = if type(hqTier) == "string" then GameConfig.HQ[hqTier] else nil
	if type(hq) == "table" and type(hq.employeeCapacity) == "number" then
		return hq.employeeCapacity
	end
	return GameConfig.Employees.BaseCapacity
end

-- Hired employees: Cashier + LotWorker + LotManager.
function EmployeeService.hiredCount(state): number
	local count = 0
	for _, role in ipairs(GameConfig.Staff.Roles) do
		local hired = state.staff[role]
		if type(hired) == "number" then
			count += hired
		end
	end
	return count
end

-- One-time hire. Checks in this order: UnknownEmployee, AlreadyHired, EmployeeLocked,
-- EmployeeCapacity, InsufficientFunds; then the cost is debited exactly once and the new
-- employee starts fully rested. A replayed request ID never reaches this function.
function EmployeeService.hire(state, employeeId: string)
	local definition = GameConfig.Employees[employeeId]
	if type(definition) ~= "table" then
		return false, "UnknownEmployee"
	end
	if state.staff[employeeId] >= 1 then
		return false, "AlreadyHired"
	end
	-- Until CM2-G9 adds the HQ ladder, an employee with requiredHqTier cannot be hired.
	if definition.requiredHqTier ~= nil then
		return false, "EmployeeLocked"
	end
	if EmployeeService.hiredCount(state) >= EmployeeService.capacity(state) then
		return false, "EmployeeCapacity"
	end
	if state.cash < definition.hireCost then
		return false, "InsufficientFunds"
	end
	state.cash -= definition.hireCost
	state.spent += definition.hireCost
	state.staff[employeeId] = 1
	state.staffEnergy[employeeId] = GameConfig.Staff.Energy.Max
	BusinessState.record(state, "EmployeeHired", -definition.hireCost)
	return true, employeeId
end

return EmployeeService
