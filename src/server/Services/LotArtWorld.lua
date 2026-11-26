--!strict
-- Clones the CM2-13a HQ art and the CM2-13b lot props into a plot (CM2-13W, docs/plans/CM2-13W.md):
-- HQ, checkout counter, receiving bays, tree bundles and decorative fences, fronts facing the
-- road. Every builder returns nil (or false) when the art is missing, so WorldService can build
-- today's primitive. `ctx` comes from WorldService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LotArt = require(Shared:WaitForChild("LotArt"))
local LotFenceWorld = require(script.Parent:WaitForChild("LotFenceWorld"))

local LotArtWorld = {}

export type Ctx = {
	lotPosition: (Model, number, number, number) -> Vector3,
	lotTop: (Model) -> number,
	facing: (Model) -> number,
	setCollisionGroup: (Instance, string) -> (),
	group: string,
	reportMissing: (string, string) -> (),
}

-- A prepared clone of the art at `path`, or nil after reporting the missing path.
local function cloneArt(path: string, ctx: Ctx): Model?
	local choice = LotArt.choose(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find, path)
	if choice.mode ~= "Art" then
		ctx.reportMissing(path, choice.code or "MissingArtAsset")
		return nil
	end
	return ArtLibrary.prepareClone(choice.template)
end

-- The HQ tier's art, centred on its footprint with its front toward the road, shrunk uniformly
-- when it exceeds the footprint.
function LotArtWorld.hq(plot: Model, level: number, ctx: Ctx): Model?
	local path = LotArt.hqPath(level)
	local model = cloneArt(path, ctx)
	if model == nil then
		return nil
	end
	model.Name = "StarterSalesTent"
	local cx, cz = LotArt.hqCentre(level)
	model:PivotTo(
		CFrame.new(ctx.lotPosition(plot, cx, cz, ctx.lotTop(plot)))
			* CFrame.Angles(0, LotArt.roadYaw(ctx.facing(plot)), 0)
	)
	model.Parent = plot
	local footprint = GameConfig.Progression.HQ.tiers[LotArt.hqLevel(level)].footprint
	local sizeX, sizeZ = LotFenceWorld.worldExtents(model)
	local scale = ArtLibrary.fitScale(sizeX, sizeZ, footprint.maxX - footprint.minX, footprint.maxZ - footprint.minZ)
	if scale < 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:SetAttribute("FitScale", scale)
	model:SetAttribute("HqArtMode", "Art")
	model:SetAttribute("HqArtPath", path)
	ctx.setCollisionGroup(model, ctx.group)
	return model
end

-- The checkout counter art at the counter's lot position.
function LotArtWorld.counter(plot: Model, ctx: Ctx): Model?
	local model = cloneArt(LotArt.PATHS.Counter, ctx)
	if model == nil then
		return nil
	end
	model.Name = "CheckoutCounter"
	model:PivotTo(
		CFrame.new(ctx.lotPosition(plot, LotArt.COUNTER.x, LotArt.COUNTER.z, ctx.lotTop(plot)))
			* CFrame.Angles(0, LotArt.roadYaw(ctx.facing(plot)), 0)
	)
	model.Parent = plot
	return model
end

-- The receiving bay art on its base point (the deck's foot on the lot ground).
function LotArtWorld.bay(folder: Instance, plot: Model, index: number, base: Vector3, ctx: Ctx): Model?
	local model = cloneArt(LotArt.PATHS.Bay, ctx)
	if model == nil then
		return nil
	end
	model.Name = "BayArt_" .. index
	model:PivotTo(CFrame.new(base) * CFrame.Angles(0, LotArt.roadYaw(ctx.facing(plot)), 0))
	model.Parent = folder
	return model
end

-- `count` tree bundles on the bay's deck in rows of three; false (nothing built) without the art.
function LotArtWorld.bundles(model: Model, bay: BasePart, count: number, ctx: Ctx): boolean
	local choice = LotArt.choose(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find, LotArt.PATHS.Bundle)
	if choice.mode ~= "Art" then
		ctx.reportMissing(LotArt.PATHS.Bundle, choice.code or "MissingArtAsset")
		return false
	end
	local deckTop = bay.Position.Y + bay.Size.Y / 2
	for k = 0, count - 1 do
		local rise, dz = LotArt.bundleOffset(k)
		local bundle = ArtLibrary.prepareClone(choice.template)
		bundle.Name = "Bundle"
		bundle:PivotTo(CFrame.new(bay.Position.X, deckTop + rise, bay.Position.Z + dz))
		bundle.Parent = model
		for _, descendant in bundle:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanQuery = false
			end
		end
	end
	return true
end

-- A decorative fence at a lot-frame point: one rail and its end post in a Model `DecorFence`.
function LotArtWorld.decorFence(plot: Model, x: number, z: number, ctx: Ctx): Model?
	local root = ArtLibrary.root(ReplicatedStorage)
	local rail = LotArt.choose(root, ArtLibrary.find, LotArt.PATHS.Rail)
	local post = LotArt.choose(root, ArtLibrary.find, LotArt.PATHS.Post)
	if rail.mode ~= "Art" or post.mode ~= "Art" then
		for _, choice in { rail, post } do
			if choice.mode ~= "Art" then
				ctx.reportMissing(choice.path, choice.code or "MissingArtAsset")
			end
		end
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "DecorFence"
	model:SetAttribute("LotArtMode", "Art")
	local facing = ctx.facing(plot)
	local top = ctx.lotTop(plot)
	for _, piece in LotArt.decorPieces(x, z) do
		local choice = if piece.kind == "Rail" then rail else post
		local clone = ArtLibrary.prepareClone(choice.template)
		clone.Name = if piece.kind == "Rail" then "Segment_1" else "EndPost"
		clone:PivotTo(
			CFrame.new(ctx.lotPosition(plot, piece.x, piece.z, top))
				* CFrame.Angles(0, LotArt.runYaw(piece.dirX, piece.dirZ, facing), 0)
		)
		clone.Parent = model
	end
	model.Parent = plot
	return model
end

return LotArtWorld
