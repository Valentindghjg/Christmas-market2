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
	AdventService = "src/server/Services/AdventService.lua",
	AnalyticsService = "src/server/Services/AnalyticsService.lua",
	CompanyDayCycle = "src/server/Services/CompanyDayCycle.lua",
	CompanyEvents = "src/server/Services/CompanyEvents.lua",
	CompanyProgression = "src/server/Services/CompanyProgression.lua",
	CompanyQuests = "src/server/Services/CompanyQuests.lua",
	CompanyPurchases = "src/server/Services/CompanyPurchases.lua",
	CompanyStaff = "src/server/Services/CompanyStaff.lua",
	CompanyStateService = "src/server/Services/CompanyStateService.lua",
	CompanyTutorial = "src/server/Services/CompanyTutorial.lua",
	CustomerOrderService = "src/server/Services/CustomerOrderService.lua",
	CustomerNpcService = "src/server/Services/CustomerNpcService.lua",
	CustomerService = "src/server/Services/CustomerService.lua",
	SupplierStockService = "src/server/Services/SupplierStockService.lua",
	CustomerSimulationService = "src/server/Services/CustomerSimulationService.lua",
	DailyRewardService = "src/server/Services/DailyRewardService.lua",
	EmployeeService = "src/server/Services/EmployeeService.lua",
	InviteCodeService = "src/server/Services/InviteCodeService.lua",
	LeaderboardService = "src/server/Services/LeaderboardService.lua",
	MonetizationService = "src/server/Services/MonetizationService.lua",
	PersistenceService = "src/server/Services/PersistenceService.lua",
	PlacementService = "src/server/Services/PlacementService.lua",
	PlayerSettingsService = "src/server/Services/PlayerSettingsService.lua",
	PlotService = "src/server/Services/PlotService.lua",
	PricingService = "src/server/Services/PricingService.lua",
	ProgressionService = "src/server/Services/ProgressionService.lua",
	PurchaseLedgerService = "src/server/Services/PurchaseLedgerService.lua",
	SaveLocatorService = "src/server/Services/SaveLocatorService.lua",
	SaveSlotCrossServer = "src/server/Services/SaveSlotCrossServer.lua",
	SaveSlotPicker = "src/server/Services/SaveSlotPicker.lua",
	SaveSlotService = "src/server/Services/SaveSlotService.lua",
	SaveSlotShared = "src/server/Services/SaveSlotShared.lua",
	SaveSlotTeam = "src/server/Services/SaveSlotTeam.lua",
	StaffNpcService = "src/server/Services/StaffNpcService.lua",
	StudioTestService = "src/server/Services/StudioTestService.lua",
}) do
	child(services, name, path)
end
local sourcePaths = {
	AdventCalendar = "src/shared/AdventCalendar.lua",
	ArtLibrary = "src/shared/ArtLibrary.lua",
	ArtPalette = "src/shared/ArtPalette.lua",
	AssetCatalog = "src/shared/AssetCatalog.lua",
	BusinessState = "src/shared/BusinessState.lua",
	CustomerProfile = "src/shared/CustomerProfile.lua",
	CustomerSelection = "src/shared/CustomerSelection.lua",
	DailyRewards = "src/shared/DailyRewards.lua",
	DayCycle = "src/shared/DayCycle.lua",
	Demand = "src/shared/Demand.lua",
	Economy = "src/shared/Economy.lua",
	EventCalendar = "src/shared/EventCalendar.lua",
	EventConfig = "src/shared/EventConfig.lua",
	GameConfig = "src/shared/GameConfig.lua",
	Inventory = "src/shared/Inventory.lua",
	LabelDeclutter = "src/shared/LabelDeclutter.lua",
	LandView = "src/shared/LandView.lua",
	LeaderboardView = "src/shared/LeaderboardView.lua",
	LightingBlend = "src/shared/LightingBlend.lua",
	Localization = "src/shared/Localization.lua",
	LotArt = "src/shared/LotArt.lua",
	MapLayout = "src/shared/MapLayout.lua",
	MusicSettings = "src/shared/MusicSettings.lua",
	ModalCoordinator = "src/shared/ModalCoordinator.lua",
	NpcLook = "src/shared/NpcLook.lua",
	NpcPath = "src/shared/NpcPath.lua",
	OrderStatus = "src/shared/OrderStatus.lua",
	ParkingArt = "src/shared/ParkingArt.lua",
	PricingView = "src/shared/PricingView.lua",
	QuestBoard = "src/shared/QuestBoard.lua",
	Progression = "src/shared/Progression.lua",
	Protocol = "src/shared/Protocol.lua",
	Purchases = "src/shared/Purchases.lua",
	Reviews = "src/shared/Reviews.lua",
	Receiving = "src/shared/Receiving.lua",
	SaveListSync = "src/shared/SaveListSync.lua",
	SaveProfile = "src/shared/SaveProfile.lua",
	ShopConfig = "src/shared/ShopConfig.lua",
	Staff = "src/shared/Staff.lua",
	Stocking = "src/shared/Stocking.lua",
	SupplierCart = "src/shared/SupplierCart.lua",
	SupplierCatalog = "src/shared/SupplierCatalog.lua",
	TreeArt = "src/shared/TreeArt.lua",
	TreeHeight = "src/shared/TreeHeight.lua",
	Tutorial = "src/shared/Tutorial.lua",
	UiStyle = "src/shared/UiStyle.lua",
	UiTheme = "src/shared/UiTheme.lua",
	VehicleArt = "src/shared/VehicleArt.lua",
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
	if name == "Players" then
		return {
			Name = "Players",
			GetPlayerByUserId = function(): nil
				return nil
			end,
		} :: Node
	end
	if name == "HttpService" then
		local guids = 0
		return {
			Name = "HttpService",
			GenerateGUID = function(): string
				guids += 1
				return "guid-" .. guids
			end,
		} :: Node
	end
	if name == "RunService" then
		return { Name = "RunService" } :: Node
	end
	error("headless runner does not expose " .. name)
end

-- Instance.new("BindableFunction") only for StudioTestService.install: Invoke calls OnInvoke.
local instanceStub = {
	new = function(): any
		local object: any = {}
		function object:Invoke(...)
			return self.OnInvoke(...)
		end
		return object
	end,
}

local loaded: { [Node]: unknown } = {}
local function loadModule(module: Node): unknown
	if loaded[module] ~= nil then
		return loaded[module]
	end
	assert(module.Path ~= nil, string.format("%s is not a module", module.Name))
	local chunk, loadError = loadstring(fs.readFile(module.Path), "@" .. module.Path)
	assert(chunk ~= nil, loadError)
	setfenv(
		chunk,
		setmetatable(
			{ game = game, require = loadModule, script = module, Instance = instanceStub },
			{ __index = getfenv() }
		)
	)
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
-- CM2-47 D2: the server entry script must drain client sends on the server-to-client Notify remote.
total += 1
do
	local ok, err = pcall(function()
		local source = fs.readFile("src/server/main.server.lua")
		assert(string.find(source, "notify.OnServerEvent:Connect(", 1, true), "Notify.OnServerEvent not connected")
	end)
	if ok then
		print("[PASS] main.server > Notify drains client sends")
	else
		failures += 1
		warn("[FAIL] main.server > Notify drains client sends | " .. tostring(err))
	end
end
-- CM2-VIBE1: both project files must carry the Lighting node of GameConfig.Lighting (Static + Day).
local serde = require("@lune/serde")
local function sameValue(actual: any, want: any): boolean
	if type(want) == "table" then
		if type(actual) ~= "table" or #actual ~= #want then
			return false
		end
		for channel = 1, #want do
			if math.abs(actual[channel] * 255 - want[channel]) >= 0.5 then
				return false
			end
		end
		return true
	elseif type(want) == "number" then
		return type(actual) == "number" and math.abs(actual - want) < 1e-4
	end
	return actual == want
end
local function checkProperties(properties: any, expected: { [string]: any }, label: string)
	assert(type(properties) == "table", label .. " has no $properties")
	for key, want in pairs(expected) do
		assert(sameValue(properties[key], want), string.format("%s.%s differs from GameConfig.Lighting", label, key))
	end
end
for _, fileName in ipairs({ "default.project.json", "release.project.json" }) do
	total += 1
	local ok, err = pcall(function()
		local config = (loadModule(shared.GameConfig) :: any).Lighting
		local node = serde.decode("json", fs.readFile(fileName)).tree.Lighting
		assert(node ~= nil and node["$className"] == "Lighting", "tree.Lighting is not a Lighting node")
		local expected = table.clone(config.Static)
		for key, value in pairs(config.Day.Lighting) do
			expected[key] = value
		end
		checkProperties(node["$properties"], expected, "Lighting")
		local count = 0
		for _ in pairs(node["$properties"]) do
			count += 1
		end
		local expectedCount = 0
		for _ in pairs(expected) do
			expectedCount += 1
		end
		assert(count == expectedCount, "Lighting has extra $properties")
		for name, className in pairs(config.Classes) do
			local effect = node[name]
			assert(effect ~= nil and effect["$className"] == className, name .. " is missing or has the wrong class")
			checkProperties(effect["$properties"], config.Day[name], name)
			local effectCount, dayCount = 0, 0
			for _ in pairs(effect["$properties"]) do
				effectCount += 1
			end
			for _ in pairs(config.Day[name]) do
				dayCount += 1
			end
			assert(effectCount == dayCount, name .. " has extra $properties")
		end
	end)
	if ok then
		print("[PASS] " .. fileName .. " > Lighting matches GameConfig.Lighting")
	else
		failures += 1
		warn("[FAIL] " .. fileName .. " > Lighting matches GameConfig.Lighting | " .. tostring(err))
	end
end
print(string.format("[SUMMARY] %d run, %d passed, %d failed", total, total - failures, failures))
if failures > 0 then
	process.exit(1)
end
