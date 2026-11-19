--!strict
return function(t)
	local Service = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("CompanyStateService")
	)
	local expect = t.expect

	local function fakePersistence()
		local records = {}
		return {
			load = function(_, companyId, ownerUserId)
				local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
				local BusinessState = require(Shared:WaitForChild("BusinessState"))
				records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
				return records[companyId], nil
			end,
			save = function(_, companyId, state)
				records[companyId] = state
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}
	end

	local function order(requestId)
		return {
			version = 1,
			requestId = requestId,
			action = "Supplier.PlaceOrder",
			payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2 },
		}
	end

	-- The authoritative service derives the cost and increments revision once.
	t.test("applies a purchase once", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		local response = service:handle("personal:42", 42, order("order_1111"))
		expect.truthy(response.ok)
		expect.equal(response.data.cost, 64)
		expect.equal(response.revision, 1)
	end)

	-- A replay cannot debit a second time or increment revision.
	t.test("rejects replayed financial request", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.truthy(service:handle("personal:42", 42, order("order_2222")).ok)
		local replay = service:handle("personal:42", 42, order("order_2222"))
		expect.falsy(replay.ok)
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(replay.revision, 1)
	end)

	-- Autosave persists all healthy sessions without accepting client input.
	t.test("autosaves loaded company", function()
		local saves = 0
		local persistence = fakePersistence()
		local originalSave = persistence.save
		persistence.save = function(self, companyId, state)
			saves += 1
			return originalSave(self, companyId, state)
		end
		local service = Service.new(persistence, function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.truthy(service:autosaveAll())
		expect.equal(saves, 1)
	end)
end
