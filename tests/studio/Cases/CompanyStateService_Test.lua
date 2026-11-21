--!strict
return function(t)
	local BusinessState = require(game:GetService("ReplicatedStorage").Shared.BusinessState)
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

	-- Auto pricing mutates in memory and is persisted once by the next flush.
	t.test("applies automatic pricing through the authoritative save boundary", function()
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
		local state = service:loadPersonalCompany(42)
		state.autoPricing = true
		state.layout.placements.fir_1 = { speciesId = "FrasierFir", sizeId = "Medium" }
		local ok, updated = service:applyAutoPricingAll()
		expect.truthy(ok)
		expect.equal(updated, 1)
		expect.equal(state.mediumPrices.FrasierFir, 78)
		expect.equal(saves, 0)
		expect.truthy(service:isDirty("personal:42"))
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
		-- An unchanged price does not dirty the record again.
		local _, repeated = service:applyAutoPricingAll()
		expect.equal(repeated, 0)
		expect.falsy(service:isDirty("personal:42"))
	end)

	t.test("simulates a successful customer sale through the save boundary", function()
		local saves = 0
		local persistence = fakePersistence()
		local originalSave = persistence.save
		persistence.save = function(self, companyId, state)
			saves += 1
			return originalSave(self, companyId, state)
		end
		local service = Service.new(persistence, function()
			return 100
		end, function()
			return 0
		end)
		local synced = 0
		service:setPlacementsChangedHandler(function(companyId, placements)
			expect.equal(companyId, "personal:42")
			expect.equal(next(placements), nil)
			synced += 1
		end)
		local state = service:loadPersonalCompany(42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		local ok, sales = service:simulateCustomerVisits()
		expect.truthy(ok)
		expect.equal(sales, 1)
		expect.equal(state.sales, 1)
		expect.equal(synced, 1)
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
	end)

	t.test("lot worker unloads delivered stock through the save boundary", function()
		local persistence = fakePersistence()
		local service = Service.new(persistence, function()
			return 160
		end)
		local state = service:loadPersonalCompany(42)
		state.staff.LotWorker = 1
		expect.truthy(BusinessState.placeOrder(state, "worker_999", "FrasierFir", "Medium", 1, 100))
		expect.truthy(BusinessState.reconcileDeliveries(state, 160))
		local ok, unloaded = service:autoUnloadDeliveriesAll()
		expect.truthy(ok)
		expect.equal(unloaded, 1)
		expect.equal(state.pendingOrders["order:worker_999"], nil)
		expect.equal(state.stock["FrasierFir:Medium"], 1)
	end)

	t.test("cashier raises customer processing capacity", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local state = service:loadPersonalCompany(42)
		state.staff.Cashier = 1
		state.layout.placements.fir_1 = { speciesId = "FrasierFir", sizeId = "Small" }
		state.layout.placements.fir_2 = { speciesId = "NobleFir", sizeId = "Small" }
		local ok, sales = service:simulateCustomerVisits()
		expect.truthy(ok)
		expect.equal(sales, 2)
		expect.equal(state.sales, 2)
	end)

	-- Player actions never write to the DataStore directly; the flush batches them.
	t.test("batches player actions into one flush", function()
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
		expect.truthy(service:handle("personal:42", 42, order("batch_0001")).ok)
		-- The second order is unaffordable but still records its request ID.
		expect.falsy(service:handle("personal:42", 42, order("batch_0002")).ok)
		expect.equal(saves, 0)
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
	end)

	t.test("returns the original outcome for a retried request", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.truthy(service:handle("personal:42", 42, order("retry_0001")).ok)
		local replay = service:handle("personal:42", 42, order("retry_0001"))
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(replay.previousResult, "Success")
	end)

	t.test("caps total request volume per player across actions", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		local payloads = {
			["Company.GetSummary"] = {},
			["Supplier.RequestQuote"] = { speciesId = "FrasierFir", sizeId = "Medium" },
			["Pricing.SetAuto"] = { enabled = false },
			["Quest.Claim"] = { questId = "FirstSale" },
			["Employee.Hire"] = { employeeId = "Cashier" },
		}
		local actions =
			{ "Company.GetSummary", "Supplier.RequestQuote", "Pricing.SetAuto", "Quest.Claim", "Employee.Hire" }
		local limited = 0
		for index = 1, 50 do
			local action = actions[(index % #actions) + 1]
			local response = service:handle("personal:42", 42, {
				version = 1,
				requestId = string.format("flood_%04d", index),
				action = action,
				payload = payloads[action],
			})
			if response.errorCode == "RateLimited" then
				limited += 1
			end
		end
		-- Each action alone stays under its 10/10s limit; the 40/10s total cap applies.
		expect.equal(limited, 10)
	end)

	-- A runtime error must not leave the company busy forever or stall other companies.
	t.test("fails closed after an internal error without wedging the server", function()
		local saves = 0
		local persistence = fakePersistence()
		local originalSave = persistence.save
		persistence.save = function(self, companyId, state)
			saves += 1
			return originalSave(self, companyId, state)
		end
		local service = Service.new(persistence, function()
			return 100
		end, function()
			return 0
		end)
		local broken = service:loadPersonalCompany(42)
		local healthy = service:loadPersonalCompany(77)
		broken.staff = nil
		healthy.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		local ok, sales, failures = service:simulateCustomerVisits()
		expect.falsy(ok)
		expect.equal(sales, 1)
		expect.equal(failures, 1)
		expect.falsy(service:isAvailable("personal:42"))
		expect.truthy(service:isAvailable("personal:77"))
		expect.equal(service:handle("personal:42", 42, order("broken_001")).errorCode, "CompanyUnavailable")
		-- The possibly half-mutated record is never persisted.
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
		local unloaded, reason = service:unloadCompany("personal:42")
		expect.falsy(unloaded)
		expect.equal(reason, "InternalError")
		expect.equal(saves, 1)
	end)

	t.test("tolerates transient save failures until the fail-closed window", function()
		local clock = 100
		local persistence = fakePersistence()
		persistence.save = function()
			return false, "SaveFailed:Throttled"
		end
		local service = Service.new(persistence, function()
			return clock
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.truthy(service:handle("personal:42", 42, order("transient_1")).ok)
		expect.falsy(service:flushDirty())
		expect.truthy(service:isAvailable("personal:42"))
		expect.truthy(service:isDirty("personal:42"))
		clock += 90
		expect.falsy(service:flushDirty())
		expect.falsy(service:isAvailable("personal:42"))
	end)

	t.test("fails closed immediately when the session lock is lost", function()
		local persistence = fakePersistence()
		persistence.save = function()
			return false, "SessionLocked"
		end
		local service = Service.new(persistence, function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.falsy(service:autosaveAll())
		expect.falsy(service:isAvailable("personal:42"))
	end)

	t.test("refuses a second load while a session for the company exists", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		local state, reason = service:loadPersonalCompany(42)
		expect.equal(state, nil)
		expect.equal(reason, "SessionBusy")
	end)

	t.test("unload saves the final record once and releases the lock", function()
		local saves, releases = 0, 0
		local persistence = fakePersistence()
		local originalSave = persistence.save
		persistence.save = function(self, companyId, state)
			saves += 1
			return originalSave(self, companyId, state)
		end
		persistence.release = function()
			releases += 1
			return true, nil
		end
		local service = Service.new(persistence, function()
			return 100
		end)
		expect.truthy(service:loadPersonalCompany(42))
		expect.truthy(service:handle("personal:42", 42, order("unload_001")).ok)
		expect.truthy(service:unloadCompany("personal:42"))
		expect.truthy(service:unloadCompany("personal:42"))
		expect.equal(saves, 1)
		expect.equal(releases, 1)
		expect.falsy(service:isAvailable("personal:42"))
		expect.truthy(service:loadPersonalCompany(42))
	end)
end
