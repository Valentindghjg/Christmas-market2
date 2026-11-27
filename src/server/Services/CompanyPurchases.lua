--!strict
-- Robux purchases of the company service (CM2-46a, docs/archive/plans/CM2-46a.md): a mixin that
-- CompanyStateService installs. Server-trusted callers only (MonetizationService and the
-- server loop); no client request reaches these methods.
-- Pass perks are runtime only (never saved): MonetizationService sets them per company from
-- the passes of the players on the save. A grant writes the receipt into the same record and
-- saves it at once, so a replayed receipt never grants twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local Purchases = require(Shared:WaitForChild("Purchases"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local CompanyPurchases = {}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[deepCopy(key)] = deepCopy(inner)
	end
	return copy
end

-- The Shop panel's summary: Cash Rush seconds left and the save's active pass perks.
function CompanyPurchases.summary(service, companyId: string, state)
	return {
		cashBoostSeconds = state.purchases.boosts.CashX2,
		perks = table.clone(service:perksOf(companyId)),
	}
end

-- Detached copy of the record's purchases (Studio playtests).
function CompanyPurchases.snapshot(state)
	return deepCopy(state.purchases)
end

function CompanyPurchases.install(CompanyStateService)
	-- Stores a copy of the save's pass perks (ShopConfig.PerkFields, booleans).
	function CompanyStateService:setPerks(companyId: string, perks)
		if self._perks == nil then
			self._perks = {}
		end
		local copy = {}
		for _, field in ipairs(ShopConfig.PerkFields) do
			copy[field] = type(perks) == "table" and perks[field] == true
		end
		self._perks[companyId] = copy
	end

	function CompanyStateService:perksOf(companyId: string)
		local stored = if self._perks ~= nil then self._perks[companyId] else nil
		return stored or Purchases.NO_PERKS
	end

	-- Evergreen VIP customers pay up to 15 % over their budget; nil without the perk.
	function CompanyStateService:priceTolerance(companyId: string): number?
		return if self:perksOf(companyId).vip then ShopConfig.VipPriceTolerance else nil
	end

	function CompanyStateService:cashMultiplierOf(companyId: string, state): number
		return Purchases.cashMultiplier(state, self:perksOf(companyId))
	end

	-- Cash Rush seconds left in a healthy live session; nil without one.
	function CompanyStateService:boostSeconds(companyId: string): number?
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return nil
		end
		return session.state.purchases.boosts.CashX2
	end

	-- Grants one product into the live record exactly once and saves it at once. Returns
	-- (true, nil, applied) after a successful save. applied is true when this call wrote the
	-- receipt into the live record, also when the save failed, and false when the record
	-- already held it (Amendment 1: the effect follows the live record). (false, "SaveFailed",
	-- applied) when the save failed, (false, code) when the section was not entered.
	function CompanyStateService:grantPurchase(
		companyId: string,
		purchaseId: string,
		product
	): (boolean, string?, boolean?)
		local session = self._sessions[companyId]
		if not session then
			return false, "CompanyUnavailable", nil
		end
		local entered, applied = self:_withSession(companyId, session, function(state)
			if Purchases.hasReceipt(state, purchaseId) then
				return false
			end
			local result = Purchases.apply(state, product, purchaseId)
			if result.cash > 0 then
				BusinessState.record(state, "RobuxPurchase", result.cash)
			end
			state.revision += 1
			session.dirty = true
			return true
		end)
		if not entered then
			return false, applied, nil
		end
		local saved = self:_save(companyId, session)
		if not saved then
			return false, "SaveFailed", applied
		end
		return true, nil, applied
	end

	-- Counts Cash Rush down in every healthy session. Boost time rides along with the next
	-- save: no dirty flag, no revision. Returns (true, ticked, 0) for the server loop.
	function CompanyStateService:tickBoostsAll(seconds: number): (boolean, number, number)
		local ticked = 0
		for _, companyId in ipairs(self:_companyIds()) do
			local session = self._sessions[companyId]
			if session and session.healthy and not session.unloading then
				local entered, changed = self:_withSession(companyId, session, function(state)
					local before = state.purchases.boosts.CashX2
					Purchases.tick(state, seconds)
					return state.purchases.boosts.CashX2 ~= before
				end)
				if entered and changed then
					ticked += 1
				end
			end
		end
		return true, ticked, 0
	end
end

return CompanyPurchases
