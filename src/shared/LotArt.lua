--!strict
-- Lot and HQ art in the world (CM2-13W, docs/plans/CM2-13W.md): which art path each lot element
-- uses, how it is turned to the road and where the lot fence pieces stand. Pure data and maths;
-- LotArtWorld and LotFenceWorld clone the models.
local GameConfig = require(script.Parent.GameConfig)

local LotArt = {}

export type Choice = {
	path: string,
	mode: string,
	template: any?,
	code: string?,
}

-- A piece in the lot frame; `kind` is "Rail" or "Post", `box` the fenceBoxes id ("Decor" for decor fences).
export type Piece = {
	box: string,
	kind: string,
	x: number,
	z: number,
	dirX: number,
	dirZ: number,
}

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

LotArt.PATHS = {
	Counter = "Props/CheckoutCounter",
	Bay = "Props/ReceivingBay",
	Bundle = "Props/TreeBundle",
	Rail = "Environment/FenceRail8",
	Post = "Environment/FencePost",
	Gate = "Props/LotGate",
}

LotArt.RAIL_LENGTH = 8 -- FenceRail8 post spacing
-- Rail extent behind and ahead of its centre along the run, and its half-width: the start post is at
-- model +X = +L/2, the rails run to -X; the v3 post is 0.9 wide (MODEL_INTEGRATION CM2-GATE).
LotArt.RAIL_BEHIND = 4.45
LotArt.RAIL_AHEAD = 3.95
LotArt.PIECE_HALF = 0.45
LotArt.FENCE_OFFSET = 0.45 -- fence line beyond the lot edge = centre of the 0.3-thick fenceBoxes
LotArt.FENCE_BASE_DROP = 0.55 -- base = map ground top 0, behind the lot edge; never floats
LotArt.GATE_X = 28 -- the gate's lot-frame x, east of the parking (CM2-GATEW)
LotArt.GATE_OFFSET = 1.0 -- beyond LotHalfDepth, so the posts stay off the placeable lot
LotArt.GATE_POST_X = 8.9 -- post centre from the gate pivot along the run
LotArt.GATE_POST_HALF = 0.75 -- 1.5 x 1.5 posts
LotArt.BUNDLE_ROW = 1.0
LotArt.BUNDLE_SPACING = 1.2

local counterBox = GameConfig.Customers.Npc.Path.Counter
LotArt.COUNTER = {
	x = (counterBox.minX + counterBox.maxX) / 2,
	z = (counterBox.minZ + counterBox.maxZ) / 2,
}

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value
end

function LotArt.hqLevel(level: any): number
	if not isNumber(level) then
		return 1
	end
	return math.clamp(math.floor(level), 1, GameConfig.Progression.HQ.maxLevel)
end

function LotArt.hqPath(level: any): string
	return "Buildings/" .. GameConfig.Progression.HQ.tiers[LotArt.hqLevel(level)].id
end

-- The centre of the tier's footprint in the lot frame.
function LotArt.hqCentre(level: any): (number, number)
	local f = GameConfig.Progression.HQ.tiers[LotArt.hqLevel(level)].footprint
	return (f.minX + f.maxX) / 2, (f.minZ + f.maxZ) / 2
end

-- Model -Z (the art's front) then points at the road: plots 1-3 face +1.
function LotArt.roadYaw(facing: number): number
	if facing == 1 then
		return math.pi
	end
	return 0
end

-- Yaw that points model -X along the lot-frame run (dirX, dirZ).
function LotArt.runYaw(dirX: number, dirZ: number, facing: number): number
	return math.atan2(dirZ * facing, -dirX)
end

function LotArt.choose(root: any, find: (any, string) -> (any, string?), path: string): Choice
	local template, code = find(root, path)
	if template ~= nil then
		return { path = path, mode = "Art", template = template, code = nil }
	end
	return { path = path, mode = "Primitive", template = nil, code = code or "MissingArtAsset" }
end

-- The lot fence pieces at expansion level `level`: the back run (10 rails and a corner post) and,
-- from level 1, both side runs (BackDepthPerLevel / RAIL_LENGTH rails per level). 11 + 2 x level.
function LotArt.fenceSegments(level: any): { Piece }
	local growth = 0
	if isNumber(level) then
		growth = math.clamp(math.floor(level), 0, GameConfig.Progression.LotExpansion.maxLevel)
	end
	local placement = GameConfig.Placement
	local half = placement.LotHalfWidth
	local back = placement.LotHalfDepth + placement.BackDepthPerLevel * growth
	local zb = -(back + LotArt.FENCE_OFFSET)
	local length = LotArt.RAIL_LENGTH
	local pieces: { Piece } = {}
	for k = 0, (2 * half) // length - 1 do
		table.insert(
			pieces,
			{ box = "Back", kind = "Rail", x = -half + length * (k + 0.5), z = zb, dirX = 1, dirZ = 0 }
		)
	end
	table.insert(pieces, { box = "Back", kind = "Post", x = half, z = zb, dirX = 1, dirZ = 0 })
	if growth >= 1 then
		local count = growth * placement.BackDepthPerLevel // length
		for _, side in { { box = "Left", x = -(half + 0.45) }, { box = "Right", x = half + 0.45 } } do
			for k = 0, count - 1 do
				table.insert(pieces, {
					box = side.box,
					kind = "Rail",
					x = side.x,
					z = -(placement.LotHalfDepth + 0.45) - length * (k + 0.5),
					dirX = 0,
					dirZ = -1,
				})
			end
		end
	end
	return pieces
end

-- A decorative fence: one rail at (x, z) and its end post 4 studs ahead along +X.
function LotArt.decorPieces(x: number, z: number): { Piece }
	return {
		{ box = "Decor", kind = "Rail", x = x, z = z, dirX = 1, dirZ = 0 },
		{ box = "Decor", kind = "Post", x = x + 4, z = z, dirX = 1, dirZ = 0 },
	}
end

-- The lot-frame footprint of a piece: a post +-0.45 on both axes, a rail from 4.45 behind to 3.95
-- ahead of its centre along the run and +-0.45 across.
function LotArt.pieceBox(piece: Piece): Box
	local half = LotArt.PIECE_HALF
	if piece.kind == "Post" then
		return { minX = piece.x - half, maxX = piece.x + half, minZ = piece.z - half, maxZ = piece.z + half }
	end
	local backX, backZ = piece.x - LotArt.RAIL_BEHIND * piece.dirX, piece.z - LotArt.RAIL_BEHIND * piece.dirZ
	local aheadX, aheadZ = piece.x + LotArt.RAIL_AHEAD * piece.dirX, piece.z + LotArt.RAIL_AHEAD * piece.dirZ
	local acrossX, acrossZ = half * math.abs(piece.dirZ), half * math.abs(piece.dirX)
	return {
		minX = math.min(backX, aheadX) - acrossX,
		maxX = math.max(backX, aheadX) + acrossX,
		minZ = math.min(backZ, aheadZ) - acrossZ,
		maxZ = math.max(backZ, aheadZ) + acrossZ,
	}
end

-- The gate pivot in the lot frame (x, z) at the road edge (CM2-GATEW).
function LotArt.gatePose(): (number, number)
	return LotArt.GATE_X, GameConfig.Placement.LotHalfDepth + LotArt.GATE_OFFSET
end

-- The gate's two posts (left then right) as lot-frame boxes.
function LotArt.gatePostBoxes(): { Box }
	local x, z = LotArt.gatePose()
	local boxes: { Box } = {}
	for _, side in { -1, 1 } do
		local cx = x + side * LotArt.GATE_POST_X
		table.insert(boxes, {
			minX = cx - LotArt.GATE_POST_HALF,
			maxX = cx + LotArt.GATE_POST_HALF,
			minZ = z - LotArt.GATE_POST_HALF,
			maxZ = z + LotArt.GATE_POST_HALF,
		})
	end
	return boxes
end

-- Bundle k on the deck: the rise above the deck top (rows of three) and the world z offset.
function LotArt.bundleOffset(k: number): (number, number)
	return (k // 3) * LotArt.BUNDLE_ROW, -LotArt.BUNDLE_SPACING + (k % 3) * LotArt.BUNDLE_SPACING
end

return LotArt
