--!strict
-- Robux purchases recorded in a company save (CM2-46a, schema 17). Pure logic over a company
-- record: `purchases = { receipts, owned, boosts }`.
-- receipts: the purchase IDs this save received, oldest first, written in the same record as
-- their grant, so a replayed receipt never grants twice. owned: count per product key.
-- boosts.CashX2: seconds of the Cash Rush boost left (counts down only while loaded).
local GameConfig = require(script.Parent.GameConfig)
local ShopConfig = require(script.Parent.ShopConfig)

local Purchases = {}

local MAX_OWNED = 10000
local MAX_PURCHASE_ID_BYTES = 64

Purchases.NO_PERKS = table.freeze({
	cashX2 = false,
	reputationX2 = false,
	instantDelivery = false,
	vip = false,
})

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

-- A proper array: keys exactly 1..n. Returns n, or nil when the table is not an array.
local function arrayLength(value: { [any]: any }): number?
	local entries = 0
	local maxKey = 0
	for key in pairs(value) do
		if not isFiniteInteger(key) or key < 1 then
			return nil
		end
		entries += 1
		if key > maxKey then
			maxKey = key
		end
	end
	if maxKey ~= entries then
		return nil
	end
	return entries
end

local function isPurchaseId(value: unknown): boolean
	return type(value) == "string" and #value >= 1 and #value <= MAX_PURCHASE_ID_BYTES
end

function Purchases.new()
	return { receipts = {}, owned = {}, boosts = { CashX2 = 0 } }
end

function Purchases.isValid(state: any): boolean
	local purchases = if type(state) == "table" then state.purchases else nil
	if type(purchases) ~= "table" then
		return false
	end
	local receipts = purchases.receipts
	if type(receipts) ~= "table" then
		return false
	end
	local length = arrayLength(receipts)
	if length == nil or length > ShopConfig.MaxSaveReceipts then
		return false
	end
	for _, purchaseId in ipairs(receipts) do
		if not isPurchaseId(purchaseId) then
			return false
		end
	end
	if type(purchases.owned) ~= "table" then
		return false
	end
	for key, count in pairs(purchases.owned) do
		if not ShopConfig.isKey(key) or not isFiniteInteger(count) or count < 1 or count > MAX_OWNED then
			return false
		end
	end
	local boosts = purchases.boosts
	if type(boosts) ~= "table" then
		return false
	end
	for key in pairs(boosts) do
		if key ~= "CashX2" then
			return false
		end
	end
	local cashX2 = boosts.CashX2
	return isFiniteInteger(cashX2) and cashX2 >= 0 and cashX2 <= ShopConfig.BoostCapSeconds
end

-- Config limits can shrink between builds; trim instead of locking the player out.
function Purchases.normalize(state: any)
	local purchases = if type(state) == "table" then state.purchases else nil
	if type(purchases) ~= "table" then
		return
	end
	local receipts = purchases.receipts
	if type(receipts) == "table" then
		while #receipts > ShopConfig.MaxSaveReceipts do
			table.remove(receipts, 1)
		end
	end
	local boosts = purchases.boosts
	if type(boosts) == "table" and isFiniteInteger(boosts.CashX2) then
		boosts.CashX2 = math.clamp(boosts.CashX2, 0, ShopConfig.BoostCapSeconds)
	end
end

function Purchases.hasReceipt(state: any, purchaseId: string): boolean
	for _, received in ipairs(state.purchases.receipts) do
		if received == purchaseId then
			return true
		end
	end
	return false
end

export type Applied = { cash: number, reputation: number, boostSeconds: number, rested: boolean }

-- Grants one product into the record and records its receipt. Returns the amounts actually
-- applied. Callers check hasReceipt first (CompanyPurchases.grantPurchase).
function Purchases.apply(state: any, product: ShopConfig.Product, purchaseId: string): Applied
	local purchases = state.purchases
	table.insert(purchases.receipts, purchaseId)
	while #purchases.receipts > ShopConfig.MaxSaveReceipts do
		table.remove(purchases.receipts, 1)
	end
	local count = purchases.owned[product.key]
	purchases.owned[product.key] = math.min((if type(count) == "number" then count else 0) + 1, MAX_OWNED)

	local grant: ShopConfig.Grant = product.grant or {}
	local cash = if type(grant.cash) == "number" then grant.cash else 0
	local reputation = if type(grant.reputation) == "number" then grant.reputation else 0
	state.cash += cash
	state.reputation += reputation

	local boostSeconds = 0
	if type(grant.boostSeconds) == "number" then
		local before = purchases.boosts.CashX2
		local after = math.min(before + grant.boostSeconds, ShopConfig.BoostCapSeconds)
		purchases.boosts.CashX2 = after
		boostSeconds = after - before
	end

	local rested = grant.rested == true
	if rested then
		for _, role in ipairs(GameConfig.Staff.Roles) do
			state.staffEnergy[role] = GameConfig.Staff.Energy.Max
		end
	end
	return { cash = cash, reputation = reputation, boostSeconds = boostSeconds, rested = rested }
end

-- The Cash Rush boost counts down by whole seconds while the save is loaded.
function Purchases.tick(state: any, seconds: number)
	if not isFiniteInteger(seconds) or seconds <= 0 then
		return
	end
	local boosts = state.purchases.boosts
	boosts.CashX2 = math.max(0, boosts.CashX2 - seconds)
end

-- Sale cash multiplier: Golden Till x2 times Cash Rush x2 (x4 with both, PROVISIONAL).
function Purchases.cashMultiplier(state: any, perks: any): number
	local multiplier = 1
	if type(perks) == "table" and perks.cashX2 == true then
		multiplier *= ShopConfig.PassCashMultiplier
	end
	if state.purchases.boosts.CashX2 > 0 then
		multiplier *= ShopConfig.BoostCashMultiplier
	end
	return multiplier
end

return Purchases
