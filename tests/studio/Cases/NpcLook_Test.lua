--!strict
-- CM2-N1: the deterministic winter look of walking customers.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcLook = require(Shared:WaitForChild("NpcLook"))
	local expect = t.expect
	local Look = GameConfig.Customers.Npc.Look

	local function key(rgb): string
		return table.concat(rgb, ",")
	end

	t.test("looks vary and stay deterministic", function()
		local coats = {}
		local distinct = 0
		for n = 1, 8 do
			local first, second = NpcLook.forVisit(n), NpcLook.forVisit(n)
			for field, value in pairs(first) do
				if type(value) == "table" then
					expect.equal(key(value), key(second[field]))
				else
					expect.equal(value, second[field])
				end
			end
			local coat = key(first.coat)
			if not coats[coat] then
				coats[coat] = true
				distinct += 1
			end
		end
		expect.truthy(distinct >= 4)
	end)

	t.test("every colour comes from the palette", function()
		local function member(list, rgb): boolean
			for _, entry in ipairs(list) do
				if entry == rgb then
					return true
				end
			end
			return false
		end
		for n = 1, 50 do
			local look = NpcLook.forVisit(n)
			expect.truthy(member(Look.Skin, look.skin))
			expect.truthy(member(Look.Coat, look.coat))
			expect.truthy(member(Look.Pants, look.pants))
			expect.truthy(member(Look.Scarf, look.scarf))
			expect.truthy(member(Look.Beanie, look.beanie))
			expect.equal(look.boots, Look.Boots)
			expect.equal(type(look.pompom), "boolean")
			expect.truthy(table.find(Look.Scales, look.scale) ~= nil)
		end
	end)

	-- CM2-25/26: staff wear the uniform; the beanie shows the role.
	t.test("staff wear the uniform with an apron", function()
		local Uniform = GameConfig.Staff.Uniform
		local cashier = NpcLook.forStaff("Cashier")
		local worker = NpcLook.forStaff("LotWorker")
		for _, look in ipairs({ cashier, worker }) do
			expect.equal(look.coat, Uniform.Coat)
			expect.equal(look.pants, Uniform.Pants)
			expect.equal(look.scarf, Uniform.Scarf)
			expect.equal(look.skin, Uniform.Skin)
			expect.equal(look.boots, Uniform.Boots)
			expect.equal(look.apron, Uniform.Apron)
			expect.equal(look.pompom, false)
			expect.equal(look.scale, 1)
		end
		expect.equal(cashier.beanie, Uniform.Beanie.Cashier)
		expect.equal(worker.beanie, Uniform.Beanie.LotWorker)
		expect.equal(NpcLook.forStaff("LotManager").beanie, Uniform.Beanie.LotManager)
		expect.truthy(key(cashier.beanie) ~= key(worker.beanie))
		expect.equal(NpcLook.forVisit(1).apron, nil)
	end)
end
