--!strict
-- Playtest step 66 (full mode): lot and HQ art in the world (CM2-13W, docs/archive/plans/CM2-13W.md).
-- Installed by RunPlaytest.execute after Steps/PlotPicker. Read-only on all six plots: HQ, counter,
-- bays, decorative fences and the lot fence show the art at the lot-frame positions, facing the
-- road; bundles are checked on a free plot through syncReceiving, which is cleared again.
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- CM2-13W: `66 LOT_ART` in `Steps/LotArt.lua` (on all six plots the HQ art, the counter art with
-- its invisible `CounterBase`, `CheckoutPrompt`, `Checkout1` and `CashierStand`, the four
-- `BayArt_<i>` with their `BundleBase`, the `DecorFence` models and the lot fence art with 11 + 2 x
-- level pieces face the road at their lot-frame positions within 0.05-0.1 studs; five bundles on a
-- free plot's `Bay_1` show as art on the deck top and its second row, then the bay is cleared).
-- CM2-GATEW: each plot also has the `LotGate` art at lot (28, 28), y at the map ground, front to
-- the road, one off `NightLight` in each of `Light1` and `Light2`, and a name board that mirrors
-- the lot sign's `NameSource` and text.
return function(ctx: any)
	local R = ctx.R
	local S = ctx.S
	local GameConfig = ctx.GameConfig
	local addStep = ctx.addStep
	local check = ctx.check
	local plotFolder = ctx.plotFolder

	local Shared = ctx.ReplicatedStorage:WaitForChild("Shared")
	local LotArt = require(Shared:WaitForChild("LotArt")) :: any
	local Stocking = require(Shared:WaitForChild("Stocking")) :: any
	local CollectionService = game:GetService("CollectionService")

	local POSITION_TOLERANCE = 0.05
	local ATTACHMENT_TOLERANCE = 0.1
	local BUNDLE_TOLERANCE = 0.06
	local BAY_X = 35
	local BAY_FIRST_DEPTH = -22
	local BAY_DEPTH_STEP = 6

	local worst = 0

	-- A world point in the lot frame of `plot`: (x - cx, (z - cz) * facing), c = LotGround.
	local function lotFrame(plot: Model, point: Vector3): (number, number, number)
		local c = (plot.PrimaryPart :: BasePart).Position
		local facing = Stocking.facing(c.Z)
		return point.X - c.X, (point.Z - c.Z) * facing, facing
	end

	-- Checks that `cframe` stands at the lot-frame (x, z) within `tolerance` and records the offset.
	local function expectAt(label: string, plot: Model, cframe: CFrame, x: number, z: number, tolerance: number)
		local lx, lz = lotFrame(plot, cframe.Position)
		local offset = math.max(math.abs(lx - x), math.abs(lz - z))
		worst = math.max(worst, offset)
		check(offset <= tolerance, string.format("%s at lot (%.2f, %.2f), expected (%.2f, %.2f)", label, lx, lz, x, z))
	end

	local function expectFacing(label: string, plot: Model, cframe: CFrame)
		local _, _, facing = lotFrame(plot, cframe.Position)
		check(
			cframe.LookVector.Z * facing >= 0.999,
			string.format("%s does not face the road (look z %.3f, facing %d)", label, cframe.LookVector.Z, facing)
		)
	end

	local function attachment(root: Instance, name: string): Attachment
		local value = root:FindFirstChild(name, true)
		check(value ~= nil and value:IsA("Attachment"), root.Name .. " has no attachment " .. name)
		return value :: Attachment
	end

	local function model(parent: Instance, name: string, label: string): Model
		local value = parent:FindFirstChild(name)
		check(value ~= nil and value:IsA("Model"), label .. " is missing")
		return value :: Model
	end

	local function groundTop(plot: Model): number
		local ground = plot.PrimaryPart :: BasePart
		return ground.Position.Y + ground.Size.Y / 2
	end

	local function plotModel(plotId: string): Model
		local plot = plotFolder(plotId)
		check(plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil, plotId .. " is missing")
		return plot :: Model
	end

	-- (f) Five bundles on Bay_1 of a free plot: art, bottoms on the deck top and the second row.
	local function bundleCheck(WorldService: any): string
		local freeId: string? = nil
		for _, plotId in GameConfig.PersonalPlotIds do
			if plotId ~= R.plotId and plotId ~= S.plotId then
				freeId = plotId
				break
			end
		end
		check(freeId ~= nil, "no free plot")
		local plot = plotModel(freeId :: string)
		local failure: string? = nil
		local ok, err = pcall(function()
			check(
				WorldService.syncReceiving(freeId, {
					[1] = {
						speciesId = "DouglasFir",
						counts = { Small = 0, Medium = 5, Large = 0 },
						total = 5,
						arriving = 0,
						arrivesIn = -1,
					},
				}),
				"syncReceiving refused " .. tostring(freeId)
			)
			local receiving = plot:FindFirstChild("Receiving") :: Instance
			local bay = receiving:FindFirstChild("Bay_1") :: BasePart
			local bundles = bay:FindFirstChild("Bundles")
			check(bundles ~= nil, "Bay_1 has no Bundles")
			check(
				(bundles :: Instance):GetAttribute("LotArtMode") == "Art",
				"Bundles LotArtMode is " .. tostring((bundles :: Instance):GetAttribute("LotArtMode"))
			)
			local bottoms: { number } = {}
			for _, child in (bundles :: Instance):GetChildren() do
				if child:IsA("Model") and child.Name == "Bundle" then
					local box, size = (child :: Model):GetBoundingBox()
					table.insert(bottoms, box.Position.Y - size.Y / 2)
				end
			end
			check(#bottoms == 5, string.format("Bay_1 shows %d Bundle models, expected 5", #bottoms))
			table.sort(bottoms)
			local deckTop = bay.Position.Y + bay.Size.Y / 2
			for index, bottom in bottoms do
				local expected = deckTop + (if index <= 3 then 0 else LotArt.BUNDLE_ROW)
				worst = math.max(worst, math.abs(bottom - expected))
				check(
					math.abs(bottom - expected) <= BUNDLE_TOLERANCE,
					string.format("bundle %d bottom %.3f, expected %.3f", index, bottom, expected)
				)
			end
		end)
		WorldService.syncReceiving(freeId, nil)
		if not ok then
			failure = tostring(err)
		end
		if failure ~= nil then
			error(failure, 0)
		end
		return "bundles 5 art"
	end

	addStep("66", "LOT_ART", { "02a" }, function()
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any
		local LotGateWorld = require(ctx.Services:WaitForChild("LotGateWorld")) :: any
		local hqArt, counters, bays, decor, fences, pieces, gates = 0, 0, 0, 0, 0, 0, 0
		local levels: { string } = {}
		worst = 0
		for _, plotId in GameConfig.PersonalPlotIds do
			local plot = plotModel(plotId)
			local top = groundTop(plot)

			-- (a) HQ art.
			local hq = model(plot, "StarterSalesTent", plotId .. " StarterSalesTent")
			local level = hq:GetAttribute("HqLevel")
			check(
				hq:GetAttribute("HqArtMode") == "Art",
				plotId .. " HqArtMode is " .. tostring(hq:GetAttribute("HqArtMode"))
			)
			check(
				hq:GetAttribute("HqArtPath") == LotArt.hqPath(level),
				plotId .. " HqArtPath is " .. tostring(hq:GetAttribute("HqArtPath"))
			)
			local cx, cz = LotArt.hqCentre(level)
			expectAt(plotId .. " StarterSalesTent", plot, hq:GetPivot(), cx, cz, POSITION_TOLERANCE)
			local dropY = math.abs(hq:GetPivot().Position.Y - top)
			worst = math.max(worst, dropY)
			check(
				dropY <= POSITION_TOLERANCE,
				string.format("%s StarterSalesTent pivot %.3f above the lot", plotId, dropY)
			)
			expectFacing(plotId .. " StarterSalesTent", plot, hq:GetPivot())
			local fit = hq:GetAttribute("FitScale")
			check(type(fit) == "number" and fit > 0 and fit <= 1, plotId .. " FitScale is " .. tostring(fit))
			hqArt += 1
			table.insert(levels, tostring(level))

			-- (b) Counter art with its invisible anchor.
			local counter = model(plot, "CheckoutCounter", plotId .. " CheckoutCounter")
			check(counter:GetAttribute("LotArtMode") == "Art", plotId .. " CheckoutCounter is not art")
			expectFacing(plotId .. " CheckoutCounter", plot, counter:GetPivot())
			expectAt(plotId .. " CheckoutCounter", plot, counter:GetPivot(), 16, -14, POSITION_TOLERANCE)
			local base = counter:FindFirstChild("CounterBase")
			check(base ~= nil and base:IsA("BasePart"), plotId .. " CounterBase missing")
			check((base :: BasePart).Transparency == 1, plotId .. " CounterBase is visible")
			check(base:FindFirstChild("CheckoutPrompt") ~= nil, plotId .. " CheckoutPrompt missing")
			expectAt(
				plotId .. " Checkout1",
				plot,
				attachment(counter, "Checkout1").WorldCFrame,
				16,
				-11,
				ATTACHMENT_TOLERANCE
			)
			expectAt(
				plotId .. " CashierStand",
				plot,
				attachment(counter, "CashierStand").WorldCFrame,
				16,
				-16.5,
				ATTACHMENT_TOLERANCE
			)
			counters += 1

			-- (c) Bay art with invisible anchors.
			local receiving = plot:FindFirstChild("Receiving")
			check(receiving ~= nil, plotId .. " has no Receiving")
			for index = 1, GameConfig.Receiving.BayCount do
				local anchor = (receiving :: Instance):FindFirstChild("Bay_" .. index)
				check(anchor ~= nil and anchor:IsA("BasePart"), plotId .. " Bay_" .. index .. " missing")
				check((anchor :: BasePart).Transparency == 1, plotId .. " Bay_" .. index .. " is visible")
				local art = model(receiving :: Instance, "BayArt_" .. index, plotId .. " BayArt_" .. index)
				expectFacing(plotId .. " BayArt_" .. index, plot, art:GetPivot())
				expectAt(
					plotId .. " BayArt_" .. index,
					plot,
					art:GetPivot(),
					BAY_X,
					BAY_FIRST_DEPTH + BAY_DEPTH_STEP * (index - 1),
					POSITION_TOLERANCE
				)
				local deckTop = (anchor :: BasePart).Position.Y + (anchor :: BasePart).Size.Y / 2
				local baseY = attachment(art, "BundleBase").WorldPosition.Y
				worst = math.max(worst, math.abs(baseY - deckTop))
				check(
					math.abs(baseY - deckTop) <= POSITION_TOLERANCE,
					string.format("%s BayArt_%d BundleBase y %.3f, deck top %.3f", plotId, index, baseY, deckTop)
				)
				bays += 1
			end

			-- (d) Decorative fences.
			local decorCount = 0
			for _, child in plot:GetChildren() do
				if child:IsA("Model") and child.Name == "DecorFence" then
					decorCount += 1
					check(child:GetAttribute("LotArtMode") == "Art", plotId .. " DecorFence is not art")
					check(child:FindFirstChild("Segment_1") ~= nil, plotId .. " DecorFence has no Segment_1")
					check(child:FindFirstChild("EndPost") ~= nil, plotId .. " DecorFence has no EndPost")
				end
			end
			check(
				decorCount == #GameConfig.Placement.DecorFences,
				string.format(
					"%s has %d DecorFence, expected %d",
					plotId,
					decorCount,
					#GameConfig.Placement.DecorFences
				)
			)
			decor += decorCount

			-- (e) The lot fence, when the plot has one.
			local visuals = plot:FindFirstChild("ProgressionVisuals")
			local fence = visuals and visuals:FindFirstChild("LotFence")
			if fence then
				check(fence:GetAttribute("LotArtMode") == "Art", plotId .. " LotFence is not art")
				local count = 0
				for _, descendant in fence:GetDescendants() do
					if
						descendant:IsA("Model")
						and (string.sub(descendant.Name, 1, 8) == "Segment_" or descendant.Name == "EndPost")
					then
						count += 1
					end
				end
				local fenceLevel = fence:GetAttribute("LotExpansionLevel")
				check(type(fenceLevel) == "number", plotId .. " LotFence has no LotExpansionLevel")
				check(
					count == 11 + 2 * fenceLevel,
					string.format("%s LotFence has %d pieces, expected %d", plotId, count, 11 + 2 * fenceLevel)
				)
				fences += 1
				pieces += count
			end

			-- (g) The entrance gate (CM2-GATEW): art, pose, two night lights, mirrored name.
			local gate = model(plot, "LotGate", plotId .. " LotGate")
			check(
				gate:GetAttribute("LotArtMode") == "Art",
				plotId .. " LotGate LotArtMode is " .. tostring(gate:GetAttribute("LotArtMode"))
			)
			local gateX, gateZ = LotArt.gatePose()
			expectAt(plotId .. " LotGate", plot, gate:GetPivot(), gateX, gateZ, ATTACHMENT_TOLERANCE)
			local gateDrop = math.abs(gate:GetPivot().Position.Y - (top - LotArt.FENCE_BASE_DROP))
			worst = math.max(worst, gateDrop)
			check(
				gateDrop <= ATTACHMENT_TOLERANCE,
				string.format("%s LotGate pivot y is off by %.3f", plotId, gateDrop)
			)
			expectFacing(plotId .. " LotGate", plot, gate:GetPivot())
			for _, lightName in { "Light1", "Light2" } do
				local lights = 0
				for _, child in attachment(gate, lightName):GetChildren() do
					if child:IsA("Light") and CollectionService:HasTag(child, GameConfig.DayCycle.NightLightTag) then
						lights += 1
					end
				end
				check(lights == 1, string.format("%s LotGate %s holds %d night lights", plotId, lightName, lights))
			end
			local gateName = LotGateWorld.nameLabel(plot)
			local signBoard = plot:FindFirstChild("LotSign") and plot.LotSign:FindFirstChild("Board")
			local signGui = signBoard and signBoard:FindFirstChild("SignFront")
			local signFrame = signGui and signGui:FindFirstChild("Frame")
			local signName = signFrame and signFrame:FindFirstChild("Name")
			check(gateName ~= nil and signName ~= nil, plotId .. " gate or lot sign name label is missing")
			check(
				(gateName :: TextLabel):GetAttribute("NameSource") == (signName :: TextLabel):GetAttribute("NameSource")
					and (gateName :: TextLabel).Text == (signName :: TextLabel).Text,
				string.format(
					"%s gate name '%s' differs from the lot sign '%s'",
					plotId,
					(gateName :: TextLabel).Text,
					(signName :: TextLabel).Text
				)
			)
			gates += 1
		end
		check(fences >= 1, "no plot has a LotFence")

		local bundles = bundleCheck(WorldService)
		return string.format(
			"6 plots: hq art %d (levels %s), counters %d, bays %d, decor %d, fences %d (%d pieces), gates %d; %s; worst offset %.2f",
			hqArt,
			table.concat(levels, ","),
			counters,
			bays,
			decor,
			fences,
			pieces,
			gates,
			bundles,
			worst
		)
	end)
end
