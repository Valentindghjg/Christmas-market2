--!strict
-- Tree art in the world (CM2-12W, docs/plans/CM2-12W.md): which CM2-12 Blender tree
-- (Trees/<Species>/<Size>) a world role shows, how the primitive fallback is scaled and where a
-- label sits. Pure data and maths; WorldService clones the models.
local TreeArt = {}

export type Choice = {
	role: string,
	path: string,
	mode: string,
	template: any?,
	code: string?,
	primitiveScale: number,
}

TreeArt.ROLES = { "Display", "Pickup", "Carried", "NpcCarried", "Roof" }
TreeArt.SIZES = { "Small", "Medium", "Large" }
TreeArt.DEFAULT_SIZE = "Medium"
TreeArt.DEFAULT_SPECIES = "DouglasFir"

-- Primitive tree geometry at scale 1 (OBSERVED in WorldService.tree): top above the foot
-- (needles 3 centre 10 + 1.5) and pivot (Trunk centre) above the foot.
TreeArt.PRIMITIVE_TOP = 11.5
TreeArt.PRIMITIVE_PIVOT = 2.5

TreeArt.PRIMITIVE_SCALES = {
	Display = { Small = 0.6, Medium = 0.8, Large = 1.0 },
	Pickup = { Small = 0.6, Medium = 0.8, Large = 1.0 },
	Carried = { Small = 0.4, Medium = 0.4, Large = 0.4 },
	NpcCarried = { Small = 0.35, Medium = 0.4, Large = 0.45 },
	Roof = { Small = 0.35, Medium = 0.35, Large = 0.35 },
} :: { [string]: { [string]: number } }

-- Roles with a label and the UiTheme.WorldLabels layout they use.
TreeArt.LABEL_LAYOUTS = { Display = "DisplayTree", Pickup = "PickupOrder" } :: { [string]: string }

local function checkRole(role: string)
	if TreeArt.PRIMITIVE_SCALES[role] == nil then
		error("TreeArt: unknown role " .. tostring(role))
	end
end

function TreeArt.sizeOf(sizeId: any): string
	for _, size in TreeArt.SIZES do
		if sizeId == size then
			return size
		end
	end
	return TreeArt.DEFAULT_SIZE
end

function TreeArt.path(speciesId: any, sizeId: any): string
	local species = TreeArt.DEFAULT_SPECIES
	if type(speciesId) == "string" and string.match(speciesId, "^%u%w*$") ~= nil then
		species = speciesId
	end
	return "Trees/" .. species .. "/" .. TreeArt.sizeOf(sizeId)
end

function TreeArt.primitiveScale(role: string, sizeId: any): number
	checkRole(role)
	return TreeArt.PRIMITIVE_SCALES[role][TreeArt.sizeOf(sizeId)]
end

-- Display and Pickup keep the art's native size; the other roles scale the art to the
-- primitive's height.
function TreeArt.artScale(role: string, sizeId: any, artHeight: number): number
	checkRole(role)
	if role == "Display" or role == "Pickup" then
		return 1
	end
	if type(artHeight) ~= "number" or artHeight ~= artHeight or artHeight == math.huge or artHeight <= 0 then
		return 1
	end
	return TreeArt.PRIMITIVE_TOP * TreeArt.primitiveScale(role, sizeId) / artHeight
end

-- Drop that puts the art's foot where the primitive's foot is when a pose targets the pivot.
function TreeArt.pivotDrop(role: string, sizeId: any): number
	return TreeArt.PRIMITIVE_PIVOT * TreeArt.primitiveScale(role, sizeId)
end

function TreeArt.choose(
	root: any,
	find: (any, string) -> (any, string?),
	role: string,
	speciesId: any,
	sizeId: any
): Choice
	checkRole(role)
	local artPath = TreeArt.path(speciesId, sizeId)
	local template, code = find(root, artPath)
	local scale = TreeArt.primitiveScale(role, sizeId)
	if template ~= nil then
		return { role = role, path = artPath, mode = "Art", template = template, code = nil, primitiveScale = scale }
	end
	return {
		role = role,
		path = artPath,
		mode = "Primitive",
		template = nil,
		code = code or "MissingArtAsset",
		primitiveScale = scale,
	}
end

-- Billboard offset above the adornee so the label sits `clearance` (+ stagger) above the tree
-- top; all heights are relative to the tree foot.
function TreeArt.labelOffset(top: number, adornee: number, clearance: number, stagger: number): number
	return top - adornee + clearance + stagger
end

return TreeArt
