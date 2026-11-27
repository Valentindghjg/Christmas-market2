--!strict
-- Robux shop products (CM2-46a, docs/archive/plans/CM2-46a.md; PRODUCT_SPEC 2026-11-21 "Monetization
-- and events", REFERENCE_GAME_LIVE_TEST §7). Pure data plus lookups.
-- Every `id` is 0: the owner creates the passes and developer products on Roblox and enters
-- their IDs here later. A product with id 0 or `ready = false` is never prompted. Prices are
-- the OBSERVED Robux prices of the reference. No product grants a random reward (paid random
-- items only from version 2).
local ShopConfig = {}

export type Grant = { cash: number?, reputation: number?, boostSeconds: number?, rested: boolean? }

export type Product = {
	key: string,
	category: string,
	kind: string, -- "Pass" or "Product"
	id: number,
	price: number,
	ready: boolean,
	perPlayer: boolean,
	perk: string?, -- passes only
	grant: Grant?, -- products only; {} = owned count only
}

-- Display order of the shop tabs.
ShopConfig.Categories = { "Starter", "Passes", "Cash", "Boosts", "SpecialTrees", "Event", "PremiumDecor" }

-- The pass perks a save can have (MonetizationService ORs them over its players).
ShopConfig.PerkFields = { "cashX2", "reputationX2", "instantDelivery", "vip" }

local function pass(key: string, price: number, perk: string): Product
	return {
		key = key,
		category = "Passes",
		kind = "Pass",
		id = 0,
		price = price,
		ready = true,
		perPlayer = false,
		perk = perk,
	}
end

local function product(
	key: string,
	category: string,
	price: number,
	ready: boolean,
	perPlayer: boolean,
	grant: Grant
): Product
	return {
		key = key,
		category = category,
		kind = "Product",
		id = 0,
		price = price,
		ready = ready,
		perPlayer = perPlayer,
		grant = grant,
	}
end

-- `ready = false`: the target system (special trees, events CM2-45, decor) does not exist yet;
-- "Coming soon", never prompted. A stray receipt only stores the owned count.
ShopConfig.Products = {
	product("StarterPack", "Starter", 79, true, true, { cash = 20000, reputation = 750 }),
	pass("PassCashX2", 99, "cashX2"),
	pass("PassReputationX2", 79, "reputationX2"),
	pass("PassInstantDelivery", 149, "instantDelivery"),
	pass("PassVip", 199, "vip"),
	product("CashPinecone", "Cash", 29, true, false, { cash = 1200 }),
	product("CashSleigh", "Cash", 99, true, false, { cash = 5000 }),
	product("CashCabin", "Cash", 249, true, false, { cash = 13000 }),
	product("CashVillage", "Cash", 599, true, false, { cash = 34000 }),
	product("CashMountain", "Cash", 1499, true, false, { cash = 90000 }),
	product("BoostCashX2", "Boosts", 10, true, false, { boostSeconds = 1800 }),
	product("BoostRested", "Boosts", 5, true, false, { rested = true }),
	product("TreeFrostcrown", "SpecialTrees", 149, false, true, {}),
	product("TreeHollyberry", "SpecialTrees", 149, false, true, {}),
	product("EventTreeCandlelight", "Event", 199, false, true, {}),
	product("EventTreeStarlight", "Event", 199, false, true, {}),
	product("EventTreeSnowberry", "Event", 199, false, true, {}),
	product("EventDecorPack", "Event", 29, false, false, {}),
	product("DecorLanternBoardwalk", "PremiumDecor", 49, false, false, {}),
	product("DecorFarmTruck", "PremiumDecor", 75, false, false, {}),
	product("DecorSnowGlobe", "PremiumDecor", 79, false, false, {}),
	product("DecorWorkshopElf", "PremiumDecor", 79, false, false, {}),
	product("DecorToyTrain", "PremiumDecor", 99, false, false, {}),
	product("DecorSnowMaker", "PremiumDecor", 99, false, false, {}),
	product("DecorFatherChristmas", "PremiumDecor", 99, false, false, {}),
	product("DecorPhotoCorner", "PremiumDecor", 129, false, false, {}),
	product("DecorVillageExpress", "PremiumDecor", 149, false, false, {}),
}

-- Roblox IDs of the products the owner created (DECISION_LOG 2026-11-24, PC-8); the rest stay 0.
local CREATED_IDS: { [string]: number } = {
	StarterPack = 3735805319,
	PassCashX2 = 2101828296,
	PassReputationX2 = 2099729097,
	PassInstantDelivery = 2099165138,
	PassVip = 2098973055,
	CashPinecone = 3735805373,
	CashSleigh = 3735805396,
	CashCabin = 3735805416,
	CashVillage = 3735805452,
	CashMountain = 3735805469,
	BoostCashX2 = 3735805526,
	BoostRested = 3735805549,
}
for _, entry in ipairs(ShopConfig.Products) do
	entry.id = CREATED_IDS[entry.key] or 0
end

-- Caps and timings (PROVISIONAL unless marked).
ShopConfig.MaxSaveReceipts = 100
ShopConfig.BoostCapSeconds = 21600
ShopConfig.PassCashMultiplier = 2
ShopConfig.BoostCashMultiplier = 2
ShopConfig.ReputationMultiplier = 2 -- OBSERVED
ShopConfig.VipPriceTolerance = 1.15 -- OBSERVED "up to 15%"
ShopConfig.VipStarBonus = 1
ShopConfig.ReceiptWaitSeconds = 60
ShopConfig.ReceiptPollSeconds = 2
ShopConfig.LedgerDoneCap = 200
ShopConfig.LedgerPendingCap = 20
ShopConfig.BoostTickSeconds = 5
ShopConfig.ShopLimit = { limit = 10, window = 10 }

function ShopConfig.byKey(key: unknown): Product?
	for _, entry in ipairs(ShopConfig.Products) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- A developer product by its Roblox ID; never matches an empty ID (0).
function ShopConfig.byProductId(id: unknown): Product?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	for _, entry in ipairs(ShopConfig.Products) do
		if entry.kind == "Product" and entry.id == id then
			return entry
		end
	end
	return nil
end

-- A game pass by its Roblox ID; never matches an empty ID (0).
function ShopConfig.byPassId(id: unknown): Product?
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	for _, entry in ipairs(ShopConfig.Products) do
		if entry.kind == "Pass" and entry.id == id then
			return entry
		end
	end
	return nil
end

-- The localization keys of a product's name and description (CM2-46b).
function ShopConfig.textKeys(entry: Product): (string, string)
	local descKey
	if entry.category == "Cash" then
		descKey = "shopDescCash"
	elseif entry.category == "SpecialTrees" then
		descKey = "shopDescSpecialTree"
	elseif string.sub(entry.key, 1, 9) == "EventTree" then
		descKey = "shopDescEventTree"
	elseif entry.category == "PremiumDecor" then
		descKey = "shopDescPremiumDecor"
	else
		descKey = "shopDesc" .. entry.key
	end
	return "shopName" .. entry.key, descKey
end

-- A product key: a letter, then letters or digits, at most 32 bytes.
function ShopConfig.isKey(value: unknown): boolean
	return type(value) == "string" and #value <= 32 and string.match(value, "^%a%w*$") ~= nil
end

return ShopConfig
