--!strict
-- Stocking spot rules (CM2-G14, docs/plans/CM2-G14.md), shared by the client preview and the
-- server. Positions use the lot frame: x is the offset from the plot centre, z the depth toward
-- the road (+ = toward the road). Each tree is a circle with radius FootprintRadius[size].
local GameConfig = require(script.Parent.GameConfig)

local Stocking = {}

export type Tree = { x: number, z: number, sizeId: string }
export type Position = { x: number, z: number }
-- breakArea (CM2-25/26): the centre of the staff break area; trees may not stand in it.
export type LayoutInput = { lotExpansion: number, trees: { Tree }, breakArea: Position? }
export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Error codes of stocking actions and the localization key that explains each one.
Stocking.ErrorKeys = {
	OutsideLot = "stockOutsideLot",
	KeepClear = "stockKeepClear",
	TooClose = "stockTooClose",
	NotEnoughTrees = "stockNotEnough",
	PlacementLimit = "stockPlacementLimit",
	BayChanged = "stockBayChanged",
	HandsFull = "handsFull",
	Reserved = "stockReserved",
	NoFreeBay = "stockNoBay",
	StorageFull = "storageFull",
	UnknownPlacement = "stockUnknownTree",
	RateLimited = "saveErrorRateLimited",
	ConnectionError = "connectionError",
} :: { [string]: string }

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Stocking.radius(sizeId: string): number
	return GameConfig.Placement.FootprintRadius[sizeId] or 0
end

function Stocking.round(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

-- Plots south of the road (centre Z < 0) face +Z; the others face -Z.
function Stocking.facing(centerZ: number): number
	return if centerZ < 0 then 1 else -1
end

-- Row positions p_i = (x + i*s*cos(rotation), z + i*s*sin(rotation)) with s = 2r + gap.
function Stocking.rowPositions(
	x: number,
	z: number,
	rotation: number,
	sizeId: string,
	count: number,
	gap: number
): { Position }
	local step = 2 * Stocking.radius(sizeId) + gap
	local angle = math.rad(rotation)
	local positions: { Position } = {}
	for index = 0, count - 1 do
		table.insert(positions, {
			x = Stocking.round(x + index * step * math.cos(angle)),
			z = Stocking.round(z + index * step * math.sin(angle)),
		})
	end
	return positions
end

-- The displayed trees with a numeric lot position; legacy placements without one are skipped.
function Stocking.layoutInput(state): LayoutInput
	local trees: { Tree } = {}
	local layout = state.layout
	local placements = if type(layout) == "table" and type(layout.placements) == "table" then layout.placements else {}
	for _, placement in pairs(placements) do
		local transform = if type(placement) == "table" then placement.transform else nil
		if type(transform) == "table" and finite(transform.x) and finite(transform.z) then
			table.insert(trees, { x = transform.x, z = transform.z, sizeId = placement.sizeId })
		end
	end
	local progression = state.progression
	local level = if type(progression) == "table" and finite(progression.lotExpansion)
		then progression.lotExpansion
		else 0
	local area = state.breakArea
	local breakArea: Position? = nil
	if type(area) == "table" and finite(area.x) and finite(area.z) then
		breakArea = { x = area.x, z = area.z }
	end
	return { lotExpansion = level, trees = trees, breakArea = breakArea }
end

-- The break area's square (CM2-25/26) for a table with finite x and z, else nil.
function Stocking.breakAreaBox(area: any): Box?
	if type(area) ~= "table" or not finite(area.x) or not finite(area.z) then
		return nil
	end
	local half = GameConfig.Staff.BreakArea.HalfSize
	return { minX = area.x - half, maxX = area.x + half, minZ = area.z - half, maxZ = area.z + half }
end

local function level(input: LayoutInput): number
	local value = if finite(input.lotExpansion) then input.lotExpansion else 0
	return math.clamp(value, 0, GameConfig.Progression.LotExpansion.maxLevel)
end

local function hitsBox(x: number, z: number, r: number, box): boolean
	local closestX = math.clamp(x, box.minX, box.maxX)
	local closestZ = math.clamp(z, box.minZ, box.maxZ)
	local dx, dz = x - closestX, z - closestZ
	return math.sqrt(dx * dx + dz * dz) < r
end

local function tooClose(x: number, z: number, r: number, otherX: number, otherZ: number, otherR: number): boolean
	local dx, dz = x - otherX, z - otherZ
	return math.sqrt(dx * dx + dz * dz) < r + otherR - GameConfig.Placement.SpacingTolerance
end

-- Checks one spot in the fixed order OutsideLot -> KeepClear (static boxes, then the break
-- area) -> TooClose.
function Stocking.check(input: LayoutInput, x: number, z: number, sizeId: string): (boolean, string?)
	local config = GameConfig.Placement
	local r = Stocking.radius(sizeId)
	local backDepth = config.LotHalfDepth + config.BackDepthPerLevel * level(input)
	if
		x - r < -config.LotHalfWidth
		or x + r > config.LotHalfWidth
		or z + r > config.LotHalfDepth
		or z - r < -backDepth
	then
		return false, "OutsideLot"
	end
	for _, box in ipairs(config.KeepClear) do
		if hitsBox(x, z, r, box) then
			return false, "KeepClear"
		end
	end
	local breakBox = Stocking.breakAreaBox(input.breakArea)
	if breakBox ~= nil and hitsBox(x, z, r, breakBox) then
		return false, "KeepClear"
	end
	for _, tree in ipairs(input.trees) do
		if tooClose(x, z, r, tree.x, tree.z, Stocking.radius(tree.sizeId)) then
			return false, "TooClose"
		end
	end
	return true, nil
end

-- Checks every row position, each also against the earlier ones; returns the failing index.
function Stocking.checkRow(input: LayoutInput, positions: { Position }, sizeId: string): (boolean, string?, number?)
	local r = Stocking.radius(sizeId)
	for index, position in ipairs(positions) do
		local ok, code = Stocking.check(input, position.x, position.z, sizeId)
		if not ok then
			return false, code, index
		end
		for earlier = 1, index - 1 do
			local other = positions[earlier]
			if tooClose(position.x, position.z, r, other.x, other.z, r) then
				return false, "TooClose", index
			end
		end
	end
	return true, nil, nil
end

return Stocking
