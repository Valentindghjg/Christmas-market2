--!strict
-- The progression ladder (CM2-G9a, docs/archive/plans/CM2-G9a.md): lot expansion levels, parking tiers,
-- HQ tiers and the Elf Workshop. Pure logic over GameConfig.Progression and a company record;
-- no Roblox types. ProgressionService buys through check(), and the summary shows the same
-- rows(), so the client sees every requirement exactly as the server checks it.
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.Progression
local Npc = GameConfig.Customers.Npc
local Placement = GameConfig.Placement

local Progression = {}

export type Row = { id: string, have: number, need: number, met: boolean }
export type Unlock = { id: string, value: number?, active: boolean }
export type Offer = {
	kind: string,
	target: number,
	id: string,
	cashCost: number,
	rows: { Row },
	unlocks: { Unlock },
	ready: boolean,
}
export type Box = { id: string, minX: number, maxX: number, minZ: number, maxZ: number }

-- The error code of a purchase refused for its first unmet row.
Progression.ROW_CODES = {
	HqLevel = "PrerequisitesNotMet",
	LotExpansion = "PrerequisitesNotMet",
	ParkingTier = "PrerequisitesNotMet",
	LotManager = "PrerequisitesNotMet",
	Reputation = "InsufficientReputation",
	Cash = "InsufficientFunds",
}

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isInteger(value: unknown): boolean
	return finite(value) and math.floor(value :: number) == value
end

local function numberOr(value: unknown, fallback: number): number
	return if finite(value) then value :: number else fallback
end

local function savedLevel(state, field: string, minimum: number, maximum: number): number
	local progression = if type(state) == "table" then state.progression else nil
	local value = if type(progression) == "table" then progression[field] else nil
	if not finite(value) then
		return minimum
	end
	return math.clamp(math.floor(value :: number), minimum, maximum)
end

function Progression.new()
	return { lotExpansion = 0, parkingTier = 1, hqLevel = 1 }
end

-- Schema 18 -> 19: { lotExpansion, parkingSpaces, hqTier } becomes { lotExpansion, parkingTier,
-- hqLevel }. A save that paid for parking space 3 gets tier 2; no money moves.
function Progression.migrate18(old)
	if type(old) ~= "table" then
		return Progression.new()
	end
	return {
		lotExpansion = old.lotExpansion,
		parkingTier = if type(old.parkingSpaces) == "number" and old.parkingSpaces >= 3 then 2 else 1,
		hqLevel = if old.hqTier == "ChristmasPavilion" then 2 else 1,
	}
end

function Progression.lotLevel(state): number
	return savedLevel(state, "lotExpansion", 0, Config.LotExpansion.maxLevel)
end

function Progression.parkingTier(state): number
	return savedLevel(state, "parkingTier", 1, Config.Parking.maxTier)
end

function Progression.hqLevel(state): number
	return savedLevel(state, "hqLevel", 1, Config.HQ.maxLevel)
end

function Progression.parkingSpaces(state): number
	return Config.Parking.tiers[Progression.parkingTier(state)].spaces
end

function Progression.employeeCapacity(state): number
	return Config.HQ.tiers[Progression.hqLevel(state)].employeeCapacity
end

-- Queue patience in seconds at an HQ level: 90, 101, 108, 117.
function Progression.queuePatienceFor(level: number): number
	local tier = Config.HQ.tiers[math.clamp(math.floor(level), 1, Config.HQ.maxLevel)]
	return math.floor(Npc.QueuePatienceSeconds * (1 + tier.customerPatienceBonus) + 0.5)
end

function Progression.queuePatienceSeconds(state): number
	return Progression.queuePatienceFor(Progression.hqLevel(state))
end

-- Per kind: the highest target, the current level and the config entry of a target.
local KINDS = {
	LotExpansion = {
		max = Config.LotExpansion.maxLevel,
		current = Progression.lotLevel,
		entry = function(target: number)
			return Config.LotExpansion.levels[target]
		end,
	},
	Parking = {
		max = Config.Parking.maxTier,
		current = Progression.parkingTier,
		entry = function(target: number)
			return Config.Parking.tiers[target]
		end,
	},
	HQ = {
		max = Config.HQ.maxLevel,
		current = Progression.hqLevel,
		entry = function(target: number)
			return Config.HQ.tiers[target]
		end,
	},
}

local function row(id: string, have: number, need: number): Row
	return { id = id, have = have, need = need, met = have >= need }
end

-- The requirements of buying `target` of `kind`, in the fixed order HqLevel, LotExpansion,
-- ParkingTier, Reputation, Cash; a row only where the entry has the field above its start value.
function Progression.rows(state, kind: string, target: number): { Row }
	local spec = KINDS[kind]
	local entry = if spec then spec.entry(target) else nil
	if type(entry) ~= "table" then
		return {}
	end
	local rows: { Row } = {}
	if type(entry.requiredHqLevel) == "number" and entry.requiredHqLevel > 1 then
		table.insert(rows, row("HqLevel", Progression.hqLevel(state), entry.requiredHqLevel))
	end
	if type(entry.requiredLotExpansion) == "number" and entry.requiredLotExpansion > 0 then
		table.insert(rows, row("LotExpansion", Progression.lotLevel(state), entry.requiredLotExpansion))
	end
	if type(entry.requiredParkingTier) == "number" and entry.requiredParkingTier > 1 then
		table.insert(rows, row("ParkingTier", Progression.parkingTier(state), entry.requiredParkingTier))
	end
	if type(entry.requiredReputation) == "number" and entry.requiredReputation > 0 then
		table.insert(rows, row("Reputation", numberOr(state.reputation, 0), entry.requiredReputation))
	end
	table.insert(rows, row("Cash", numberOr(state.cash, 0), entry.cashCost))
	return rows
end

-- Whether `target` of `kind` may be bought now: InvalidLevel, AlreadyOwned, NotNextLevel, then
-- the ROW_CODES code of the first unmet row.
function Progression.check(state, kind: string, target: unknown): (boolean, string?)
	local spec = KINDS[kind]
	if spec == nil or not isInteger(target) or (target :: number) < 1 or (target :: number) > spec.max then
		return false, "InvalidLevel"
	end
	local level = target :: number
	local current = spec.current(state)
	if level <= current then
		return false, "AlreadyOwned"
	end
	if level > current + 1 then
		return false, "NotNextLevel"
	end
	for _, entry in Progression.rows(state, kind, level) do
		if not entry.met then
			return false, Progression.ROW_CODES[entry.id]
		end
	end
	return true, nil
end

-- What buying `target` of `kind` unlocks (derived, never stored). Inactive entries show
-- "coming soon" (new species and more counters come with CM2-G9d, the workshop's content later).
function Progression.unlocks(kind: string, target: number): { Unlock }
	if kind == "LotExpansion" then
		return {
			{ id = "DisplaySpace", value = Placement.BackDepthPerLevel, active = true },
			{ id = "DeliveryStorage", value = GameConfig.Receiving.StoragePerLotExpansion, active = true },
		}
	end
	if kind == "Parking" then
		local tier = Config.Parking.tiers[target]
		return if tier then { { id = "ParkingSpaces", value = tier.spaces, active = true } } else {}
	end
	local tier = if kind == "HQ" then Config.HQ.tiers[target] else nil
	if tier == nil then
		return {}
	end
	local previous = Config.HQ.tiers[target - 1]
	local list: { Unlock } = {}
	if tier.newSpecies > 0 then
		table.insert(list, { id = "NewSpecies", value = tier.newSpecies, active = false })
	end
	if previous == nil or tier.checkoutStations > previous.checkoutStations then
		table.insert(list, { id = "CheckoutStations", value = tier.checkoutStations, active = false })
	end
	table.insert(list, { id = "EmployeeCapacity", value = tier.employeeCapacity, active = true })
	if tier.customerPatienceBonus > 0 then
		local percent = math.floor(tier.customerPatienceBonus * 100 + 0.5)
		table.insert(list, { id = "CustomerPatience", value = percent, active = true })
	end
	if tier.unlocksLotManager then
		table.insert(list, { id = "LotManager", active = true })
	end
	if tier.unlocksWorkshop then
		table.insert(list, { id = "ElfWorkshop", active = false })
	end
	return list
end

-- Parking tiers carry no config id; their offer is named "ParkingTier<n>".
local function offerId(kind: string, target: number, entry): string
	if type(entry.id) == "string" then
		return entry.id
	end
	return kind .. "Tier" .. target
end

-- The next purchase of `kind`; nil once the kind is at its highest level.
function Progression.offer(state, kind: string): Offer?
	local spec = KINDS[kind]
	if spec == nil then
		return nil
	end
	local current = spec.current(state)
	if current >= spec.max then
		return nil
	end
	local target = current + 1
	local entry = spec.entry(target)
	local rows = Progression.rows(state, kind, target)
	local ready = true
	for _, requirement in rows do
		ready = ready and requirement.met
	end
	return {
		kind = kind,
		target = target,
		id = offerId(kind, target, entry),
		cashCost = entry.cashCost,
		rows = rows,
		unlocks = Progression.unlocks(kind, target),
		ready = ready,
	}
end

-- The Elf Workshop: unlocked with HQ 4 and a hired Lot Manager; no cost, no action.
function Progression.workshop(state)
	local config = Config.Workshop
	local rows: { Row } = { row("HqLevel", Progression.hqLevel(state), config.requiredHqLevel) }
	if config.requiresLotManager then
		local staff = if type(state) == "table" and type(state.staff) == "table" then state.staff else {}
		table.insert(rows, row("LotManager", numberOr(staff.LotManager, 0), 1))
	end
	local unlocked = true
	for _, entry in rows do
		unlocked = unlocked and entry.met
	end
	return { unlocked = unlocked, rows = rows }
end

-- The summary's ladder (Company.GetSummary `progression`).
function Progression.summary(state)
	local lot = Progression.lotLevel(state)
	local tier = Progression.parkingTier(state)
	local hq = Progression.hqLevel(state)
	return {
		lotExpansion = {
			level = lot,
			maxLevel = Config.LotExpansion.maxLevel,
			storage = GameConfig.Receiving.BaseStorage + lot * GameConfig.Receiving.StoragePerLotExpansion,
			next = Progression.offer(state, "LotExpansion"),
		},
		parking = {
			tier = tier,
			maxTier = Config.Parking.maxTier,
			spaces = Progression.parkingSpaces(state),
			next = Progression.offer(state, "Parking"),
		},
		hq = {
			level = hq,
			maxLevel = Config.HQ.maxLevel,
			id = Config.HQ.tiers[hq].id,
			next = Progression.offer(state, "HQ"),
		},
		workshop = Progression.workshop(state),
	}
end

-- The lot fence at expansion level `level` in the lot frame: the back rail just behind the lot
-- edge and, once the lot grew, both side rails from the starter lot's back edge to it.
function Progression.fenceBoxes(level: number): { Box }
	local growth = math.clamp(math.floor(numberOr(level, 0)), 0, Config.LotExpansion.maxLevel)
	local back = Placement.LotHalfDepth + Placement.BackDepthPerLevel * growth
	local half = Placement.LotHalfWidth
	local boxes: { Box } = {
		{ id = "Back", minX = -(half + 0.6), maxX = half + 0.6, minZ = -(back + 0.6), maxZ = -(back + 0.3) },
	}
	if growth >= 1 then
		local starter = -Placement.LotHalfDepth
		table.insert(
			boxes,
			{ id = "Left", minX = -(half + 0.6), maxX = -(half + 0.3), minZ = -(back + 0.6), maxZ = starter }
		)
		table.insert(
			boxes,
			{ id = "Right", minX = half + 0.3, maxX = half + 0.6, minZ = -(back + 0.6), maxZ = starter }
		)
	end
	return boxes
end

return Progression
