--!strict
-- The lot fence of a plot (CM2-G9a, docs/archive/plans/CM2-G9a.md): ProgressionVisuals.LotFence, built
-- from Progression.fenceBoxes so it moves back with every lot expansion level. Parts only; the
-- helpers (part, lotPosition, paletteColor, setCollisionGroup, group) come from WorldService.
-- Also holds WorldService's lot-frame helpers for fitting the HQ art (Amendment 1), which keep
-- WorldService under its 1500-line cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression"))

local LotFenceWorld = {}

local RAIL_HEIGHTS = { 1.4, 2.4 }
local POST_SIZE = Vector3.new(0.5, 3, 0.5)
local POST_Y = 2.05
local POST_SPACING = 8

-- Rebuilds `visuals.LotFence` for expansion level `growth`: per box a Model named by its id with
-- Rail_1/Rail_2 over the whole box and posts Post_k at both ends and evenly every <= 8 studs.
function LotFenceWorld.build(plot: Model, visuals: Instance, growth: number, helpers)
	local existing = visuals:FindFirstChild("LotFence")
	if existing then
		existing:Destroy()
	end
	local fence = Instance.new("Model")
	fence.Name = "LotFence"
	fence:SetAttribute("LotExpansionLevel", growth)
	local smooth = Enum.Material.SmoothPlastic
	local railColor, postColor = helpers.paletteColor("WoodWarm"), helpers.paletteColor("WoodWarmShade")
	for _, box in Progression.fenceBoxes(growth) do
		local side = Instance.new("Model")
		side.Name = box.id
		side.Parent = fence
		local sx, sz = box.maxX - box.minX, box.maxZ - box.minZ
		local cx, cz = (box.minX + box.maxX) / 2, (box.minZ + box.maxZ) / 2
		local railSize = Vector3.new(sx, 0.3, sz)
		for index, y in RAIL_HEIGHTS do
			helpers.part(side, "Rail_" .. index, railSize, helpers.lotPosition(plot, cx, cz, y), railColor, smooth)
		end
		local alongX = sx >= sz
		local gaps = math.max(1, math.ceil(math.max(sx, sz) / POST_SPACING))
		for k = 0, gaps do
			local x = if alongX then box.minX + k * sx / gaps else cx
			local z = if alongX then cz else box.minZ + k * sz / gaps
			helpers.part(
				side,
				"Post_" .. (k + 1),
				POST_SIZE,
				helpers.lotPosition(plot, x, z, POST_Y),
				postColor,
				smooth
			)
		end
	end
	for _, descendant in fence:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = true
			descendant.CastShadow = false
		end
	end
	helpers.setCollisionGroup(fence, helpers.group)
	fence.Parent = visuals
end

-- A KeepClear box of the lot frame by id (GameConfig.Placement.KeepClear); errors if missing.
function LotFenceWorld.keepClearBox(id: string)
	for _, box in GameConfig.Placement.KeepClear do
		if box.id == id then
			return box
		end
	end
	error("KeepClear has no " .. id .. " box")
end

-- World X and Z size of the AABB over every BasePart's 8 corners. The lot axes are the world
-- axes (WorldService lotPosition), so this is also the lot-frame size.
function LotFenceWorld.worldExtents(model: Model): (number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local offset = Vector3.new(sx, sy, sz) * descendant.Size / 2
						local corner = descendant.CFrame:PointToWorldSpace(offset)
						minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
						minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
					end
				end
			end
		end
	end
	return maxX - minX, maxZ - minZ
end

return LotFenceWorld
