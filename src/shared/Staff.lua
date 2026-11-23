--!strict
-- Staff rules shared by the save schema and the staff director (CM2-25/26,
-- docs/plans/CM2-25-26a.md): gentle energy, the break area and the lot-frame points staff walk
-- to. Pure and deterministic; every point is in the lot frame (x from the plot centre, z the
-- depth toward the road).
local GameConfig = require(script.Parent.GameConfig)
local Stocking = require(script.Parent.Stocking)

local Staff = {}

export type Point = { x: number, z: number }
export type BreakArea = { x: number, z: number, rotation: number }

local function config()
	return GameConfig.Staff
end

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Every role starts fully rested.
function Staff.newEnergy(): { [string]: number }
	local energy = {}
	for _, role in ipairs(config().Roles) do
		energy[role] = config().Energy.Max
	end
	return energy
end

-- Drains on shift, recovers while resting; always within 0..Max.
function Staff.stepEnergy(energy: number, dt: number, resting: boolean): number
	local rules = config().Energy
	local rate = if resting then rules.RestPerSecond else -rules.DrainPerSecond
	return math.clamp(energy + rate * dt, 0, rules.Max)
end

function Staff.isTired(energy: number): boolean
	return energy <= config().Energy.TiredAt
end

function Staff.isRested(energy: number): boolean
	return energy >= config().Energy.RestedAt
end

local function level(input: Stocking.LayoutInput): number
	local value = if finite(input.lotExpansion) then input.lotExpansion else 0
	return math.clamp(value, 0, GameConfig.Progression.LotExpansion.maxLevel)
end

-- A circle (x, z, r) touches the box (same rule as Stocking's spot check).
local function hitsBox(x: number, z: number, r: number, box: Stocking.Box): boolean
	local closestX = math.clamp(x, box.minX, box.maxX)
	local closestZ = math.clamp(z, box.minZ, box.maxZ)
	local dx, dz = x - closestX, z - closestZ
	return math.sqrt(dx * dx + dz * dz) < r
end

local function overlaps(a: Stocking.Box, b): boolean
	return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
end

-- Whether the break area may stand at (x, z): inside the lot at input.lotExpansion, clear of
-- every keep-clear box, decor fence and tree. input.breakArea is ignored.
function Staff.checkBreakArea(input: Stocking.LayoutInput, x: number, z: number): (boolean, string?)
	if not finite(x) or not finite(z) then
		return false, "InvalidBreakArea"
	end
	local placement = GameConfig.Placement
	local box = Stocking.breakAreaBox({ x = x, z = z }) :: Stocking.Box
	local backDepth = placement.LotHalfDepth + placement.BackDepthPerLevel * level(input)
	if
		box.minX < -placement.LotHalfWidth
		or box.maxX > placement.LotHalfWidth
		or box.maxZ > placement.LotHalfDepth
		or box.minZ < -backDepth
	then
		return false, "OutsideLot"
	end
	for _, keepClear in ipairs(placement.KeepClear) do
		if overlaps(box, keepClear) then
			return false, "KeepClear"
		end
	end
	for _, fence in ipairs(placement.DecorFences) do
		if hitsBox(fence.x, fence.z, placement.DecorFenceRadius, box) then
			return false, "KeepClear"
		end
	end
	for _, tree in ipairs(input.trees) do
		if hitsBox(tree.x, tree.z, Stocking.radius(tree.sizeId), box) then
			return false, "TooClose"
		end
	end
	return true, nil
end

-- The first candidate spot that is free in this save, else candidate 1; rotation 0.
function Staff.defaultBreakArea(state): BreakArea
	local candidates = config().BreakArea.Candidates
	local input = Stocking.layoutInput(state)
	for _, candidate in ipairs(candidates) do
		if Staff.checkBreakArea(input, candidate.x, candidate.z) then
			return { x = candidate.x, z = candidate.z, rotation = 0 }
		end
	end
	return { x = candidates[1].x, z = candidates[1].z, rotation = 0 }
end

-- An area-frame offset in the lot frame; rotation 90 maps (0, 3.6) to (3.6, 0).
function Staff.toLot(area: BreakArea, offset: Point): Point
	local r = math.rad(area.rotation)
	return {
		x = area.x + offset.x * math.cos(r) + offset.z * math.sin(r),
		z = area.z - offset.x * math.sin(r) + offset.z * math.cos(r),
	}
end

-- The role's seat at the campfire (index of the role in Staff.Roles).
function Staff.restPoint(area: BreakArea, role: string): Point
	local index = table.find(config().Roles, role) or 1
	return Staff.toLot(area, config().BreakArea.RestPoints[index])
end

-- Where the Lot Worker stands to take the pickup tree of parking space `space`.
function Staff.pickupApproach(space: number): Point
	local pickup = config().Pickup
	return { x = pickup.FirstX + pickup.Step * (math.clamp(space, 1, 4) - 1), z = pickup.ApproachZ }
end

-- Where the Lot Worker stands to take a tree from receiving bay `bay`.
function Staff.bayApproach(bay: number): Point
	return { x = config().BayApproachX, z = -22 + 6 * (bay - 1) }
end

return Staff
