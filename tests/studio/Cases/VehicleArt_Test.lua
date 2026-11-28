-- Vehicle art in the world: paths, car styles, yaws, cargo count and bundle layout (CM2-14W). Uses fake
-- nodes, so it runs in Studio and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local ArtLibrary = require(Shared.ArtLibrary)
	local LotArt = require(Shared.LotArt)
	local MapLayout = require(Shared.MapLayout)
	local VehicleArt = require(Shared.VehicleArt)
	local expect = t.expect

	-- A fake instance with the members ArtLibrary.find reads.
	local function node(className)
		local value = { children = {} }
		function value:FindFirstChild(name)
			return self.children[name]
		end
		function value:IsA(name)
			return name == className
		end
		function value:GetAttribute()
			return nil
		end
		return value
	end

	t.test("vehicle paths are valid art paths", function()
		expect.truthy(ArtLibrary.isValidPath(VehicleArt.TRUCK_PATH))
		expect.equal(#VehicleArt.CAR_PATHS, 3)
		for _, path in ipairs(VehicleArt.CAR_PATHS) do
			expect.truthy(ArtLibrary.isValidPath(path))
		end
	end)

	t.test("art is used when present, primitive when absent", function()
		local root = node("Folder")
		local vehicles = node("Folder")
		root.children.Vehicles = vehicles
		vehicles.children.CustomerWagon = node("Model")
		local art = LotArt.choose(root, ArtLibrary.find, "Vehicles/CustomerWagon")
		expect.equal(art.mode, "Art")
		local missing = LotArt.choose(root, ArtLibrary.find, VehicleArt.TRUCK_PATH)
		expect.equal(missing.mode, "Primitive")
		expect.equal(missing.code, "MissingArtAsset")
	end)

	t.test("car style covers 3 bodies x 6 colours", function()
		local path, colour = VehicleArt.carStyle(1)
		expect.equal(path, "Vehicles/CustomerHatchback")
		expect.equal(colour, 1)
		path, colour = VehicleArt.carStyle(2)
		expect.equal(path, "Vehicles/CustomerWagon")
		expect.equal(colour, 2)
		path, colour = VehicleArt.carStyle(7)
		expect.equal(path, "Vehicles/CustomerWagon")
		expect.equal(colour, 1)
		local seen = {}
		local distinct = 0
		for n = 1, 18 do
			local p, c = VehicleArt.carStyle(n)
			local key = p .. "#" .. c
			if not seen[key] then
				seen[key] = true
				distinct += 1
			end
		end
		expect.equal(distinct, 18)
		local p19, c19 = VehicleArt.carStyle(19)
		expect.equal(p19, "Vehicles/CustomerHatchback")
		expect.equal(c19, 1)
		for _, bad in ipairs({ 0, -3, 0 / 0, "x" }) do
			local p, c = VehicleArt.carStyle(bad)
			expect.equal(p, "Vehicles/CustomerHatchback")
			expect.equal(c, 1)
		end
	end)

	t.test("yaw per plot side", function()
		expect.equal(#MapLayout.PLOTS, 6)
		for _, plot in ipairs(MapLayout.PLOTS) do
			-- CFrame.Angles(0, yaw, 0).LookVector.Z = -cos(yaw): the cab faces the road, the nose into the lot.
			local truckLook = -math.cos(VehicleArt.truckYaw(plot.facing))
			local carLook = -math.cos(VehicleArt.carYaw(plot.facing))
			expect.equal(truckLook * plot.facing > 0, true)
			expect.equal(carLook * plot.facing < 0, true)
		end
	end)

	t.test("cargo count is clamped", function()
		local inputs = { 0, 5, 9, 12, -1, 0 / 0, "3", 2.7 }
		local expected = { 0, 5, 9, 9, 0, 0, 0, 2 }
		for index, value in ipairs(inputs) do
			expect.equal(VehicleArt.cargoCount(value), expected[index])
		end
		expect.equal(VehicleArt.cargoCount(math.huge), 0)
	end)

	t.test("box bottom of an oriented part", function()
		local function near(a, b)
			expect.truthy(math.abs(a - b) <= 1e-6)
		end
		near(VehicleArt.boxBottom(5, 2, 3, 4, 0, 1, 0), 3.5)
		near(VehicleArt.boxBottom(5, 2, 3, 4, 0, 0, 1), 3)
		near(VehicleArt.boxBottom(5, 2, 3, 4, 0, 0.7071, 0.7071), 5 - (3 + 4) * 0.7071 / 2)
		expect.equal(VehicleArt.boxBottom(0 / 0, 2, 3, 4, 0, 1, 0), math.huge)
		expect.equal(VehicleArt.boxBottom(5, "x", 3, 4, 0, 1, 0), math.huge)
		expect.equal(VehicleArt.boxBottom(5, 2, 3, 4, 0, math.huge, 0), math.huge)
	end)

	t.test("roof lift settles the tree on each car look", function()
		local carTop = 0.82
		for _, anchor in ipairs({ 4.0, 4.0, 4.6 }) do
			local top = carTop + anchor
			for _, lowest in ipairs({ top - 1.03, top - 0.79, top, top + 0.4 }) do
				local clearance = lowest + VehicleArt.roofLift(lowest, top) - top
				expect.truthy(math.abs(clearance - 0.05) <= 1e-9)
				expect.truthy(clearance >= -0.05 and clearance <= 0.3)
			end
		end
		expect.equal(VehicleArt.roofLift(0 / 0, 4), 0)
		expect.equal(VehicleArt.roofLift(1, math.huge), 0)
	end)

	t.test("nine bundles fit the truck bed", function()
		local anchorY, anchorZ = 2.6, 2.1
		local half = 0.515 -- the TreeBundle's half depth; its height is 1.03
		local rows = { {}, {} }
		for k = 0, VehicleArt.MAX_BUNDLES - 1 do
			local rise, dz = VehicleArt.bundleOffset(k)
			local z = anchorZ + dz
			expect.truthy(z - half >= -1.85 and z + half <= 6.05)
			table.insert(rows[if rise == 0 then 1 else 2], z)
			if rise > 0 then
				expect.truthy(anchorY + rise + 2 * half <= 4.7)
			end
		end
		expect.equal(#rows[1], 6)
		expect.equal(#rows[2], 3)
		for _, row in ipairs(rows) do
			table.sort(row)
			for index = 2, #row do
				expect.truthy(row[index] - row[index - 1] >= 2 * half)
			end
		end
	end)
end
