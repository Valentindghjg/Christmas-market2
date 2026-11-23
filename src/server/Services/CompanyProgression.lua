--!strict
-- Progression of the company service (CM2-G9a, docs/plans/CM2-G9a.md): a mixin that
-- CompanyStateService installs. Its _dispatch runs the three Progression.Buy* actions through
-- buy() (ProgressionService, idempotency and limits come from handle); this mixin tells trusted
-- server code (main.server.lua: stand, lot pad, fence, parking) when the saved ladder changed
-- and holds the Studio test setter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local Config = GameConfig.Progression

local CompanyProgression = {}

local MAX_TEST_VALUE = 1e9

-- The purchase actions; the stand, lot pad, fence and parking follow them.
CompanyProgression.ACTIONS = {
	[Protocol.Actions.ProgressionBuyLotExpansion] = true,
	[Protocol.Actions.ProgressionBuyParking] = true,
	[Protocol.Actions.ProgressionBuyHQ] = true,
}

-- One validated purchase inside _dispatch (must not yield): lot {level}, parking {tier}, HQ {level}.
function CompanyProgression.buy(state, action: string, payload): (boolean, any)
	if action == Protocol.Actions.ProgressionBuyLotExpansion then
		return ProgressionService.buyLotExpansion(state, payload.level)
	elseif action == Protocol.Actions.ProgressionBuyParking then
		return ProgressionService.buyParking(state, payload.tier)
	elseif action == Protocol.Actions.ProgressionBuyHQ then
		return ProgressionService.buyHQ(state, payload.level)
	end
	return false, "UnknownAction"
end

-- setProgressionForTest: each allowed field and its integer range.
local TEST_FIELDS = {
	cash = { min = 0, max = MAX_TEST_VALUE },
	reputation = { min = 0, max = MAX_TEST_VALUE },
	lotExpansion = { min = 0, max = Config.LotExpansion.maxLevel },
	parkingTier = { min = 1, max = Config.Parking.maxTier },
	hqLevel = { min = 1, max = Config.HQ.maxLevel },
	lotManager = { min = 0, max = 1 },
}

local function isInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and math.floor(value) == value
end

local function validTestFields(fields): boolean
	if type(fields) ~= "table" then
		return false
	end
	for key, value in pairs(fields) do
		local range = TEST_FIELDS[key]
		if range == nil or not isInteger(value) or value < range.min or value > range.max then
			return false
		end
	end
	return true
end

function CompanyProgression.install(CompanyStateService)
	function CompanyStateService:setProgressionChangedHandler(handler: (companyId: string, progression: any) -> ())
		self._progressionChanged = handler
	end

	function CompanyStateService:_notifyProgression(companyId: string, session)
		local handler = self._progressionChanged
		if handler and self._sessions[companyId] == session then
			local ok, err = pcall(handler, companyId, table.clone(session.state.progression))
			if not ok then
				warn(string.format("[ChristmasMarket2] progression notify failed for %s: %s", companyId, tostring(err)))
			end
		end
	end

	-- handle: after a successful purchase (response.progressionChanged), notifies and clears the flag.
	function CompanyStateService:_syncProgression(companyId: string, session, response)
		if response.progressionChanged then
			self:_notifyProgression(companyId, session)
		end
		response.progressionChanged = nil
	end

	-- Studio test instrument only (StudioTestService setProgression): sets cash, reputation, the
	-- ladder fields and the Lot Manager without a purchase. A bad field changes nothing.
	function CompanyStateService:setProgressionForTest(companyId: string, fields): boolean
		if not validTestFields(fields) then
			return false
		end
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			for key, value in pairs(fields) do
				if key == "cash" or key == "reputation" then
					state[key] = value
				elseif key == "lotManager" then
					state.staff.LotManager = value
				else
					state.progression[key] = value
				end
			end
			state.revision += 1
			session.dirty = true
			return true
		end)
		if entered then
			self:_notifyProgression(companyId, session)
		end
		return entered
	end
end

return CompanyProgression
