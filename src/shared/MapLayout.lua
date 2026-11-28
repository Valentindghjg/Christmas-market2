--!strict
-- Pure data and maths of the mountain-village map (CM2-10W, PROVISIONAL, contract in
-- docs/MODEL_INTEGRATION.md "Map layout (CM2-10)"). No Roblox types: the headless tests run it.
-- World frame: y up, road along X; a lot's frame is (lx, depth), world z = cz + facing * depth.
local GameConfig = require(script.Parent.GameConfig)

local MapLayout = {}

export type Box = { id: string?, minX: number, maxX: number, minZ: number, maxZ: number }
export type Piece = {
	id: string,
	artPath: string,
	group: string,
	x: number,
	y: number,
	z: number,
	yaw: number,
	scale: number,
	plot: number?,
	row: number?,
	textKey: string?,
	boardKey: string?,
	paint: { number }?,
}
export type Surface = {
	id: string,
	kind: string, -- "Part" or "Wedge"
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	yaw: number,
	material: string, -- Enum.Material name
	color: { number },
}
export type Wall = { id: string, x: number, y: number, z: number, sx: number, sy: number, sz: number }
export type Placement = { piece: Piece, mode: string, template: any }
export type Missing = { path: string, code: string }
export type ArtEntry = { w: number, l: number, triangles: number, meshParts: number, fallback: string? }
export type Zone = {
	id: string,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	a: number,
	b: number,
	rocks: number,
}
export type PlotSpot = { x: number, z: number, facing: number }
export type FlatTop = { id: string, minX: number, maxX: number, minZ: number, maxZ: number, top: number }
export type CoplanarPair = { a: string, b: string, area: number, gap: number }

MapLayout.SEED = 1010
MapLayout.MAX_LEVEL = 6
-- CM2-FLICK: technical thresholds of the coplanar-surface check (not contract values).
MapLayout.COPLANAR_TOLERANCE = 0.02
MapLayout.COPLANAR_MIN_AREA = 0.1

local BRIDGE = "Buildings/CoveredBridge"
local TREE = "Environment/VillageTree"
local BOARD = "Props/LeaderboardBoard"
local HOUSE = "Buildings/VillageHouse"
local SIGN = "Props/SignBoard"
local LAMP = "Props/LampPost"
local BENCH = "Props/Bench"
local FIR = "Environment/ForestFir"
local CLUSTER_A = "Environment/ForestClusterA"
local CLUSTER_B = "Environment/ForestClusterB"
local ROCK = "Environment/RockCluster"
local PEAK = "Environment/MountainPeak"
local RIDGE = "Environment/MountainRidge"
local SNOW_A = "Props/SnowPileA"
local SNOW_B = "Props/SnowPileB"
local SNOWMAN = "Props/Snowman"
local SLED = "Props/Sled"
local WOODSTACK = "Props/WoodStack"
local FIR_BARREL = "Props/FirBarrel"

-- W x L (docs "Map art"), triangle and MeshPart budget per model (docs "Map layout (CM2-10)").
MapLayout.ART = {
	[BRIDGE] = { w = 34.2, l = 56.2, triangles = 4000, meshParts = 10, fallback = "BridgeDeck" },
	[TREE] = { w = 29.89, l = 29.89, triangles = 4000, meshParts = 10, fallback = "VillageTree" },
	[BOARD] = { w = 14.0, l = 2.97, triangles = 1500, meshParts = 8, fallback = "Board" },
	[HOUSE] = { w = 23.15, l = 19.2, triangles = 3000, meshParts = 10, fallback = nil },
	[SIGN] = { w = 8.6, l = 1.0, triangles = 220, meshParts = 3, fallback = "Sign" },
	[LAMP] = { w = 1.13, l = 1.13, triangles = 160, meshParts = 3, fallback = "Lamp" },
	[BENCH] = { w = 4.96, l = 1.82, triangles = 240, meshParts = 3, fallback = nil },
	[FIR] = { w = 8.75, l = 8.67, triangles = 240, meshParts = 3, fallback = "Fir" },
	[CLUSTER_A] = { w = 21.81, l = 20.56, triangles = 1000, meshParts = 4, fallback = "ClusterA" },
	[CLUSTER_B] = { w = 14.26, l = 13.22, triangles = 700, meshParts = 4, fallback = "ClusterB" },
	[ROCK] = { w = 7.4, l = 4.5, triangles = 300, meshParts = 3, fallback = nil },
	[PEAK] = { w = 220, l = 180, triangles = 1000, meshParts = 4, fallback = nil },
	[RIDGE] = { w = 300, l = 150, triangles = 1000, meshParts = 4, fallback = nil },
	[SNOW_A] = { w = 5.76, l = 3.83, triangles = 160, meshParts = 2, fallback = "SnowPileA" },
	[SNOW_B] = { w = 4.58, l = 4.64, triangles = 240, meshParts = 2, fallback = "SnowPileB" },
	[SNOWMAN] = { w = 3.5, l = 2.3, triangles = 560, meshParts = 3, fallback = nil },
	[SLED] = { w = 1.77, l = 3.99, triangles = 300, meshParts = 3, fallback = nil },
	[WOODSTACK] = { w = 5.6, l = 2.31, triangles = 520, meshParts = 3, fallback = nil },
	[FIR_BARREL] = { w = 2.4, l = 2.4, triangles = 360, meshParts = 3, fallback = "FirBarrel" },
} :: { [string]: ArtEntry }

MapLayout.COUNTS = {
	[BRIDGE] = 1,
	[TREE] = 1,
	[BOARD] = 4,
	[HOUSE] = 4,
	[SIGN] = 7,
	[LAMP] = 32,
	[BENCH] = 12,
	[FIR] = 162,
	[CLUSTER_A] = 40,
	[CLUSTER_B] = 30,
	[ROCK] = 24,
	[PEAK] = 6,
	[RIDGE] = 7,
	[SNOW_A] = 32,
	[SNOW_B] = 14,
	[SNOWMAN] = 8,
	[SLED] = 6,
	[WOODSTACK] = 6,
	[FIR_BARREL] = 16,
} :: { [string]: number }

-- Plots 1-3 sit at z -75 facing +1 (toward the road), plots 4-6 at z 75 facing -1.
MapLayout.PLOTS = {
	{ x = -110, z = -75, facing = 1 },
	{ x = 0, z = -75, facing = 1 },
	{ x = 110, z = -75, facing = 1 },
	{ x = -110, z = 75, facing = -1 },
	{ x = 0, z = 75, facing = -1 },
	{ x = 110, z = 75, facing = -1 },
} :: { PlotSpot }

-- Disjoint subsets of the contract's forest zones; a / b = ForestClusterA / B, rocks = RockCluster.
MapLayout.ZONES = {
	{ id = "W_N", minX = -410, maxX = -242, minZ = 22, maxZ = 260, a = 6, b = 5, rocks = 4 },
	{ id = "W_S", minX = -410, maxX = -242, minZ = -260, maxZ = -22, a = 6, b = 5, rocks = 4 },
	{ id = "C_N", minX = -194, maxX = 410, minZ = 156, maxZ = 260, a = 9, b = 6, rocks = 5 },
	{ id = "C_S", minX = -194, maxX = 410, minZ = -260, maxZ = -156, a = 9, b = 6, rocks = 5 },
	{ id = "SP_N", minX = -194, maxX = -156, minZ = 52, maxZ = 156, a = 1, b = 1, rocks = 0 },
	{ id = "SP_S", minX = -194, maxX = -156, minZ = -156, maxZ = -52, a = 1, b = 1, rocks = 0 },
	{ id = "NE", minX = 165, maxX = 410, minZ = 78, maxZ = 156, a = 3, b = 2, rocks = 2 },
	{ id = "SE", minX = 165, maxX = 410, minZ = -156, maxZ = -78, a = 3, b = 2, rocks = 2 },
	{ id = "E", minX = 286, maxX = 410, minZ = -80, maxZ = 80, a = 2, b = 2, rocks = 2 },
} :: { Zone }

-- The four plot-gap rectangles (ForestFir only).
MapLayout.GAP_ZONES = {
	{ id = "Gap_W_N", minX = -58, maxX = -43, minZ = 51, maxZ = 153 },
	{ id = "Gap_W_S", minX = -58, maxX = -43, minZ = -153, maxZ = -51 },
	{ id = "Gap_E_N", minX = 52, maxX = 67, minZ = 51, maxZ = 153 },
	{ id = "Gap_E_S", minX = 52, maxX = 67, minZ = -153, maxZ = -51 },
} :: { Box }

local RESERVE_DEPTHS = { -36, -46, -56, -66 }
local RESERVE_COLUMNS = { -30, -15, 0, 15, 30 }
local RESERVE_JITTER = 1.5 -- x jitter; the hide rule stays conservative with it
local RESERVE_Z_JITTER = 0.6 -- rows 10 apart: 10 - 1.2 = 8.8 > 8.75, the largest fir z extent
local FIR_HALF_LENGTH = 4.375 -- ForestFir half width
local HIDE_CLEARANCE = 3

local YAWS = { 0, 90, 180, 270 }
local SCALES = { 0.9, 1.0, 1.1 }

-- Reserve hide rule -----------------------------------------------------------------------

-- Smallest lot expansion level whose lot edge comes within 3 studs of the row's nearest fir
-- edge (worst-case jitter); MAX_LEVEL + 1 when no level does.
function MapLayout.hideLevel(row: number): number
	local depth = RESERVE_DEPTHS[row]
	local gap = math.abs(depth) - FIR_HALF_LENGTH - RESERVE_JITTER
	for level = 0, MapLayout.MAX_LEVEL do
		local lotEdge = GameConfig.Placement.LotHalfDepth + GameConfig.Placement.BackDepthPerLevel * level
		if gap - lotEdge < HIDE_CLEARANCE then
			return level
		end
	end
	return MapLayout.MAX_LEVEL + 1
end

function MapLayout.hiddenRowCount(level: number): number
	local whole = math.floor(level)
	local count = 0
	for row = 1, #RESERVE_DEPTHS do
		if MapLayout.hideLevel(row) <= whole then
			count += 1
		end
	end
	return count
end

-- Boxes -----------------------------------------------------------------------------------

function MapLayout.footprint(piece: Piece): Box
	local art = MapLayout.ART[piece.artPath]
	local halfX, halfZ = art.w / 2, art.l / 2
	if piece.yaw % 180 ~= 0 then
		halfX, halfZ = halfZ, halfX
	end
	halfX *= piece.scale
	halfZ *= piece.scale
	return {
		id = piece.id,
		minX = piece.x - halfX,
		maxX = piece.x + halfX,
		minZ = piece.z - halfZ,
		maxZ = piece.z + halfZ,
	}
end

function MapLayout.distance(a: Box, b: Box): number
	local dx = math.max(0, a.minX - b.maxX, b.minX - a.maxX)
	local dz = math.max(0, a.minZ - b.maxZ, b.minZ - a.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

-- The 19 keep-out boxes: the road and, per plot, the lot, car lane and truck lane.
function MapLayout.keepOut(): { Box }
	local boxes: { Box } = { { id = "Road", minX = -190, maxX = 190, minZ = -16, maxZ = 16 } }
	for index, plot in ipairs(MapLayout.PLOTS) do
		local sign = plot.z < 0 and 1 or -1 -- plots 1-3 use the contract z, plots 4-6 mirror it
		local function box(id: string, minX: number, maxX: number, nearZ: number, farZ: number)
			local z1, z2 = sign * nearZ, sign * farZ
			table.insert(boxes, {
				id = id .. "_" .. index,
				minX = plot.x + minX,
				maxX = plot.x + maxX,
				minZ = math.min(z1, z2),
				maxZ = math.max(z1, z2),
			})
		end
		box("Lot", -40, 49, -150, -48)
		box("Cars", -28, 16, -48, -16)
		box("Truck", 43, 49, -48, -16)
	end
	return boxes
end

-- Pieces ----------------------------------------------------------------------------------

local function fixed(id: string, artPath: string, group: string, x: number, y: number, z: number, yaw: number): Piece
	return { id = id, artPath = artPath, group = group, x = x, y = y, z = z, yaw = yaw, scale = 1 }
end

local function fixedPieces(): { Piece }
	local list: { Piece } = {}
	table.insert(list, fixed("CoveredBridge", BRIDGE, "Landmarks", -218, 0, 0, 90))
	table.insert(list, fixed("VillageTree", TREE, "Landmarks", 235, 0, 0, 0))

	local boards: { { key: string, x: number, z: number, yaw: number } } = {
		{ key = "CashEarned", x = 217, z = 36.5, yaw = 0 },
		{ key = "Reputation", x = 253, z = 36.5, yaw = 0 },
		{ key = "HoursPlayed", x = 217, z = -36.5, yaw = 180 },
		{ key = "RobuxSpent", x = 253, z = -36.5, yaw = 180 },
	}
	for _, entry in boards do
		local piece = fixed("Board_" .. entry.key, BOARD, "Square", entry.x, 0.35, entry.z, entry.yaw)
		piece.boardKey = entry.key
		piece.textKey = "board" .. entry.key
		table.insert(list, piece)
	end
	local houses: { { x: number, z: number, yaw: number, paint: { number } } } = {
		{ x = 212, z = 62, yaw = 0, paint = { 178, 64, 56 } },
		{ x = 258, z = 62, yaw = 0, paint = { 64, 104, 146 } },
		{ x = 212, z = -62, yaw = 180, paint = { 214, 186, 112 } },
		{ x = 258, z = -62, yaw = 180, paint = { 88, 132, 96 } },
	}
	for index, entry in houses do
		local piece = fixed("House_" .. index, HOUSE, "Square", entry.x, 0, entry.z, entry.yaw)
		piece.paint = entry.paint
		table.insert(list, piece)
	end
	local benches: { { x: number, z: number, yaw: number } } = {
		{ x = 262, z = 12, yaw = 90 },
		{ x = 262, z = -12, yaw = 90 },
		{ x = 208, z = 20, yaw = -90 },
		{ x = 208, z = -20, yaw = -90 },
	}
	for index, entry in benches do
		table.insert(list, fixed("Bench_" .. index, BENCH, "Square", entry.x, 0.35, entry.z, entry.yaw))
	end
	local squareLamps: { { x: number, z: number } } = {
		{ x = 194, z = 41 },
		{ x = 235, z = 41 },
		{ x = 276, z = 41 },
		{ x = 194, z = -41 },
		{ x = 235, z = -41 },
		{ x = 276, z = -41 },
		{ x = 276, z = 14 },
		{ x = 276, z = -14 },
	}
	for index, entry in squareLamps do
		table.insert(list, fixed(string.format("Lamp_%02d", index), LAMP, "Square", entry.x, 0.35, entry.z, 0))
	end

	local lampIndex = #squareLamps
	for _, x in { -165, -80, -38, 30, 70, 140, 182 } do
		for _, z in { 22, -22 } do
			lampIndex += 1
			table.insert(list, fixed(string.format("Lamp_%02d", lampIndex), LAMP, "Street", x, 0, z, 0))
		end
	end
	local welcome = fixed("Sign_Welcome", SIGN, "Street", -170, 0, 30, 0)
	welcome.textKey = "mapWelcome"
	table.insert(list, welcome)
	for index, plot in ipairs(MapLayout.PLOTS) do
		local sign = fixed(
			string.format("Sign_Deliveries_Plot_%02d", index),
			SIGN,
			"Street",
			plot.x + 57,
			0,
			plot.z + plot.facing * 52,
			index <= 3 and 180 or 0
		)
		sign.plot = index
		sign.textKey = "mapDeliveries"
		table.insert(list, sign)
	end

	local mountains: { { path: string, x: number, z: number, yaw: number } } = {
		{ path = RIDGE, x = -300, z = 350, yaw = 0 },
		{ path = PEAK, x = -60, z = 350, yaw = 0 },
		{ path = RIDGE, x = 190, z = 350, yaw = 0 },
		{ path = PEAK, x = 430, z = 340, yaw = 0 },
		{ path = PEAK, x = -300, z = -350, yaw = 180 },
		{ path = RIDGE, x = -60, z = -350, yaw = 180 },
		{ path = PEAK, x = 190, z = -350, yaw = 180 },
		{ path = RIDGE, x = 430, z = -340, yaw = 180 },
		{ path = RIDGE, x = -500, z = 175, yaw = -90 },
		{ path = RIDGE, x = -500, z = -175, yaw = -90 },
		{ path = PEAK, x = -760, z = 0, yaw = -90 },
		{ path = PEAK, x = 560, z = -150, yaw = 90 },
		{ path = RIDGE, x = 560, z = 150, yaw = 90 },
	}
	for index, entry in mountains do
		local id = string.format("Mountain_%02d", index)
		table.insert(list, fixed(id, entry.path, "Mountains", entry.x, 0, entry.z, entry.yaw))
	end
	return list
end

MapLayout.DRESSING_CODES = {
	A = SNOW_A,
	B = SNOW_B,
	SM = SNOWMAN,
	SL = SLED,
	WS = WOODSTACK,
	FB = FIR_BARREL,
	L = LAMP,
	BE = BENCH,
	F = FIR,
} :: { [string]: string }

-- CM2-10D placement contract (docs "Map dressing (CM2-10D)"): north half, mirrored to the south by dressingPieces.
MapLayout.DRESSING = {
	-- 1. Street (01-19)
	{ code = "L", x = -195, z = 22, yaw = 0 },
	{ code = "A", x = -187, z = 24, yaw = 0 },
	{ code = "FB", x = -180, z = 23.5, yaw = 0 },
	{ code = "SM", x = -158, z = 34, yaw = 0 },
	{ code = "BE", x = -152, z = 24, yaw = 0 },
	{ code = "B", x = -145, z = 26, yaw = 0 },
	{ code = "WS", x = -186, z = 40, yaw = 0 },
	{ code = "SL", x = -182, z = 36, yaw = 90 },
	{ code = "F", x = -150, z = 40, yaw = 0 },
	{ code = "B", x = -34, z = 27, yaw = 0 },
	{ code = "FB", x = -40, z = 34, yaw = 0 },
	{ code = "B", x = 76, z = 27, yaw = 0 },
	{ code = "WS", x = 73, z = 40, yaw = 0 },
	{ code = "FB", x = 70, z = 30, yaw = 0 },
	{ code = "BE", x = 176, z = 24.5, yaw = 0 },
	{ code = "SM", x = 170, z = 36, yaw = 0 },
	{ code = "A", x = 183, z = 40, yaw = 0 },
	{ code = "FB", x = 165, z = 30, yaw = 0 },
	{ code = "FB", x = 186, z = 26, yaw = 0 },
	-- 2. Approach road, bridge west end (20-33)
	{ code = "L", x = -252, z = 20, yaw = 0 },
	{ code = "L", x = -300, z = 20, yaw = 0 },
	{ code = "L", x = -350, z = 20, yaw = 0 },
	{ code = "L", x = -400, z = 20, yaw = 0 },
	{ code = "A", x = -272, z = 21, yaw = 0 },
	{ code = "A", x = -325, z = 21, yaw = 0 },
	{ code = "A", x = -375, z = 21, yaw = 0 },
	{ code = "B", x = -262, z = 25, yaw = 0 },
	{ code = "SM", x = -258, z = 34, yaw = 0 },
	{ code = "SL", x = -254, z = 31, yaw = 0 },
	{ code = "BE", x = -280, z = 25, yaw = 0 },
	{ code = "FB", x = -249, z = 22, yaw = 0 },
	{ code = "F", x = -262, z = 42, yaw = 0 },
	{ code = "F", x = -290, z = 45, yaw = 0 },
	-- 3. Stream banks (34-38)
	{ code = "A", x = -197, z = 60, yaw = 90 },
	{ code = "A", x = -197, z = 100, yaw = 90 },
	{ code = "A", x = -197, z = 140, yaw = 90 },
	{ code = "A", x = -238.5, z = 60, yaw = 90 },
	{ code = "A", x = -238.5, z = 120, yaw = 90 },
	-- 4. Square (39-47)
	{ code = "WS", x = 226, z = 62, yaw = 270 },
	{ code = "SM", x = 237, z = 58, yaw = 0 },
	{ code = "SL", x = 243, z = 57, yaw = 90 },
	{ code = "B", x = 195, z = 49, yaw = 0 },
	{ code = "A", x = 274, z = 49, yaw = 0 },
	{ code = "FB", x = 283, z = 20, yaw = 0 },
	{ code = "FB", x = 283, z = 40, yaw = 0 },
	{ code = "F", x = 235, z = 70, yaw = 0 },
	{ code = "B", x = 280, z = 62, yaw = 0 },
	-- 5. Plot gaps (48-49)
	{ code = "A", x = -50.5, z = 42, yaw = 0 },
	{ code = "A", x = 59.5, z = 42, yaw = 0 },
	-- 6. More (50-55)
	{ code = "A", x = -170, z = 42, yaw = 0 },
	{ code = "B", x = -310, z = 25, yaw = 0 },
	{ code = "F", x = -365, z = 30, yaw = 0 },
	{ code = "BE", x = -385, z = 22, yaw = 0 },
	{ code = "A", x = -197, z = 200, yaw = 90 },
	{ code = "A", x = -238.5, z = 180, yaw = 90 },
} :: { { code: string, x: number, z: number, yaw: number } }

local function dressingPieces(): { Piece }
	local list: { Piece } = {}
	for nn, e in ipairs(MapLayout.DRESSING) do
		local path = MapLayout.DRESSING_CODES[e.code]
		table.insert(list, fixed(string.format("Dress_%02d_N", nn), path, "Dressing", e.x, 0, e.z, e.yaw))
		table.insert(
			list,
			fixed(string.format("Dress_%02d_S", nn), path, "Dressing", e.x, 0, -e.z, (e.yaw + 180) % 360)
		)
	end
	return list
end

local function overlaps(a: Box, b: Box, grow: number): boolean
	return a.minX - grow < b.maxX and b.minX - grow < a.maxX and a.minZ - grow < b.maxZ and b.minZ - grow < a.maxZ
end

-- Fresh generation: reserve firs, plot-gap firs, then the forest and rock zones, all from one
-- Park-Miller stream so the layout is identical on every server.
function MapLayout.generate(): { Piece }
	local state = MapLayout.SEED
	local function nextRandom(): number
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	local function rand(lo: number, hi: number): number
		return lo + (hi - lo) * nextRandom()
	end
	local function pick(list: { number }): number
		return list[math.min(#list, math.floor(nextRandom() * #list) + 1)]
	end

	local list = fixedPieces()
	local generated: { Piece } = {}
	local boxes: { Box } = {}

	for plotIndex, plot in ipairs(MapLayout.PLOTS) do
		for row, depth in ipairs(RESERVE_DEPTHS) do
			for column, lx in ipairs(RESERVE_COLUMNS) do
				local x = plot.x + lx + rand(-RESERVE_JITTER, RESERVE_JITTER)
				local z = plot.z + plot.facing * (depth + rand(-RESERVE_Z_JITTER, RESERVE_Z_JITTER))
				local piece = fixed(
					string.format("Reserve_Plot_%02d_%d_%d", plotIndex, row, column),
					FIR,
					"Reserve",
					x,
					0,
					z,
					pick(YAWS)
				)
				piece.plot = plotIndex
				piece.row = row
				table.insert(generated, piece)
				table.insert(boxes, MapLayout.footprint(piece))
			end
		end
	end

	local strips: { { x: number, minZ: number, maxZ: number } } = {
		{ x = -50.5, minZ = 51, maxZ = 153 },
		{ x = -50.5, minZ = -153, maxZ = -51 },
		{ x = 59.5, minZ = 51, maxZ = 153 },
		{ x = 59.5, minZ = -153, maxZ = -51 },
	}
	local gapIndex = 0
	for _, strip in strips do
		for k = 1, 8 do
			gapIndex += 1
			local z = strip.minZ + 102 * (k - 0.5) / 8 + rand(-1.5, 1.5)
			local x = strip.x + rand(-2, 2)
			local piece = fixed(string.format("GapFir_%02d", gapIndex), FIR, "Forest", x, 0, z, 0)
			piece.scale = pick(SCALES)
			piece.yaw = pick(YAWS)
			table.insert(generated, piece)
			table.insert(boxes, MapLayout.footprint(piece))
		end
	end

	local counters = { [CLUSTER_A] = 0, [CLUSTER_B] = 0, [ROCK] = 0 }
	local prefixes = { [CLUSTER_A] = "ForestA_", [CLUSTER_B] = "ForestB_", [ROCK] = "Rock_" }
	local function place(zone: Zone, artPath: string, group: string)
		counters[artPath] += 1
		local id = string.format("%s%02d", prefixes[artPath], counters[artPath])
		for _ = 1, 200 do
			local piece = fixed(id, artPath, group, 0, 0, 0, 0)
			piece.scale = pick(SCALES)
			piece.yaw = pick(YAWS)
			local half = MapLayout.footprint(piece) -- centred on the origin: half extents
			local hx, hz = half.maxX, half.maxZ
			piece.x = rand(zone.minX + hx, zone.maxX - hx)
			piece.z = rand(zone.minZ + hz, zone.maxZ - hz)
			local box = MapLayout.footprint(piece)
			local clear = true
			for _, other in boxes do
				if overlaps(box, other, 1) then
					clear = false
					break
				end
			end
			if clear then
				table.insert(generated, piece)
				table.insert(boxes, box)
				return
			end
		end
		error("MapLayout: cannot place " .. id)
	end
	for _, zone in MapLayout.ZONES do
		for _ = 1, zone.a do
			place(zone, CLUSTER_A, "Forest")
		end
		for _ = 1, zone.b do
			place(zone, CLUSTER_B, "Forest")
		end
		for _ = 1, zone.rocks do
			place(zone, ROCK, "Rocks")
		end
	end

	for _, piece in generated do
		table.insert(list, piece)
	end
	for _, piece in dressingPieces() do
		table.insert(list, piece)
	end
	return list
end

local cached: { Piece }? = nil
function MapLayout.pieces(): { Piece }
	if cached == nil then
		cached = MapLayout.generate()
	end
	return cached :: { Piece }
end

function MapLayout.budget(pieces: { Piece }): (number, number, number)
	local triangles, meshParts, models = 0, 0, 0
	for _, piece in pieces do
		local art = MapLayout.ART[piece.artPath]
		triangles += art.triangles
		meshParts += art.meshParts
		models += 1
	end
	return triangles, meshParts, models
end

-- Plan ------------------------------------------------------------------------------------

-- Decides per piece whether the library has its art ("Art"), a Part fallback exists
-- ("Fallback") or the piece is left out ("Skip"). find is called once per distinct path.
function MapLayout.plan(root: any, find: (any, string) -> (any, string?)): ({ Placement }, { Missing })
	local found: { [string]: { template: any } } = {}
	local missing: { Missing } = {}
	local placements: { Placement } = {}
	for _, piece in MapLayout.pieces() do
		local entry = found[piece.artPath]
		if entry == nil then
			local template, code = find(root, piece.artPath)
			entry = { template = template }
			found[piece.artPath] = entry
			if template == nil then
				table.insert(missing, { path = piece.artPath, code = code or "MissingArtAsset" })
			end
		end
		local mode = "Art"
		if entry.template == nil then
			mode = if MapLayout.ART[piece.artPath].fallback ~= nil then "Fallback" else "Skip"
		end
		table.insert(placements, { piece = piece, mode = mode, template = entry.template })
	end
	return placements, missing
end

-- Surfaces and walls ----------------------------------------------------------------------

function MapLayout.surfaces(): { Surface }
	local list: { Surface } = {}
	local function slab(
		id: string,
		minX: number,
		maxX: number,
		minZ: number,
		maxZ: number,
		top: number,
		thickness: number,
		material: string,
		color: { number }
	)
		table.insert(list, {
			id = id,
			kind = "Part",
			x = (minX + maxX) / 2,
			y = top - thickness / 2,
			z = (minZ + maxZ) / 2,
			sx = maxX - minX,
			sy = thickness,
			sz = maxZ - minZ,
			yaw = 0,
			material = material,
			color = color,
		})
	end
	slab("Ground_West", -560, -236, -380, 380, 0, 2, "Snow", { 238, 246, 250 })
	slab("Ground_East", -200, 560, -380, 380, 0, 2, "Snow", { 238, 246, 250 })
	-- Bank wedges: local +Z is the high side (top 0 falling to -3 toward the ice).
	local banks: { { id: string, x: number, yaw: number } } = {
		{ id = "Bank_West", x = -233, yaw = -90 },
		{ id = "Bank_East", x = -203, yaw = 90 },
	}
	for _, bank in banks do
		table.insert(list, {
			id = bank.id,
			kind = "Wedge",
			x = bank.x,
			y = -1.5,
			z = 0,
			sx = 760,
			sy = 3,
			sz = 6,
			yaw = bank.yaw,
			material = "Snow",
			color = { 226, 236, 242 },
		})
	end
	slab("Ice", -230, -206, -380, 380, -3, 1, "Ice", { 188, 220, 236 })
	slab("ApproachRoad", -560, -246, -16, 16, 0.35, 0.3, "Asphalt", { 54, 58, 61 })
	slab("Square", 190, 280, -45, 45, 0.35, 0.4, "Cobblestone", { 168, 160, 150 })
	slab("Sidewalk_N", -190, 190, 16, 20, 0.45, 0.5, "Concrete", { 198, 202, 206 })
	slab("Sidewalk_S", -190, 190, -20, -16, 0.45, 0.5, "Concrete", { 198, 202, 206 })
	for index, plot in ipairs(MapLayout.PLOTS) do
		local minZ, maxZ = -102, -20
		if index > 3 then
			minZ, maxZ = 20, 102
		end
		slab(
			string.format("TruckLane_Plot_%02d", index),
			plot.x + 43,
			plot.x + 49,
			minZ,
			maxZ,
			0.05,
			0.2,
			"Pebble",
			{ 150, 146, 140 }
		)
	end
	return list
end

-- CM2-FLICK: top rectangles of the flat (Part) surfaces; all have yaw 0. Wedges are skipped.
function MapLayout.surfaceTops(): { FlatTop }
	local tops: { FlatTop } = {}
	for _, surface in MapLayout.surfaces() do
		if surface.kind == "Part" then
			table.insert(tops, {
				id = surface.id,
				minX = surface.x - surface.sx / 2,
				maxX = surface.x + surface.sx / 2,
				minZ = surface.z - surface.sz / 2,
				maxZ = surface.z + surface.sz / 2,
				top = surface.y + surface.sy / 2,
			})
		end
	end
	return tops
end

-- CM2-FLICK: pairs of flat tops within `tolerance` in height whose footprints overlap by more
-- than `minArea`; those z-fight. Pure; the input is not mutated.
function MapLayout.coplanarPairs(tops: { FlatTop }, tolerance: number, minArea: number): { CoplanarPair }
	local sorted: { FlatTop } = table.clone(tops)
	table.sort(sorted, function(left: FlatTop, right: FlatTop)
		if left.top ~= right.top then
			return left.top < right.top
		end
		return left.id < right.id
	end)
	local pairsFound: { CoplanarPair } = {}
	for i = 1, #sorted do
		local first = sorted[i]
		local j = i + 1
		while j <= #sorted and sorted[j].top - first.top <= tolerance do
			local second = sorted[j]
			local width = math.min(first.maxX, second.maxX) - math.max(first.minX, second.minX)
			local depth = math.min(first.maxZ, second.maxZ) - math.max(first.minZ, second.minZ)
			local area = math.max(0, width) * math.max(0, depth)
			if area > minArea then
				table.insert(pairsFound, { a = first.id, b = second.id, area = area, gap = second.top - first.top })
			end
			j += 1
		end
	end
	return pairsFound
end

function MapLayout.walls(): { Wall }
	return {
		{ id = "BoundaryWall_N", x = 0, y = 40, z = 266, sx = 832, sy = 80, sz = 2 },
		{ id = "BoundaryWall_S", x = 0, y = 40, z = -266, sx = 832, sy = 80, sz = 2 },
		{ id = "BoundaryWall_E", x = 416, y = 40, z = 0, sx = 2, sy = 80, sz = 534 },
		{ id = "BoundaryWall_W", x = -416, y = 40, z = 0, sx = 2, sy = 80, sz = 534 },
	}
end

return MapLayout
