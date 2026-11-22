--!strict
return function(t)
	local BusinessState = require(game:GetService("ReplicatedStorage").Shared.BusinessState)
	local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
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
		expect.truthy(service:loadCompany("personal:42", 42))
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
		expect.truthy(service:loadCompany("personal:42", 42))
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
		expect.truthy(service:loadCompany("personal:42", 42))
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
		local state = service:loadCompany("personal:42", 42)
		state.autoPricing = true
		state.layout.placements.fir_1 = { speciesId = "FrasierFir", sizeId = "Medium" }
		local ok, updated = service:applyAutoPricingAll()
		expect.truthy(ok)
		expect.equal(updated, 1)
		expect.equal(state.mediumPrices.FrasierFir, 155)
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
		local state = service:loadCompany("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		local ok, sales = service:simulateCustomerVisits()
		expect.truthy(ok)
		expect.equal(sales, 1)
		expect.equal(state.sales, 1)
		expect.equal(synced, 1)
		expect.truthy(service:flushDirty())
		expect.equal(saves, 1)
	end)

	t.test("deliveries land in their bay through the save boundary", function()
		local persistence = fakePersistence()
		local service = Service.new(persistence, function()
			return 160
		end)
		local synced = {}
		service:setReceivingChangedHandler(function(companyId, bays)
			table.insert(synced, { companyId = companyId, bays = bays })
		end)
		local state = service:loadCompany("personal:42", 42)
		expect.truthy(BusinessState.placeOrder(state, "worker_999", "FrasierFir", "Medium", 1, 100))
		local ok, delivered = service:reconcileDeliveriesAll()
		expect.truthy(ok)
		expect.equal(delivered, 1)
		expect.equal(state.pendingOrders["order:worker_999"], nil)
		expect.equal(state.bays[1].counts.Medium, 1)
		expect.truthy(service:isDirty("personal:42"))
		expect.equal(#synced, 1)
		expect.equal(synced[1].companyId, "personal:42")
		expect.equal(synced[1].bays[1].counts.Medium, 1)
		expect.equal(synced[1].bays[1].arrivesIn, -1)
		-- Without open orders the pass skips the company.
		local _, again = service:reconcileDeliveriesAll()
		expect.equal(again, 0)
		expect.equal(#synced, 1)
	end)

	local function stockPlace(requestId: string, x: number, z: number, count: number)
		return {
			version = 1,
			requestId = requestId,
			action = "Stock.Place",
			payload = {
				bay = 1,
				speciesId = "DouglasFir",
				sizeId = "Medium",
				x = x,
				z = z,
				rotation = 0,
				count = count,
				gap = 0.5,
			},
		}
	end

	-- OBSERVED: stocking needs empty hands.
	t.test("Stock actions refuse a player carrying a tree", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		local state = service:loadCompany("personal:42", 42)
		state.bays[1] = { speciesId = "DouglasFir", counts = { Medium = 2 } }
		state.customerOrders["1"] = {
			orderNumber = 1,
			speciesId = "DouglasFir",
			sizeId = "Medium",
			heightTenths = 75,
			salePrice = 70,
			soldAt = 100,
			expiresAt = 220,
			parkingSpace = 1,
			carriedBy = 42,
			queueSeconds = 0,
		}
		state.nextOrderNumber = 2
		expect.truthy(BusinessState.validate(state))
		local response = service:handle("personal:42", 42, stockPlace("hands_full_1", -35, -13, 1))
		expect.falsy(response.ok)
		expect.equal(response.errorCode, "HandsFull")
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(next(state.layout.placements), nil)
	end)

	t.test("a replayed row fill places nothing twice", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		local state = service:loadCompany("personal:42", 42)
		state.bays[1] = { speciesId = "DouglasFir", counts = { Medium = 9 } }
		local first = service:handle("personal:42", 42, stockPlace("row_fill_01", -35, -20, 5))
		expect.truthy(first.ok)
		expect.equal(#first.data.placementIds, 5)
		local replay = service:handle("personal:42", 42, stockPlace("row_fill_01", -35, -20, 5))
		expect.falsy(replay.ok)
		expect.equal(replay.errorCode, "DuplicateRequest")
		local placements = 0
		for _ in pairs(state.layout.placements) do
			placements += 1
		end
		expect.equal(placements, 5)
		expect.equal(state.bays[1].counts.Medium, 4)
	end)

	t.test("cashier raises customer processing capacity", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
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
		expect.truthy(service:loadCompany("personal:42", 42))
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
		expect.truthy(service:loadCompany("personal:42", 42))
		expect.truthy(service:handle("personal:42", 42, order("retry_0001")).ok)
		local replay = service:handle("personal:42", 42, order("retry_0001"))
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(replay.previousResult, "Success")
	end)

	t.test("caps total request volume per player across actions", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadCompany("personal:42", 42))
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
		local broken = service:loadCompany("personal:42", 42)
		local healthy = service:loadCompany("personal:77", 77)
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
		expect.truthy(service:loadCompany("personal:42", 42))
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
		expect.truthy(service:loadCompany("personal:42", 42))
		expect.falsy(service:autosaveAll())
		expect.falsy(service:isAvailable("personal:42"))
	end)

	t.test("refuses a second load while a session for the company exists", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		expect.truthy(service:loadCompany("personal:42", 42))
		local state, reason = service:loadCompany("personal:42", 42)
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
		expect.truthy(service:loadCompany("personal:42", 42))
		expect.truthy(service:handle("personal:42", 42, order("unload_001")).ok)
		expect.truthy(service:unloadCompany("personal:42"))
		expect.truthy(service:unloadCompany("personal:42"))
		expect.equal(saves, 1)
		expect.equal(releases, 1)
		expect.falsy(service:isAvailable("personal:42"))
		expect.truthy(service:loadCompany("personal:42", 42))
	end)

	-- CM2-R3: a live session that stops accepting mutations is reported once with a code.
	local function failureRecorder(service)
		local calls = {}
		service:setSessionFailedHandler(function(companyId, code)
			table.insert(calls, { companyId = companyId, code = code })
		end)
		return calls
	end

	t.test("reports a lost lock once through the failure handler", function()
		local persistence = fakePersistence()
		persistence.save = function()
			return false, "SessionLocked"
		end
		local service = Service.new(persistence, function()
			return 100
		end)
		local calls = failureRecorder(service)
		expect.truthy(service:loadCompany("personal:42", 42))
		expect.falsy(service:flushDirty(true))
		service:flushDirty(true)
		expect.equal(#calls, 1)
		expect.equal(calls[1].companyId, "personal:42")
		expect.equal(calls[1].code, "SessionLocked")
		expect.falsy(service:isAvailable("personal:42"))
	end)

	t.test("reports an internal error through the failure handler", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local calls = failureRecorder(service)
		local broken = service:loadCompany("personal:42", 42)
		broken.staff = nil
		service:simulateCustomerVisits()
		service:simulateCustomerVisits()
		expect.equal(#calls, 1)
		expect.equal(calls[1].code, "InternalError")
		-- Unloading never reports again.
		service:unloadCompany("personal:42")
		expect.equal(#calls, 1)
	end)

	t.test("reports a save outage after the fail-closed window", function()
		local clock = 100
		local persistence = fakePersistence()
		persistence.save = function()
			return false, "SaveFailed:Throttled"
		end
		local service = Service.new(persistence, function()
			return clock
		end)
		local calls = failureRecorder(service)
		expect.truthy(service:loadCompany("personal:42", 42))
		expect.falsy(service:flushDirty(true))
		clock += GameConfig.SaveFailClosedSeconds - 1
		expect.falsy(service:flushDirty())
		expect.equal(#calls, 0)
		expect.truthy(service:isAvailable("personal:42"))
		clock += 1
		expect.falsy(service:flushDirty())
		expect.equal(#calls, 1)
		expect.equal(calls[1].code, "SaveFailed")
		expect.falsy(service:isAvailable("personal:42"))
	end)

	-- CM2-S2: co-op saves. The fake stores a deep copy on every save, like a DataStore.
	local function deepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = deepCopy(inner)
		end
		return copy
	end

	local function copyingPersistence()
		local persistence: any = { records = {}, saves = 0, failSaves = false }
		function persistence.load(_, companyId, ownerUserId)
			local stored = persistence.records[companyId] or BusinessState.new(companyId, ownerUserId)
			return deepCopy(stored), nil
		end
		function persistence.save(_, companyId, state)
			persistence.saves += 1
			if persistence.failSaves then
				return false, "SaveFailed:Throttled"
			end
			persistence.records[companyId] = deepCopy(state)
			return true, nil
		end
		function persistence.release()
			return true, nil
		end
		return persistence
	end

	local SHARED = "save:42_" .. string.rep("0c", 8)
	local BIG_MEMBER = 9223372036854774784

	local function sharedService(persistence, cash: number?)
		local service = Service.new(persistence, function()
			return 100
		end)
		local state = service:loadCompany(SHARED, 42)
		state.saveSize = "Quad"
		state.members["43"] = "Member"
		state.members["9223372036854774784"] = "Member"
		state.cash = cash or 10000
		return service, state
	end

	local function act(service, userId: number, requestId: string, action: string, payload)
		return service:handle(SHARED, userId, {
			version = 1,
			requestId = requestId,
			action = action,
			payload = payload,
		})
	end

	t.test("members of a shared save may do every gameplay action", function()
		local PricingService = require(
			game:GetService("ServerScriptService")
				:WaitForChild("Server")
				:WaitForChild("Services")
				:WaitForChild("PricingService")
		)
		local service = sharedService(copyingPersistence())
		expect.truthy(act(service, 43, "member_order_1", "Supplier.PlaceOrder", {
			speciesId = "FrasierFir",
			sizeId = "Medium",
			quantity = 2,
		}).ok)
		local minimum = PricingService.bounds("FrasierFir")
		expect.truthy(act(service, 43, "member_price_1", "Pricing.SetMediumPrice", {
			speciesId = "FrasierFir",
			mediumPrice = minimum,
		}).ok)
		expect.truthy(act(service, 43, "member_hire_1", "Employee.Hire", { employeeId = "Cashier" }).ok)
		expect.truthy(act(service, 43, "member_summary_1", "Company.GetSummary", {}).ok)
		local stranger = act(service, 44, "stranger_order_1", "Supplier.PlaceOrder", {
			speciesId = "FrasierFir",
			sizeId = "Medium",
			quantity = 1,
		})
		expect.falsy(stranger.ok)
		expect.equal(stranger.errorCode, "Forbidden")
		local strangerQuery = act(service, 44, "stranger_summary_1", "Company.GetSummary", {})
		expect.equal(strangerQuery.errorCode, "Forbidden")
		expect.truthy(act(service, BIG_MEMBER, "big_hire_1", "Employee.Hire", { employeeId = "LotWorker" }).ok)
		expect.equal(service:memberRole(SHARED, 43), "Member")
		expect.equal(service:memberRole(SHARED, 42), "Owner")
		expect.equal(service:memberRole(SHARED, BIG_MEMBER), "Member")
		expect.equal(service:memberRole(SHARED, 44), nil)
	end)

	-- CM2-G7: the Pricing tab reads the server-derived pricing table from the summary.
	t.test("the company summary carries the pricing table", function()
		local service = sharedService(copyingPersistence())
		local response = act(service, 43, "member_pricing_summary_1", "Company.GetSummary", {})
		expect.truthy(response.ok)
		local pricing = response.data.pricing
		expect.equal(#pricing.species, 4)
		expect.equal(pricing.species[1].speciesId, "DouglasFir")
		expect.equal(pricing.species[1].mediumPrice, 140)
		expect.equal(pricing.species[1].sentiment, "Fair")
		expect.equal(pricing.automatic, false)
	end)

	t.test("a manual price and the auto flag survive a save and reload", function()
		local persistence = copyingPersistence()
		local service = sharedService(persistence)
		expect.truthy(act(service, 43, "member_price_reload_1", "Pricing.SetMediumPrice", {
			speciesId = "FrasierFir",
			mediumPrice = 150,
		}).ok)
		expect.truthy(act(service, 43, "member_auto_reload_1", "Pricing.SetAuto", { enabled = true }).ok)
		expect.truthy(service:unloadCompany(SHARED))
		local reloaded = Service.new(persistence, function()
			return 100
		end)
		local state = reloaded:loadCompany(SHARED, 42)
		expect.truthy(state)
		expect.equal(state.mediumPrices.FrasierFir, 150)
		expect.equal(state.autoPricing, true)
	end)

	t.test("two members never double-spend the shared cash", function()
		local persistence = copyingPersistence()
		local cost = 64 -- FrasierFir Medium x2 at the server wholesale price
		local service, state = sharedService(persistence, cost + 1)
		local payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2 }
		local first = act(service, 42, "shared_order_a", "Supplier.PlaceOrder", payload)
		expect.truthy(first.ok)
		expect.equal(first.data.cost, cost)
		local second = act(service, 43, "shared_order_b", "Supplier.PlaceOrder", payload)
		expect.falsy(second.ok)
		expect.equal(second.errorCode, "InsufficientFunds")
		local replay = act(service, 43, "shared_order_a", "Supplier.PlaceOrder", payload)
		expect.falsy(replay.ok)
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(state.cash, 1)
		expect.equal(state.spent, cost)
		expect.truthy(service:flushDirty())
		local stored = persistence.records[SHARED]
		local pending = 0
		for _ in pairs(stored.pendingOrders) do
			pending += 1
		end
		expect.equal(pending, 1)
		expect.equal(stored.cash, 1)
		expect.equal(stored.spent, cost)
	end)

	t.test("changeTeam saves at once and stays dirty when the save fails", function()
		local persistence = copyingPersistence()
		local service = Service.new(persistence, function()
			return 100
		end)
		local state = service:loadCompany(SHARED, 42)
		state.saveSize = "Duo"
		state.inviteCode = "12345"
		local ok, reason, result, saved = service:changeTeam(SHARED, function(live)
			return BusinessState.addMember(live, 43, "12345")
		end, true)
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(result.outcome, "Joined")
		expect.truthy(saved)
		expect.equal(persistence.saves, 1)
		expect.equal(persistence.records[SHARED].members["43"], "Member")
		expect.falsy(service:isDirty(SHARED))
		expect.equal(state.revision, 0)

		local refused, refusedReason, _, refusedSaved = service:changeTeam(SHARED, function(live)
			return BusinessState.addMember(live, 44, "12345")
		end, true)
		expect.falsy(refused)
		expect.equal(refusedReason, "SaveFull")
		expect.falsy(refusedSaved)
		expect.equal(persistence.saves, 1)

		persistence.failSaves = true
		local kept, keptReason, _, keptSaved = service:changeTeam(SHARED, function(live)
			return BusinessState.removeMember(live, 43)
		end, true)
		expect.truthy(kept)
		expect.equal(keptReason, nil)
		expect.falsy(keptSaved)
		expect.equal(persistence.saves, 2)
		expect.truthy(service:isDirty(SHARED))
		expect.truthy(service:isAvailable(SHARED))
		expect.equal(state.members["43"], nil)

		local team = service:teamInfo(SHARED)
		expect.equal(team.ownerUserId, 42)
		expect.equal(team.saveSize, "Duo")
		expect.equal(team.inviteCode, "12345")
		team.members["99"] = "Member"
		expect.equal(state.members["99"], nil)
		expect.truthy(service:hasSession(SHARED))
		expect.falsy(service:isFailed(SHARED))
		local missing, missingReason = service:changeTeam("save:none", function()
			return true
		end, true)
		expect.falsy(missing)
		expect.equal(missingReason, "CompanyUnavailable")
	end)

	-- CM2-R5: final-save retries. save logs every call and fails while failures > 0;
	-- release logs every call. The injected wait records its values, then runs env.onWait.
	local RETRY_ID = "save:42_" .. string.rep("0d", 8)

	local function retryPersistence()
		local persistence: any = { records = {}, log = {}, failures = 0 }
		function persistence.load(_, companyId, ownerUserId)
			local stored = persistence.records[companyId]
			if stored then
				return deepCopy(stored), nil
			end
			return BusinessState.new(companyId, ownerUserId), nil
		end
		function persistence.save(_, companyId, state)
			table.insert(persistence.log, "save")
			if persistence.failures > 0 then
				persistence.failures -= 1
				return false, "SaveFailed:Throttled"
			end
			persistence.records[companyId] = deepCopy(state)
			return true, nil
		end
		function persistence.release()
			table.insert(persistence.log, "release")
			return true, nil
		end
		return persistence
	end

	local function retrySetup()
		local env: any = { now = 100, waits = {}, onWait = nil }
		env.persistence = retryPersistence()
		env.service = Service.new(
			env.persistence,
			function()
				return env.now
			end,
			nil,
			function(seconds: number)
				table.insert(env.waits, seconds)
				if env.onWait then
					env.onWait(seconds)
				end
			end
		)
		env.state = env.service:loadCompany(RETRY_ID, 42)
		expect.truthy(env.state)
		return env
	end

	local function countOf(list, value): number
		local found = 0
		for _, item in ipairs(list) do
			if item == value then
				found += 1
			end
		end
		return found
	end

	local function keyCount(map): number
		local found = 0
		for _ in pairs(map) do
			found += 1
		end
		return found
	end

	t.test("a final save that fails twice is retried and releases once after success", function()
		local env = retrySetup()
		expect.truthy(env.service:handle(RETRY_ID, 42, order("retry_a_1")).ok)
		local cash, revision, pending = env.state.cash, env.state.revision, keyCount(env.state.pendingOrders)
		expect.equal(pending, 1)
		env.persistence.failures = 2
		local retries = {}
		local ok, reason = env.service:unloadCompany(RETRY_ID, {
			onRetry = function(attempt: number)
				table.insert(retries, attempt)
			end,
		})
		expect.truthy(ok)
		expect.equal(reason, nil)
		expect.equal(table.concat(env.persistence.log, ","), "save,save,save,release")
		expect.equal(table.concat(env.waits, ","), "2,4")
		expect.equal(table.concat(retries, ","), "1,2")
		local stored = env.persistence.records[RETRY_ID]
		expect.equal(stored.cash, cash)
		expect.equal(stored.revision, revision)
		expect.equal(keyCount(stored.pendingOrders), pending)
	end)

	t.test("a final save that always fails keeps the lock and gives up", function()
		local env = retrySetup()
		env.persistence.failures = math.huge
		local ok, reason = env.service:unloadCompany(RETRY_ID)
		expect.falsy(ok)
		expect.equal(reason, "SaveFailed")
		expect.equal(countOf(env.persistence.log, "save"), 8)
		expect.equal(countOf(env.persistence.log, "release"), 0)
		expect.equal(table.concat(env.waits, ","), "2,4,8,16,16,16,16")
		expect.falsy(env.service:hasSession(RETRY_ID))
	end)

	t.test("a lost lock ends the final save at once", function()
		local env = retrySetup()
		env.persistence.save = function()
			table.insert(env.persistence.log, "save")
			return false, "SessionLocked"
		end
		local ok, reason = env.service:unloadCompany(RETRY_ID)
		expect.falsy(ok)
		expect.equal(reason, "SessionLocked")
		expect.equal(countOf(env.persistence.log, "save"), 1)
		expect.equal(#env.waits, 0)
		expect.equal(countOf(env.persistence.log, "release"), 1)
	end)

	t.test("a shutdown caps the final save retries", function()
		local env = retrySetup()
		env.onWait = function(seconds: number)
			env.now += seconds
		end
		expect.equal(env.now, 100)
		env.service:beginShutdown()
		env.persistence.failures = math.huge
		local ok, reason = env.service:unloadCompany(RETRY_ID)
		expect.falsy(ok)
		expect.equal(reason, "SaveFailed")
		expect.equal(table.concat(env.waits, ","), "2,4,8,4")
		expect.equal(countOf(env.persistence.log, "save"), 5)
		expect.equal(countOf(env.persistence.log, "release"), 0)
	end)

	t.test("a retrying unload refuses loads and counts as unloading", function()
		local env = retrySetup()
		env.onWait = function()
			coroutine.yield()
		end
		expect.truthy(env.service:handle(RETRY_ID, 42, order("retry_c_1")).ok)
		local cash = env.state.cash
		env.persistence.failures = 1
		local unload = coroutine.create(function()
			return env.service:unloadCompany(RETRY_ID)
		end)
		expect.truthy(coroutine.resume(unload))
		expect.equal(coroutine.status(unload), "suspended")
		local state, reason = env.service:loadCompany(RETRY_ID, 42)
		expect.equal(state, nil)
		expect.equal(reason, "SessionBusy")
		expect.equal(env.service:unloadingCount(), 1)
		expect.falsy(env.service:isAvailable(RETRY_ID))
		expect.equal(env.service:handle(RETRY_ID, 42, order("retry_c_2")).errorCode, "CompanyUnavailable")
		local result = nil
		while coroutine.status(unload) ~= "dead" do
			result = table.pack(coroutine.resume(unload))
		end
		expect.truthy(result)
		expect.truthy(result[1])
		expect.truthy(result[2])
		expect.equal(env.service:unloadingCount(), 0)
		local reloaded = env.service:loadCompany(RETRY_ID, 42)
		expect.truthy(reloaded)
		expect.equal(reloaded.cash, cash)
	end)

	t.test("abortOnFailure keeps a healthy session live", function()
		local env = retrySetup()
		expect.truthy(env.service:handle(RETRY_ID, 42, order("retry_abort_1")).ok)
		env.persistence.failures = 1
		local ok, reason = env.service:unloadCompany(RETRY_ID, { abortOnFailure = true })
		expect.falsy(ok)
		expect.equal(reason, "UnloadAborted")
		expect.truthy(env.service:isAvailable(RETRY_ID))
		expect.truthy(env.service:isDirty(RETRY_ID))
		expect.equal(env.service:unloadingCount(), 0)
		expect.equal(countOf(env.persistence.log, "release"), 0)
		expect.equal(#env.waits, 0)
		expect.truthy(env.service:flushDirty())
		expect.truthy(env.service:unloadCompany(RETRY_ID))
		expect.equal(countOf(env.persistence.log, "release"), 1)
	end)

	t.test("abortOnFailure waits for a failed session and during shutdown", function()
		-- (i) A session that already failed closed is not called off.
		local env = retrySetup()
		env.persistence.failures = 1
		env.now += GameConfig.SaveFailClosedSeconds
		expect.falsy(env.service:flushDirty())
		expect.truthy(env.service:isFailed(RETRY_ID))
		env.persistence.failures = 1
		expect.truthy(env.service:unloadCompany(RETRY_ID, { abortOnFailure = true }))
		expect.equal(table.concat(env.waits, ","), "2")
		expect.equal(countOf(env.persistence.log, "release"), 1)

		-- (ii) Once shutdown began, a switch no longer calls the unload off.
		local closing = retrySetup()
		closing.service:beginShutdown()
		closing.persistence.failures = 1
		expect.truthy(closing.service:unloadCompany(RETRY_ID, { abortOnFailure = true }))
		expect.equal(countOf(closing.persistence.log, "release"), 1)
	end)

	t.test("a second unload caller gets the result after the lock release", function()
		local env = retrySetup()
		env.onWait = function()
			coroutine.yield()
		end
		env.persistence.release = function()
			table.insert(env.persistence.log, "release")
			coroutine.yield()
			return true
		end
		env.persistence.failures = 1
		local first = coroutine.create(function()
			return env.service:unloadCompany(RETRY_ID)
		end)
		local second = coroutine.create(function()
			return env.service:unloadCompany(RETRY_ID)
		end)
		expect.truthy(coroutine.resume(first))
		expect.equal(coroutine.status(first), "suspended")
		expect.equal(table.concat(env.waits, ","), "2")
		expect.truthy(coroutine.resume(second))
		expect.equal(coroutine.status(second), "suspended")
		expect.equal(#env.waits, 2)
		expect.equal(env.waits[1], 2)
		expect.equal(env.waits[2], 0.1)
		-- The first caller is suspended inside the lock release.
		expect.truthy(coroutine.resume(first))
		expect.equal(coroutine.status(first), "suspended")
		expect.falsy(env.service:hasSession(RETRY_ID))
		expect.equal(table.concat(env.persistence.log, ","), "save,save,release")
		-- The second caller does not wake before the first one stored its results.
		expect.truthy(coroutine.resume(second))
		expect.equal(coroutine.status(second), "suspended")
		local firstResult = table.pack(coroutine.resume(first))
		expect.equal(coroutine.status(first), "dead")
		expect.truthy(firstResult[1])
		expect.equal(firstResult[2], true)
		expect.equal(firstResult[3], nil)
		local secondResult = table.pack(coroutine.resume(second))
		expect.equal(coroutine.status(second), "dead")
		expect.truthy(secondResult[1])
		expect.equal(secondResult[2], true)
		expect.equal(secondResult[3], nil)
		expect.equal(countOf(env.persistence.log, "release"), 1)
	end)

	-- CM2-G15: a like changes the liked save once per UTC day and never through handle().
	t.test("likeLot changes the liked save once per day", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		local state = service:loadCompany("personal:42", 42)
		local revision = state.revision
		expect.falsy(service:isDirty("personal:42"))
		local liked = service:likeLot("personal:42", 77)
		expect.truthy(liked.ok)
		expect.equal(liked.data.likes, 1)
		expect.equal(liked.revision, revision + 1)
		expect.equal(state.revision, revision + 1)
		expect.truthy(service:isDirty("personal:42"))
		local again = service:likeLot("personal:42", 77)
		expect.falsy(again.ok)
		expect.equal(again.errorCode, "AlreadyLikedToday")
		expect.equal(again.revision, revision + 1)
		expect.equal(state.likes.total, 1)
		local viaHandle = service:handle(
			"personal:42",
			42,
			{ version = 1, requestId = "like_000001", action = "Lot.Like", payload = { plotId = "Plot_01" } }
		)
		expect.equal(viaHandle.errorCode, "Forbidden")
		expect.equal(state.likes.total, 1)
		for _ = 1, GameConfig.Reviews.LikeLimit.limit do
			expect.truthy(service:allowLike(88))
		end
		expect.falsy(service:allowLike(88))
	end)

	t.test("loading notifies one review", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end, function()
			return 0
		end)
		local notified = {}
		service:setReviewsHandler(function(companyId, reviews)
			table.insert(notified, { companyId = companyId, reviews = reviews })
		end)
		local state = service:loadCompany("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		service:simulateCustomerVisits()
		local function request(id: string, action: string, payload)
			return { version = 1, requestId = id, action = action, payload = payload }
		end
		expect.truthy(service:handle("personal:42", 42, request("carry_0001", "Order.Carry", { orderNumber = 1 })).ok)
		expect.equal(#notified, 0)
		local load =
			service:handle("personal:42", 42, request("load_00001", "Order.Load", { orderNumber = 1, carNumber = 1 }))
		expect.truthy(load.ok)
		expect.equal(#notified, 1)
		expect.equal(notified[1].companyId, "personal:42")
		expect.equal(#notified[1].reviews, 1)
		expect.equal(notified[1].reviews[1].stars, 5)
		expect.equal(notified[1].reviews[1].textKey, "reviewGreat")
	end)
end
