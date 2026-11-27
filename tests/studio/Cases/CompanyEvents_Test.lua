--!strict
-- CM2-45: Event.Buy through CompanyStateService:handle (server prices, replay, limit, window,
-- members, rate limit), the summary rows, the save across a reload and the test clock.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local EventConfig = require(Shared:WaitForChild("EventConfig"))
	local Service = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("CompanyStateService")
	)
	local expect = t.expect

	local COMPANY = "personal:42"
	local NOV_1 = AdventCalendar.utcTime(2026, 11, 1, 0)
	local NOV_29_NOON = 1795953600 -- 2026-11-29 12:00 UTC
	local DEC_6 = 1796515200 -- 2026-12-06 00:00 UTC
	local ADVENT1 = EventConfig.Events[1]
	local DECOR_IDS = { "CandleArch", "CandleLanternPost", "CandleWreathStand", "CandleMiniFir", "CandleStarSled" }

	local function deepCopy(value: any): any
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = deepCopy(inner)
		end
		return copy
	end

	-- Stores detached copies, so a reload reads only what was saved.
	local function fakePersistence()
		local records = {}
		return {
			load = function(_, companyId, ownerUserId)
				local stored = records[companyId]
				if stored == nil then
					return BusinessState.new(companyId, ownerUserId), nil
				end
				return BusinessState.migrate(deepCopy(stored), companyId, ownerUserId)
			end,
			save = function(_, companyId, state)
				records[companyId] = deepCopy(state)
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}
	end

	local function setup(at: number, cash: number)
		local clock = { now = at }
		local service = Service.new(fakePersistence(), function()
			return clock.now
		end, function()
			return 0.5
		end, function() end)
		local state = service:loadCompany(COMPANY, 42)
		state.cash = cash
		return service, state, clock
	end

	local sequence = 0
	local function buy(service, userId: number, payload, requestId: string?)
		sequence += 1
		return service:handle(COMPANY, userId, {
			version = 1,
			requestId = requestId or string.format("event_%04d", sequence),
			action = "Event.Buy",
			payload = payload,
		})
	end

	local function pack()
		return { eventId = "Advent1", itemKey = "CandlelightPack" }
	end

	local function summaryEvent(service, userId: number?)
		local response = service:handle(COMPANY, userId or 42, {
			version = 1,
			requestId = "summary_0001",
			action = "Company.GetSummary",
			payload = {},
		})
		expect.truthy(response.ok)
		return response.data.event
	end

	local function expectDecor(state, count: number)
		for _, id in ipairs(DECOR_IDS) do
			expect.equal(state.decorInventory[id], count)
		end
	end

	t.test("buys the event pack once with server prices", function()
		local service, state = setup(NOV_29_NOON, 5000)
		local spent = state.spent
		local response = buy(service, 42, pack())
		expect.truthy(response.ok)
		expect.equal(response.data.price, 2000)
		expect.equal(response.data.bought, 1)
		expect.equal(state.cash, 3000)
		expect.equal(state.spent, spent + 2000)
		local last = state.history[#state.history]
		expect.equal(last.kind, "EventPurchase")
		expect.equal(last.amount, -2000)
		expectDecor(state, 3)
		expect.equal(response.data.decor.CandleArch, 3)
		expect.equal(state.eventPurchases.Advent1.CandlelightPack, 1)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("replays a request ID without a second debit", function()
		local service, state = setup(NOV_29_NOON, 5000)
		expect.truthy(buy(service, 42, pack(), "event_replay_1").ok)
		local replay = buy(service, 42, pack(), "event_replay_1")
		expect.falsy(replay.ok)
		expect.equal(replay.errorCode, "DuplicateRequest")
		expect.equal(state.cash, 3000)
		expectDecor(state, 3)
	end)

	t.test("refuses a purchase over the limit", function()
		local service, state = setup(NOV_29_NOON, 5000)
		expect.truthy(buy(service, 42, pack()).ok)
		local again = buy(service, 42, pack())
		expect.falsy(again.ok)
		expect.equal(again.errorCode, "PurchaseLimit")
		expect.equal(state.cash, 3000)
		expectDecor(state, 3)
		expect.equal(state.eventPurchases.Advent1.CandlelightPack, 1)
	end)

	t.test("refuses outside the window and for another event", function()
		local service, state, clock = setup(ADVENT1.startsAt - 1, 5000)
		expect.equal(buy(service, 42, pack()).errorCode, "EventClosed")
		clock.now = ADVENT1.endsAt
		expect.equal(buy(service, 42, pack()).errorCode, "EventClosed")
		clock.now = NOV_29_NOON
		expect.equal(buy(service, 42, { eventId = "Advent2", itemKey = "CandlelightPack" }).errorCode, "EventClosed")
		expect.equal(state.cash, 5000)
		expect.equal(next(state.eventPurchases), nil)
		expect.equal(next(state.decorInventory), nil)
	end)

	t.test("refuses unknown items, Robux items and missing cash", function()
		local service, state = setup(NOV_29_NOON, 1999)
		expect.equal(
			buy(service, 42, { eventId = "Advent1", itemKey = "EventTreeCandlelight" }).errorCode,
			"InvalidItem"
		)
		expect.equal(buy(service, 42, { eventId = "Advent1", itemKey = "Nope" }).errorCode, "InvalidItem")
		expect.equal(buy(service, 42, pack()).errorCode, "InsufficientFunds")
		expect.equal(state.cash, 1999)
		expect.equal(next(state.eventPurchases), nil)
		expect.equal(next(state.decorInventory), nil)
	end)

	t.test("keeps the items after the event and a reload", function()
		local service, state, clock = setup(NOV_29_NOON, 5000)
		expect.truthy(buy(service, 42, pack()).ok)
		clock.now = DEC_6
		expectDecor(state, 3)
		expect.equal(state.eventPurchases.Advent1.CandlelightPack, 1)
		expect.equal(summaryEvent(service), nil)
		expect.truthy(service:unloadCompany(COMPANY))
		local reloaded = service:loadCompany(COMPANY, 42)
		expect.truthy(reloaded)
		expect.equal(reloaded.cash, 3000)
		expectDecor(reloaded, 3)
		expect.equal(reloaded.eventPurchases.Advent1.CandlelightPack, 1)
	end)

	t.test("summarizes the event for the client", function()
		local service = setup(NOV_29_NOON, 5000)
		local event = summaryEvent(service)
		expect.equal(event.id, "Advent1")
		expect.equal(event.titleKey, "eventTitleAdvent1")
		expect.equal(event.endsIn, 561600)
		expect.equal(#event.items, 4)
		local cashItem = event.items[1]
		expect.equal(cashItem.key, "CandlelightPack")
		expect.equal(cashItem.kind, "Cash")
		expect.equal(cashItem.price, 2000)
		expect.equal(cashItem.limit, 1)
		expect.equal(cashItem.bought, 0)
		for index, key in ipairs({ "EventTreeCandlelight", "EventTreeStarlight", "EventTreeSnowberry" }) do
			local row = event.items[index + 1]
			expect.equal(row.key, key)
			expect.equal(row.kind, "Robux")
			expect.equal(row.price, 199)
			expect.equal(row.ready, false)
		end
		expect.truthy(buy(service, 42, pack()).ok)
		expect.equal(summaryEvent(service).items[1].bought, 1)
	end)

	t.test("lets a member buy, refuses outsiders and floods", function()
		local service, state = setup(NOV_29_NOON, 5000)
		state.members["77"] = "Member"
		expect.truthy(buy(service, 77, pack()).ok)
		expect.equal(state.cash, 3000)
		expect.equal(buy(service, 99, pack()).errorCode, "Forbidden")
		for _ = 2, 10 do
			expect.equal(buy(service, 77, pack()).errorCode, "PurchaseLimit")
		end
		expect.equal(buy(service, 77, pack()).errorCode, "RateLimited")
		expect.equal(state.cash, 3000)
	end)

	t.test("moves only the event clock in tests", function()
		local service, state, clock = setup(NOV_1, 5000)
		expect.equal(buy(service, 42, pack()).errorCode, "EventClosed")
		service:setEventNowForTest(NOV_29_NOON)
		expect.truthy(buy(service, 42, pack()).ok)
		expect.equal(service:eventView().id, "Advent1")
		expect.equal(clock.now, NOV_1)
		service:setEventNowForTest(nil)
		expect.equal(service:eventView().id, "")
		local revision = state.revision
		expect.truthy(service:clearEventPurchasesForTest(COMPANY))
		expect.equal(next(state.eventPurchases), nil)
		expect.equal(state.revision, revision + 1)
		expectDecor(state, 3)
		expect.falsy(service:clearEventPurchasesForTest("personal:404"))
	end)
end
