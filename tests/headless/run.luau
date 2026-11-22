--!strict
-- Executes every unit-test case outside Studio for local and CI feedback.
local fs = require("@lune/fs")
local process = require("@lune/process")

type Node = {
	Name: string,
	Parent: Node?,
	Path: string?,
	[string]: unknown,
}

local function child(parent: Node, name: string, path: string?): Node
	local node: Node = {
		Name = name,
		Parent = parent,
		Path = path,
	}
	function node:WaitForChild(childName: string): Node
		local result = self[childName]
		assert(type(result) == "table", string.format("%s has no child %s", self.Name, childName))
		return result :: Node
	end
	parent[name] = node
	return node
end

local replicatedStorage = { Name = "ReplicatedStorage" } :: Node
function replicatedStorage:WaitForChild(childName: string): Node
	local result = self[childName]
	assert(type(result) == "table", string.format("%s has no child %s", self.Name, childName))
	return result :: Node
end
local shared = child(replicatedStorage, "Shared")
local serverScriptService = { Name = "ServerScriptService" } :: Node
function serverScriptService:WaitForChild(childName: string): Node
	local result = self[childName]
	assert(type(result) == "table", string.format("%s has no child %s", self.Name, childName))
	return result :: Node
end
local server = child(serverScriptService, "Server")
local services = child(server, "Services")
for name, path in pairs({
	AnalyticsService = "src/server/Services/AnalyticsService.lua",
	CompanyStateService = "src/server/Services/CompanyStateService.lua",
	CustomerOrderService = "src/server/Services/CustomerOrderService.lua",
	CustomerService = "src/server/Services/CustomerService.lua",
	SupplierStockService = "src/server/Services/SupplierStockService.lua",
	CustomerSimulationService = "src/server/Services/CustomerSimulationService.lua",
	EmployeeService = "src/server/Services/EmployeeService.lua",
	PersistenceService = "src/server/Services/PersistenceService.lua",
	PlacementService = "src/server/Services/PlacementService.lua",
	PlotService = "src/server/Services/PlotService.lua",
	PricingService = "src/server/Services/PricingService.lua",
	ProgressionService = "src/server/Services/ProgressionService.lua",
	QuestService = "src/server/Services/QuestService.lua",
}) do
	child(services, name, path)
end
local sourcePaths = {
	ArtLibrary = "src/shared/ArtLibrary.lua",
	ArtPalette = "src/shared/ArtPalette.lua",
	AssetCatalog = "src/shared/AssetCatalog.lua",
	BusinessState = "src/shared/BusinessState.lua",
	CustomerProfile = "src/shared/CustomerProfile.lua",
	CustomerSelection = "src/shared/CustomerSelection.lua",
	Demand = "src/shared/Demand.lua",
	Economy = "src/shared/Economy.lua",
	GameConfig = "src/shared/GameConfig.lua",
	Inventory = "src/shared/Inventory.lua",
	Localization = "src/shared/Localization.lua",
	Protocol = "src/shared/Protocol.lua",
	SupplierCatalog = "src/shared/SupplierCatalog.lua",
	TreeHeight = "src/shared/TreeHeight.lua",
}
for name, path in pairs(sourcePaths) do
	child(shared, name, path)
end

local serverStorage = { Name = "ServerStorage" } :: Node
function serverStorage:WaitForChild(childName: string): Node
	local result = self[childName]
	assert(type(result) == "table", string.format("%s has no child %s", self.Name, childName))
	return result :: Node
end
local unitTest = child(serverStorage, "UnitTest")
local playtest = child(unitTest, "Playtest")
child(playtest, "RunPlaytest", "tests/studio/Playtest/RunPlaytest.lua")

local game = { JobId = "headless" }
function game:GetService(name: string): Node
	if name == "ReplicatedStorage" then
		return replicatedStorage
	end
	if name == "ServerStorage" then
		return serverStorage
	end
	if name == "ServerScriptService" then
		return serverScriptService
	end
	if name == "DataStoreService" then
		return { Name = "DataStoreService" } :: Node
	end
	error("headless runner does not expose " .. name)
end

local loaded: { [Node]: unknown } = {}
local function loadModule(module: Node): unknown
	if loaded[module] ~= nil then
		return loaded[module]
	end
	assert(module.Path ~= nil, string.format("%s is not a module", module.Name))
	local chunk, loadError = loadstring(fs.readFile(module.Path), "@" .. module.Path)
	assert(chunk ~= nil, loadError)
	setfenv(chunk, setmetatable({ game = game, require = loadModule, script = module }, { __index = getfenv() }))
	local value = chunk()
	loaded[module] = value
	return value
end

local total, failures = 0, 0
local function format(value: unknown): string
	return type(value) == "string" and string.format("%q", value) or tostring(value)
end
local expect = {}
function expect.equal(actual: unknown, expected: unknown)
	assert(actual == expected, string.format("expected %s, got %s", format(expected), format(actual)))
end
function expect.truthy(value: unknown)
	assert(value, string.format("expected truthy, got %s", format(value)))
end
function expect.falsy(value: unknown)
	assert(not value, string.format("expected falsy, got %s", format(value)))
end
function expect.throws(fn: () -> ())
	local ok, err = pcall(fn)
	assert(not ok, "expected function to throw")
	return err
end

local function runCase(name: string)
	local testModule = child({ Name = "Cases" } :: Node, name, "tests/studio/Cases/" .. name .. ".lua")
	local factory = loadModule(testModule)
	assert(type(factory) == "function", name .. " must return a test factory")
	local context = { expect = expect }
	function context.test(testName: string, fn: () -> ())
		total += 1
		local ok, err = pcall(fn)
		if ok then
			print(string.format("[PASS] %s > %s", name, testName))
		else
			failures += 1
			warn(string.format("[FAIL] %s > %s | %s", name, testName, tostring(err)))
		end
	end
	(factory :: (unknown) -> ())(context)
end

-- Every Studio case runs headlessly; new cases are discovered automatically.
local caseNames = {}
for _, fileName in ipairs(fs.readDir("tests/studio/Cases")) do
	local caseName = string.match(fileName, "^(.+_Test)%.lua$")
	if caseName then
		table.insert(caseNames, caseName)
	end
end
table.sort(caseNames)
assert(#caseNames > 0, "no test cases discovered")
for _, name in ipairs(caseNames) do
	runCase(name)
end
print(string.format("[SUMMARY] %d run, %d passed, %d failed", total, total - failures, failures))
if failures > 0 then
	process.exit(1)
end
