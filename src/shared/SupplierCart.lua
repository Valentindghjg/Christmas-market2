--!strict
-- Supplier cart (CM2-SUP, docs/plans/CM2-SUP.md): validation, cost and bay packing of a
-- multi-line supplier order. The server re-checks every cart with `normalize`; the client
-- uses the same math (maxAdd, deliveryArea) only for convenience.
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local SupplierCart = {}

export type Line = { speciesId: string, sizeId: string, quantity: number }
export type GroupLine = { sizeId: string, quantity: number }
export type Group = { speciesId: string, total: number, lines: { GroupLine } }
export type Limits = {
	cash: number,
	freeBays: number,
	storageFree: number,
	stock: { [string]: number },
}

local LINE_KEYS = { speciesId = true, sizeId = true, quantity = true }

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function bayCapacity(): number
	return GameConfig.Receiving.BayCapacity
end

local function speciesRank(speciesId: string): number
	for index, candidate in ipairs(GameConfig.SpeciesOrder) do
		if candidate == speciesId then
			return index
		end
	end
	return math.huge
end

local function sizeRank(sizeId: string): number
	for index, candidate in ipairs(GameConfig.SizeIds) do
		if candidate == sizeId then
			return index
		end
	end
	return math.huge
end

local function countOf(map: { [string]: number }?, key: string): number
	if map == nil then
		return 0
	end
	local value = map[key]
	return if isFiniteInteger(value) and (value :: number) > 0 then value :: number else 0
end

-- Validates an untrusted cart and returns new, sorted line tables (never the client's tables).
function SupplierCart.normalize(lines: unknown): ({ Line }?, string?)
	if type(lines) ~= "table" then
		return nil, "InvalidCart"
	end
	local source = lines :: { [unknown]: unknown }
	local count = 0
	for _ in pairs(source) do
		count += 1
	end
	if count == 0 or count > GameConfig.Supplier.MaxCartLines then
		return nil, "InvalidCart"
	end
	for key in pairs(source) do
		if not isFiniteInteger(key) or (key :: number) < 1 or (key :: number) > count then
			return nil, "InvalidCart"
		end
	end
	local result: { Line } = {}
	local seen: { [string]: boolean } = {}
	local total = 0
	for index = 1, count do
		local line = source[index]
		if type(line) ~= "table" then
			return nil, "UnexpectedField"
		end
		local entry = line :: { [unknown]: unknown }
		for key in pairs(entry) do
			if type(key) ~= "string" or not LINE_KEYS[key] then
				return nil, "UnexpectedField"
			end
		end
		local speciesId = entry.speciesId
		local sizeId = entry.sizeId
		if type(speciesId) ~= "string" or not GameConfig.Trees[speciesId] or not GameConfig.isValidSize(sizeId) then
			return nil, "InvalidItem"
		end
		local quantity = entry.quantity
		if
			not isFiniteInteger(quantity)
			or (quantity :: number) < 1
			or (quantity :: number) > GameConfig.MaxOrderQuantity
		then
			return nil, "InvalidQuantity"
		end
		local key = Inventory.key(speciesId, sizeId :: string)
		if seen[key] then
			return nil, "DuplicateLine"
		end
		seen[key] = true
		total += quantity :: number
		table.insert(result, { speciesId = speciesId, sizeId = sizeId :: string, quantity = quantity :: number })
	end
	if total > GameConfig.MaxOrderQuantity then
		return nil, "InvalidQuantity"
	end
	table.sort(result, function(a: Line, b: Line): boolean
		local aRank, bRank = speciesRank(a.speciesId), speciesRank(b.speciesId)
		if aRank ~= bRank then
			return aRank < bRank
		end
		if a.speciesId ~= b.speciesId then
			return a.speciesId < b.speciesId
		end
		return sizeRank(a.sizeId) < sizeRank(b.sizeId)
	end)
	return result, nil
end

-- Cart lines from a client count map ("<speciesId>:<sizeId>" -> quantity), species then sizes.
function SupplierCart.fromCounts(counts: { [string]: number }): { Line }
	local lines: { Line } = {}
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local quantity = countOf(counts, Inventory.key(speciesId, sizeId))
			if quantity > 0 then
				table.insert(lines, { speciesId = speciesId, sizeId = sizeId, quantity = quantity })
			end
		end
	end
	return lines
end

function SupplierCart.total(lines: { Line }): number
	local total = 0
	for _, line in ipairs(lines) do
		total += line.quantity
	end
	return total
end

function SupplierCart.cost(lines: { Line }): number
	local cost = 0
	for _, line in ipairs(lines) do
		cost += (GameConfig.wholesaleFor(line.speciesId, line.sizeId) or 0) * line.quantity
	end
	return cost
end

-- Per species (SpeciesOrder), sizes in SizeIds order fill groups of at most BayCapacity trees;
-- a line larger than the room left splits across groups. One group = one bay.
function SupplierCart.pack(lines: { Line }): { Group }
	local groups: { Group } = {}
	local capacity = bayCapacity()
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		local current: Group? = nil
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local remaining = 0
			for _, line in ipairs(lines) do
				if line.speciesId == speciesId and line.sizeId == sizeId then
					remaining += line.quantity
				end
			end
			while remaining > 0 do
				if current == nil or current.total >= capacity then
					local fresh: Group = { speciesId = speciesId, total = 0, lines = {} }
					table.insert(groups, fresh)
					current = fresh
				end
				local group = current :: Group
				local put = math.min(capacity - group.total, remaining)
				table.insert(group.lines, { sizeId = sizeId, quantity = put })
				group.total += put
				remaining -= put
			end
		end
	end
	return groups
end

local function speciesTotals(lines: { Line }): { [string]: number }
	local totals: { [string]: number } = {}
	for _, line in ipairs(lines) do
		totals[line.speciesId] = (totals[line.speciesId] or 0) + line.quantity
	end
	return totals
end

local function baysFor(trees: number): number
	return math.ceil(trees / bayCapacity())
end

function SupplierCart.baysNeeded(lines: { Line }): number
	local bays = 0
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		local trees = speciesTotals(lines)[speciesId] or 0
		bays += baysFor(trees)
	end
	return bays
end

-- How many more trees of one SKU the cart can take under the tightest limit; never negative.
function SupplierCart.maxAdd(counts: { [string]: number }, speciesId: string, sizeId: string, limits: Limits): number
	local unit = GameConfig.wholesaleFor(speciesId, sizeId)
	if unit == nil or unit <= 0 then
		return 0
	end
	local key = Inventory.key(speciesId, sizeId)
	local lines = SupplierCart.fromCounts(counts)
	local total = SupplierCart.total(lines)
	local cost = SupplierCart.cost(lines)
	local totals = speciesTotals(lines)
	local otherBays = 0
	for otherId, trees in pairs(totals) do
		if otherId ~= speciesId then
			otherBays += baysFor(trees)
		end
	end
	local speciesTotal = totals[speciesId] or 0
	local capacity = bayCapacity()
	local value = math.min(
		countOf(limits.stock, key) - countOf(counts, key),
		GameConfig.MaxOrderQuantity - total,
		(limits.storageFree or 0) - total,
		math.floor(((limits.cash or 0) - cost) / unit),
		capacity * ((limits.freeBays or 0) - otherBays) - speciesTotal
	)
	return math.max(0, value)
end

-- (free, capacity) of the delivery area: BayCapacity trees per free bay minus the cart.
function SupplierCart.deliveryArea(counts: { [string]: number }, freeBays: number): (number, number)
	local capacity = bayCapacity() * freeBays
	local total = SupplierCart.total(SupplierCart.fromCounts(counts))
	return math.max(0, capacity - total), capacity
end

-- CM2-SUPQ: clamps the sell-back quantity of one row to `bound` (clearing it at 0) and writes the
-- clamped value to the row's Qty label, so a hidden or sold-out row never keeps a stale number.
function SupplierCart.applySellQty(
	sellQty: { [string]: number },
	key: string,
	bound: number,
	label: { Text: string }
): number
	local qty = math.min(sellQty[key] or 0, math.max(0, bound))
	sellQty[key] = if qty > 0 then qty else nil
	label.Text = tostring(qty)
	return qty
end

return SupplierCart
