--!strict
-- Walking routes of customer NPCs (CM2-N1, docs/plans/CM2-N1.md). Pure and deterministic:
-- every point is in the lot frame (x from the plot centre, z the depth toward the road), and
-- the obstacles are the known keep-clear boxes, so no navmesh is needed and routes are
-- headless-testable. toWorld/fromWorld mirror plots north of the road (Stocking.facing).
local GameConfig = require(script.Parent.GameConfig)
local Stocking = require(script.Parent.Stocking)

local NpcPath = {}

export type Point = { x: number, z: number }
export type Box = { id: string?, minX: number, maxX: number, minZ: number, maxZ: number }

local PUSH_MARGIN = 0.01
local SHRINK = 0.01
local MAX_PUSH_PASSES = 3

local function config()
	return GameConfig.Customers.Npc
end

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function point(x: number, z: number): Point
	return { x = x, z = z }
end

-- The customer's car door beside parking space `space`.
function NpcPath.door(space: number): Point
	local path = config().Path
	return point(path.ParkingFirstX + path.ParkingStep * (space - 1) + path.DoorOffsetX, path.ParkingDepth)
end

-- The aisle point in front of parking space `space`.
function NpcPath.aisle(space: number): Point
	return point(NpcPath.door(space).x, config().Path.AisleDepth)
end

-- Queue slot `index` (1 = at the counter).
function NpcPath.queueSlot(index: number): Point
	local path = config().Path
	return point(path.QueueX, path.QueueFirstDepth + path.QueueSpacing * (index - 1))
end

-- Where the cashier stands behind the counter (CM2-N2, CM2-25/26).
function NpcPath.staffPoint(): Point
	local path = config().Path
	return point(path.QueueX, path.StaffDepth)
end

local function inflate(box, id: string, clearance: number): Box
	return {
		id = id,
		minX = box.minX - clearance,
		maxX = box.maxX + clearance,
		minZ = box.minZ - clearance,
		maxZ = box.maxZ + clearance,
	}
end

-- The sales stand and the receiving bays inflated by Clearance, the counter by
-- CounterClearance (Fix round 1), in the order Stand, Counter, Bays.
function NpcPath.obstacles(): { Box }
	local clearance = config().Clearance
	local byId = {}
	for _, box in ipairs(GameConfig.Placement.KeepClear) do
		byId[box.id] = box
	end
	return {
		inflate(byId.Stand, "Stand", clearance),
		inflate(config().Path.Counter, "Counter", config().CounterClearance),
		inflate(byId.Bays, "Bays", clearance),
	}
end

local function strictlyInside(p: Point, box: Box): boolean
	return p.x > box.minX and p.x < box.maxX and p.z > box.minZ and p.z < box.maxZ
end

-- Liang-Barsky: the length of segment a-b inside the box.
local function clippedLength(a: Point, b: Point, box: Box): number
	local dx, dz = b.x - a.x, b.z - a.z
	local t0, t1 = 0, 1
	local ps = { -dx, dx, -dz, dz }
	local qs = { a.x - box.minX, box.maxX - a.x, a.z - box.minZ, box.maxZ - a.z }
	for index = 1, 4 do
		local p, q = ps[index], qs[index]
		if p == 0 then
			if q < 0 then
				return 0
			end
		else
			local t = q / p
			if p < 0 then
				t0 = math.max(t0, t)
			else
				t1 = math.min(t1, t)
			end
			if t0 > t1 then
				return 0
			end
		end
	end
	return (t1 - t0) * math.sqrt(dx * dx + dz * dz)
end

-- False when the segment runs through any box (each shrunk by 0.01 per side).
function NpcPath.segmentClear(a: Point, b: Point, boxes: { Box }): boolean
	for _, box in ipairs(boxes) do
		local shrunk = {
			minX = box.minX + SHRINK,
			maxX = box.maxX - SHRINK,
			minZ = box.minZ + SHRINK,
			maxZ = box.maxZ - SHRINK,
		}
		if clippedLength(a, b, shrunk) > 0 then
			return false
		end
	end
	return true
end

function NpcPath.inLot(p: Point, level: number): boolean
	local placement = GameConfig.Placement
	local backDepth = placement.LotHalfDepth + placement.BackDepthPerLevel * level
	return math.abs(p.x) <= placement.LotHalfWidth and p.z >= -backDepth and p.z <= placement.LotHalfDepth
end

function NpcPath.distance(a: Point, b: Point): number
	local dx, dz = b.x - a.x, b.z - a.z
	return math.sqrt(dx * dx + dz * dz)
end

-- Moves a point that lies strictly inside a box to that box's nearest edge + 0.01
-- (ties in the order minX, maxX, minZ, maxZ); at most MAX_PUSH_PASSES passes.
local function pushOut(p: Point, boxes: { Box }): Point
	local current = point(p.x, p.z)
	for _ = 1, MAX_PUSH_PASSES do
		local moved = false
		for _, box in ipairs(boxes) do
			if strictlyInside(current, box) then
				local candidates = {
					{ current.x - box.minX, point(box.minX - PUSH_MARGIN, current.z) },
					{ box.maxX - current.x, point(box.maxX + PUSH_MARGIN, current.z) },
					{ current.z - box.minZ, point(current.x, box.minZ - PUSH_MARGIN) },
					{ box.maxZ - current.z, point(current.x, box.maxZ + PUSH_MARGIN) },
				}
				local best = candidates[1]
				for index = 2, 4 do
					if candidates[index][1] < best[1] then
						best = candidates[index]
					end
				end
				current = best[2]
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return current
end

-- The waypoints from `from` to `to` around the obstacles, ending with `to` (after it was
-- pushed out of any obstacle). Dijkstra over the box corners; ties go to the lower node index.
-- When `from` lay inside an obstacle, the route first walks out to the pushed start (Fix round 1).
function NpcPath.route(from: Point, to: Point, level: number): { Point }
	local boxes = NpcPath.obstacles()
	local start = pushOut(from, boxes)
	local goal = pushOut(to, boxes)
	local startMoved = start.x ~= from.x or start.z ~= from.z
	if NpcPath.segmentClear(start, goal, boxes) then
		if startMoved then
			return { start, goal }
		end
		return { goal }
	end
	local nodes: { Point } = {}
	for boxIndex, box in ipairs(boxes) do
		for _, corner in ipairs({
			point(box.minX, box.minZ),
			point(box.maxX, box.minZ),
			point(box.maxX, box.maxZ),
			point(box.minX, box.maxZ),
		}) do
			local blocked = not NpcPath.inLot(corner, level)
			if not blocked then
				for otherIndex, other in ipairs(boxes) do
					if otherIndex ~= boxIndex and strictlyInside(corner, other) then
						blocked = true
						break
					end
				end
			end
			if not blocked then
				table.insert(nodes, corner)
			end
		end
	end
	table.insert(nodes, start)
	local startIndex = #nodes
	table.insert(nodes, goal)
	local goalIndex = #nodes

	local count = #nodes
	local dist: { number } = {}
	local previous: { [number]: number } = {}
	local done: { boolean } = {}
	for index = 1, count do
		dist[index] = math.huge
		done[index] = false
	end
	dist[startIndex] = 0
	while true do
		local current: number? = nil
		for index = 1, count do
			if not done[index] and dist[index] < math.huge and (current == nil or dist[index] < dist[current]) then
				current = index
			end
		end
		if current == nil or current == goalIndex then
			break
		end
		local at = current :: number
		done[at] = true
		for index = 1, count do
			if not done[index] and index ~= at and NpcPath.segmentClear(nodes[at], nodes[index], boxes) then
				local candidate = dist[at] + NpcPath.distance(nodes[at], nodes[index])
				if candidate < dist[index] then
					dist[index] = candidate
					previous[index] = at
				end
			end
		end
	end
	local points: { Point } = {}
	if startMoved then
		table.insert(points, start)
	end
	if dist[goalIndex] == math.huge then
		table.insert(points, goal)
		return points
	end
	local reversed: { Point } = {}
	local cursor: number? = goalIndex
	while cursor ~= nil and cursor ~= startIndex do
		table.insert(reversed, nodes[cursor])
		cursor = previous[cursor]
	end
	for index = #reversed, 1, -1 do
		table.insert(points, reversed[index])
	end
	return points
end

-- Where a customer stands to pick up a tree: beside it, inside the lot and outside every
-- obstacle; else the tree centre. nil without a numeric position.
function NpcPath.approach(tree, level: number): Point?
	if type(tree) ~= "table" or not finite(tree.x) or not finite(tree.z) then
		return nil
	end
	local d = Stocking.radius(tree.sizeId) + config().Path.ApproachGap
	local boxes = NpcPath.obstacles()
	for _, candidate in ipairs({
		point(tree.x, tree.z + d),
		point(tree.x, tree.z - d),
		point(tree.x + d, tree.z),
		point(tree.x - d, tree.z),
	}) do
		local clear = NpcPath.inLot(candidate, level)
		if clear then
			for _, box in ipairs(boxes) do
				if strictlyInside(candidate, box) then
					clear = false
					break
				end
			end
		end
		if clear then
			return candidate
		end
	end
	return point(tree.x, tree.z)
end

-- Lot frame -> world X/Z for a plot centred at c ({x, z}).
function NpcPath.toWorld(c: Point, p: Point): Point
	return point(c.x + p.x, c.z + Stocking.facing(c.z) * p.z)
end

-- World X/Z -> lot frame for a plot centred at c ({x, z}).
function NpcPath.fromWorld(c: Point, x: number, z: number): Point
	return point(x - c.x, (z - c.z) * Stocking.facing(c.z))
end

return NpcPath
