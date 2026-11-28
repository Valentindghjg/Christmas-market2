--!strict
-- Playtest step 73 (full mode): vehicle art in the world (CM2-14W, docs/archive/plans/CM2-14W.md).
-- Installed by RunPlaytest.execute after Steps/LotArt. On every free plot (neither the player's
-- nor the shadow's), all at once: (a) the supplier truck pulls in with 9 `TreeBundle`s on its bed
-- (`syncReceiving` with 12 arriving), (b) it leaves empty, (c) four numbered customer cars park
-- (9301..9304) with the art of `carStyle(n)` and its `CAR_COLORS` paint, and (d) four loaded cars
-- leave with the roof tree resting on the cargo anchor (lowest of all parts), welded, moves with the car. Poses are read off the models; the
-- receiving view and the plot are reset at the end.
return function(ctx: any)
	local R = ctx.R
	local S = ctx.S
	local GameConfig = ctx.GameConfig
	local addStep = ctx.addStep
	local check = ctx.check
	local poll = ctx.poll
	local plotFolder = ctx.plotFolder

	local Shared = ctx.ReplicatedStorage:WaitForChild("Shared")
	local Stocking = require(Shared:WaitForChild("Stocking")) :: any
	local VehicleArt = require(Shared:WaitForChild("VehicleArt")) :: any

	local POSITION_TOLERANCE = 0.05
	local TRUCK_X = 46
	local TRUCK_Y = 0.05
	local TRUCK_LANE_DEPTH = -22 -- bay 1
	local CAR_Y = 0.82
	local BUNDLE_HEADROOM = 2.1
	local ORDER_NUMBERS = { 9301, 9302, 9303, 9304 }

	local function facingOf(plot: Model): number
		return Stocking.facing((plot.PrimaryPart :: BasePart).Position.Z)
	end

	-- A world point in the lot frame of `plot`: (x - cx, (z - cz) * facing).
	local function lotFrame(plot: Model, point: Vector3): (number, number)
		local c = (plot.PrimaryPart :: BasePart).Position
		return point.X - c.X, (point.Z - c.Z) * facingOf(plot)
	end

	local function expectPose(label: string, plot: Model, pivot: CFrame, x: number, z: number, y: number)
		local lx, lz = lotFrame(plot, pivot.Position)
		local offset = math.max(math.abs(lx - x), math.abs(lz - z), math.abs(pivot.Position.Y - y))
		check(
			offset <= POSITION_TOLERANCE,
			string.format(
				"%s at lot (%.2f, %.2f) y %.3f, expected (%.2f, %.2f) y %.3f",
				label,
				lx,
				lz,
				pivot.Position.Y,
				x,
				z,
				y
			)
		)
	end

	local function expectLook(label: string, pivot: CFrame, expectedSign: number)
		check(
			math.sign(pivot.LookVector.Z) == expectedSign and math.abs(pivot.LookVector.Z) >= 0.999,
			string.format("%s look z %.3f, expected sign %d", label, pivot.LookVector.Z, expectedSign)
		)
	end

	-- Bottom of a part's oriented box.
	local function partBottom(part: BasePart): number
		local cf = part.CFrame
		local size = part.Size
		local half = (
			math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z
		) / 2
		return cf.Position.Y - half
	end

	local function lowest(model: Model): number
		local bottom = math.huge
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				bottom = math.min(bottom, partBottom(descendant))
			end
		end
		return bottom
	end

	local function freePlots(): { Model }
		local plots: { Model } = {}
		for _, plotId in GameConfig.PersonalPlotIds do
			if plotId ~= R.plotId and plotId ~= S.plotId then
				local plot = plotFolder(plotId)
				if plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil then
					table.insert(plots, plot)
				end
			end
		end
		return plots
	end

	addStep("73", "VEHICLE_ART", { "02a" }, function()
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any
		local receiving = GameConfig.Receiving
		local plots = freePlots()
		local sides: { [number]: boolean } = {}
		for _, plot in plots do
			sides[facingOf(plot)] = true
		end
		check(#plots >= 2, string.format("%d free plots, expected at least 2", #plots))
		check(sides[1] == true and sides[-1] == true, "the free plots do not cover both road sides")

		local trucks, cars = 0, 0
		local ok, err = pcall(function()
			-- (a) The truck arrives with nine bundles.
			for _, plot in plots do
				check(
					WorldService.syncReceiving(plot.Name, {
						[1] = {
							speciesId = "NobleFir",
							counts = { Small = 0, Medium = 0, Large = 0 },
							total = 0,
							arriving = 12,
							arrivesIn = receiving.TruckPullInSeconds,
						},
					}),
					"syncReceiving refused " .. plot.Name
				)
			end
			task.wait(receiving.TruckPullInSeconds + 1)
			local arrived: { Model } = {}
			for _, plot in plots do
				local label = plot.Name .. " DeliveryTruck"
				local truck = plot:FindFirstChild("DeliveryTruck")
				check(truck ~= nil and truck:IsA("Model"), label .. " is missing")
				local model = truck :: Model
				check(model:GetAttribute("VehicleArtMode") == "Art", label .. " is not art")
				check(
					model:GetAttribute("VehicleArtPath") == VehicleArt.TRUCK_PATH,
					label .. " path is " .. tostring(model:GetAttribute("VehicleArtPath"))
				)
				expectPose(label, plot, model:GetPivot(), TRUCK_X, TRUCK_LANE_DEPTH, TRUCK_Y)
				expectLook(label, model:GetPivot(), facingOf(plot))
				local cargo = model:FindFirstChild("Cargo")
				check(cargo ~= nil and cargo:IsA("Model"), label .. " has no Cargo")
				local top = WorldService.carCargoTop(model).Position.Y
				local bundles = 0
				for _, child in (cargo :: Model):GetChildren() do
					if child:IsA("Model") and child.Name == "Bundle" then
						bundles += 1
						local box, size = child:GetBoundingBox()
						local bottom, ceiling = box.Position.Y - size.Y / 2, box.Position.Y + size.Y / 2
						check(
							bottom >= top - POSITION_TOLERANCE,
							string.format("%s bundle bottom %.3f below the cargo top %.3f", label, bottom, top)
						)
						check(
							ceiling <= top + BUNDLE_HEADROOM,
							string.format("%s bundle top %.3f above %.3f", label, ceiling, top + BUNDLE_HEADROOM)
						)
					end
				end
				check(bundles == 9, string.format("%s carries %d bundles, expected 9", label, bundles))
				table.insert(arrived, model)
				trucks += 1
			end

			-- (b) The truck leaves empty.
			for _, plot in plots do
				WorldService.syncReceiving(plot.Name, {
					[1] = {
						speciesId = "NobleFir",
						counts = { Small = 0, Medium = 0, Large = 0 },
						total = 0,
						arriving = 0,
						arrivesIn = -1,
					},
				})
			end
			for index, plot in plots do
				check(arrived[index]:FindFirstChild("Cargo") == nil, plot.Name .. " truck keeps its Cargo")
			end
			check(
				poll(function()
					for _, plot in plots do
						if plot:FindFirstChild("DeliveryTruck") ~= nil then
							return false
						end
					end
					return true
				end, receiving.TruckLeaveSeconds + 2),
				"a delivery truck stayed on its plot"
			)

			-- (c) Four numbered cars park.
			for _, plot in plots do
				local orders: { any } = {}
				for space, orderNumber in ORDER_NUMBERS do
					table.insert(orders, {
						orderNumber = orderNumber,
						speciesId = "NobleFir",
						sizeId = "Medium",
						heightTenths = 0,
						parkingSpace = space,
						expiresAt = 0,
						carried = false,
					})
				end
				check(
					WorldService.syncCustomerOrders(plot.Name, { orders = orders }, nil),
					"syncCustomerOrders refused " .. plot.Name
				)
			end
			task.wait(2.5)
			local path = GameConfig.Customers.Npc.Path
			for _, plot in plots do
				local folder = plot:FindFirstChild("CustomerOrders") :: Instance
				for space, orderNumber in ORDER_NUMBERS do
					local label = string.format("%s CustomerCar_%d", plot.Name, orderNumber)
					local car = folder:FindFirstChild("CustomerCar_" .. orderNumber)
					check(car ~= nil and car:IsA("Model"), label .. " is missing")
					local model = car :: Model
					local artPath, colour = VehicleArt.carStyle(orderNumber)
					check(model:GetAttribute("VehicleArtMode") == "Art", label .. " is not art")
					check(
						model:GetAttribute("VehicleArtPath") == artPath,
						label .. " path is " .. tostring(model:GetAttribute("VehicleArtPath"))
					)
					local paint = model:FindFirstChild("Paint", true)
					check(paint ~= nil and paint:IsA("BasePart"), label .. " has no Paint")
					local rgb = VehicleArt.CAR_COLORS[colour]
					local color = (paint :: BasePart).Color
					check(
						math.abs(math.round(color.R * 255) - rgb[1]) <= 1
							and math.abs(math.round(color.G * 255) - rgb[2]) <= 1
							and math.abs(math.round(color.B * 255) - rgb[3]) <= 1,
						string.format(
							"%s Paint is %d,%d,%d, expected %d,%d,%d",
							label,
							math.round(color.R * 255),
							math.round(color.G * 255),
							math.round(color.B * 255),
							rgb[1],
							rgb[2],
							rgb[3]
						)
					)
					expectPose(
						label,
						plot,
						model:GetPivot(),
						path.ParkingFirstX + (space - 1) * path.ParkingStep,
						path.ParkingDepth,
						CAR_Y
					)
					expectLook(label, model:GetPivot(), -facingOf(plot))
					local root = model.PrimaryPart
					check(root ~= nil and root.Name == "ArtRoot", label .. " PrimaryPart is not ArtRoot")
					check(
						(root :: BasePart):FindFirstChild("Label") ~= nil
							and (root :: BasePart):FindFirstChild("LoadOrder") ~= nil,
						label .. " ArtRoot has no Label or LoadOrder"
					)
					check(
						WorldService.findOrderTarget(plot.Name, "Car", orderNumber) == root,
						label .. " findOrderTarget is not its ArtRoot"
					)
					cars += 1
				end
			end

			-- (d) The cars leave loaded.
			local parkedPivots: { [Model]: CFrame } = {}
			local roofOffsets: { [Model]: CFrame } = {}
			local labels: { [Model]: string } = {}
			for _, plot in plots do
				local before = plot:FindFirstChild("CustomerOrders") :: Instance
				for _, parked in before:GetChildren() do
					if parked:IsA("Model") then
						parkedPivots[parked] = parked:GetPivot()
					end
				end
				check(
					WorldService.syncCustomerOrders(plot.Name, { orders = {}, loadedNumbers = ORDER_NUMBERS }, nil),
					"syncCustomerOrders refused (d) " .. plot.Name
				)
				local folder = plot:FindFirstChild("CustomerOrders") :: Instance
				local leaving = 0
				for _, child in folder:GetChildren() do
					if child.Name == "LeavingCar" and child:IsA("Model") then
						leaving += 1
						local label = plot.Name .. " LeavingCar"
						local roof = child:FindFirstChild("RoofTree")
						check(roof ~= nil and roof:IsA("Model"), label .. " has no RoofTree")
						local clearance = lowest(roof :: Model) - WorldService.carCargoTop(child).Position.Y
						check(
							clearance >= -0.05 and clearance <= 0.3,
							string.format("%s roof tree rests %.3f from the cargo anchor", label, clearance)
						)
						if roof ~= nil and roof:IsA("Model") then
							local parts = 0
							for _, part in roof:GetDescendants() do
								if part:IsA("BasePart") then
									parts += 1
									local welded = false
									for _, weld in part:GetChildren() do
										if
											weld:IsA("WeldConstraint")
											and weld.Enabled
											and weld.Part0 == child.PrimaryPart
											and weld.Part1 == part
										then
											welded = true
										end
									end
									check(
										welded,
										string.format("%s roof part %s has no weld to the car", label, part.Name)
									)
								end
							end
							check(parts > 0, label .. " roof tree has no parts")
							roofOffsets[child] = child:GetPivot():ToObjectSpace(roof:GetPivot())
							labels[child] = label
						end
					end
				end
				check(leaving == #ORDER_NUMBERS, string.format("%s has %d leaving cars", plot.Name, leaving))
			end
			-- The cars are still driving (CAR_DRIVE_SECONDS is 2): the roof must move with them.
			task.wait(0.5)
			for car, rel in roofOffsets do
				local roof = car:FindFirstChild("RoofTree")
				if car.Parent ~= nil and roof ~= nil and roof:IsA("Model") then
					local now = car:GetPivot():ToObjectSpace(roof:GetPivot())
					local slide = (now.Position - rel.Position).Magnitude
					check(slide <= 0.01, string.format("%s roof tree slid %.3f on the car", labels[car], slide))
					local moved = (car:GetPivot().Position - parkedPivots[car].Position).Magnitude
					check(moved > 0.1, string.format("%s did not drive off", labels[car]))
				end
			end
			check(
				poll(function()
					for _, plot in plots do
						local folder = plot:FindFirstChild("CustomerOrders")
						if folder ~= nil and folder:FindFirstChild("LeavingCar") ~= nil then
							return false
						end
					end
					return true
				end, 5),
				"a leaving car stayed on its plot"
			)
		end)
		for _, plot in plots do
			WorldService.syncReceiving(plot.Name, nil)
		end
		if not ok then
			error(tostring(err), 0)
		end
		return string.format("trucks=%d cars=%d", trucks, cars)
	end)
end
