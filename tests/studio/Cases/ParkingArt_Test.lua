--!strict
-- CM2-PARK: the car park art specs (shared/ParkingArt.lua): bays on the CarPark pads and the
-- fixtures inside the apron, off every NPC walkway and car pad.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local ParkingArt = require(Shared:WaitForChild("ParkingArt"))
	local VehicleArt = require(Shared:WaitForChild("VehicleArt"))
	local expect = t.expect

	local CarPark = GameConfig.Placement.CarPark
	local EPSILON = 1e-6

	type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

	local function footprint(spec): Box
		return {
			minX = spec.x - spec.size[1] / 2,
			maxX = spec.x + spec.size[1] / 2,
			minZ = spec.z - spec.size[3] / 2,
			maxZ = spec.z + spec.size[3] / 2,
		}
	end

	local function inside(inner: Box, outer: Box): boolean
		return inner.minX >= outer.minX - EPSILON
			and inner.maxX <= outer.maxX + EPSILON
			and inner.minZ >= outer.minZ - EPSILON
			and inner.maxZ <= outer.maxZ + EPSILON
	end

	local function boxDistance(a: Box, b: Box): number
		local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
		local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
		return math.sqrt(dx * dx + dz * dz)
	end

	local function obstacle(id: string): Box
		for _, box in NpcPath.obstacles() do
			if box.id == id then
				return box
			end
		end
		error("no obstacle " .. id)
	end

	t.test("bays sit on the CarPark pads", function()
		local rise = VehicleArt.PARKING_RISE
		for space = 1, 4 do
			local bay = ParkingArt.bay(space)
			local pad = bay.pad
			expect.equal(pad.name, "Parking_" .. space)
			expect.equal(pad.x, CarPark.X[space])
			expect.equal(pad.z, CarPark.Depth)
			expect.equal(pad.size[1], CarPark.PadWidth)
			expect.equal(pad.size[2], 0.9)
			expect.equal(pad.size[3], CarPark.PadLength)
			expect.truthy(math.abs(pad.dy - (rise - 0.45)) < EPSILON)
			local padBox = footprint(pad)
			local reference = NpcPath.parkingPad(space)
			expect.truthy(inside(padBox, reference) and inside(reference, padBox))
			local padTop = pad.dy + pad.size[2] / 2
			local names = {}
			for _, mark in bay.marks do
				table.insert(names, mark.name)
				expect.truthy(inside(footprint(mark), padBox))
				expect.truthy(mark.dy - mark.size[2] / 2 >= padTop + 0.005 - EPSILON)
				expect.equal(mark.collide, false)
			end
			expect.equal(table.concat(names, ","), "LineL,LineR,Stop")
			-- CM2-PARK Amendment 1: the corridor in front of the gate stays free.
			expect.truthy(padBox.maxX <= -10 + EPSILON or padBox.minX >= 10 - EPSILON)
		end
	end)

	t.test("fixtures stay in the apron, off the walkways", function()
		local apron = CarPark.Apron
		local apronBox = { minX = apron.minX, maxX = apron.maxX, minZ = apron.minDepth, maxZ = apron.maxDepth }
		local sign = CarPark.Fixtures.Sign
		for _, facing in { 1, -1 } do
			local names = {}
			for _, fixture in ParkingArt.fixtures(facing, 4) do
				table.insert(names, fixture.name)
				for _, part in fixture.parts do
					expect.truthy(inside(footprint(part), apronBox))
					if part.name == "Slab" then
						local slab = footprint(part)
						expect.truthy(slab.maxX <= -10 + EPSILON or slab.minX >= 10 - EPSILON)
					end
					if part.name == "LetterBowl" then
						expect.truthy(math.abs(part.x - (sign.x + facing * 0.1)) < EPSILON)
					end
				end
				if fixture.lightPart ~= nil then
					local found = false
					for _, part in fixture.parts do
						found = found or part.name == fixture.lightPart
					end
					expect.truthy(found)
				end
			end
			expect.equal(
				table.concat(names, ","),
				"CarPark_DriveL,CarPark_DriveR,CarPark_Sign,CarPark_Lamp_1,CarPark_Lamp_2"
			)
			local single = {}
			for _, fixture in ParkingArt.fixtures(facing, 1) do
				table.insert(single, fixture.name)
			end
			expect.equal(table.concat(single, ","), "CarPark_DriveL,CarPark_Sign,CarPark_Lamp_1,CarPark_Lamp_2")
		end
		local fenceLeft, fenceRight = obstacle("FenceLeft"), obstacle("FenceRight")
		local ids = {}
		for _, box in ParkingArt.footprints() do
			table.insert(ids, box.id)
			expect.truthy(inside(box, fenceLeft) or inside(box, fenceRight))
			for space = 1, 4 do
				expect.truthy(boxDistance(box, NpcPath.parkingPad(space)) >= 2)
				local door = NpcPath.door(space)
				local doorBox = { minX = door.x, maxX = door.x, minZ = door.z, maxZ = door.z }
				expect.truthy(boxDistance(box, doorBox) >= 1.5)
			end
			expect.truthy(box.maxX <= -8.15 or box.minX >= 8.15)
		end
		expect.equal(table.concat(ids, ","), "Sign,Lamp_1,Lamp_2")
	end)
end
