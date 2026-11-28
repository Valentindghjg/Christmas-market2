--!strict
-- Playtest step 72 (full mode): the event shop (CM2-45, docs/plans/CM2-45.md). Installed by
-- RunPlaytest.execute after Steps/Advent. Drives the real player R through Event.Buy with the
-- event clock set by `eventNow` (the business clock is untouched) and the save's purchases
-- cleared by `eventReset`; price, limit and decor come from EventConfig on the server.
-- Step details:
-- Customers stay paused after the step: 02 pauses them for the run, 23 CLEANUP unpauses them (CM2-LEAK22).
-- CM2-45: `72 EVENT_SHOP` (needs 03): (1) customers paused, purchases cleared, Nov 28 12:00 UTC:
-- `EventId` "", `EventEndsIn` 0, summary `event` nil, Event.Buy `EventClosed` with cash
-- unchanged. (2) Nov 29 12:00: `EventId` "Advent1", `EventEndsIn` 561600; the summary has 4
-- items, CandlelightPack $2000 bought 0 and 3 Robux items not ready. (3) cash 1999:
-- `InsufficientFunds`; cash 5000: bought, cash 3000, each decor +3; the same request ID is
-- `DuplicateRequest`, a new one `PurchaseLimit`, cash 3000. (4) a Robux item is `InvalidItem`,
-- an extra `price` field `UnexpectedField`. (5) after `flush` and `rejoin` cash, decor and the
-- purchase count are equal. (6) Dec 6: `EventId` "", summary `event` nil, `EventClosed`, decor
-- unchanged. The event clock override is always cleared afterwards.
return function(ctx: any)
	local HttpService = ctx.HttpService
	local R = ctx.R
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local call = ctx.call
	local check = ctx.check
	local rejoin = ctx.rejoin
	local snap = ctx.snap

	-- 2026-11-28 12:00, 2026-11-29 12:00 and 2026-12-06 00:00 UTC.
	local NOV_28_NOON = 1795867200
	local NOV_29_NOON = 1795953600
	local DEC_6 = 1796515200
	local DECOR_IDS = { "CandleArch", "CandleLanternPost", "CandleWreathStand", "CandleMiniFir", "CandleStarSled" }
	local ROBUX_KEYS = { "EventTreeCandlelight", "EventTreeStarlight", "EventTreeSnowberry" }

	local function codeOf(response: any): string
		return tostring(type(response) == "table" and response.errorCode or response)
	end

	local function newId(): string
		return "e45_" .. HttpService:GenerateGUID(false)
	end

	local function buy(payload: any, requestId: string?): any
		return act(R.userId, "Event.Buy", payload, requestId or newId())
	end

	local function pack(): any
		return { eventId = "Advent1", itemKey = "CandlelightPack" }
	end

	local function refused(response: any, expected: string, label: string)
		local code = codeOf(response)
		check(code == expected, string.format("%s returned %s, expected %s", label, code, expected))
	end

	local function eventNow(at: number)
		check(call("eventNow", { at = at }) == true, "eventNow did not apply")
	end

	local function expectAttributes(id: string, endsIn: number)
		local storage = game:GetService("ReplicatedStorage")
		local gotId, gotEndsIn = storage:GetAttribute("EventId"), storage:GetAttribute("EventEndsIn")
		check(
			gotId == id and gotEndsIn == endsIn,
			string.format("Event attributes %s/%s, expected %s/%d", tostring(gotId), tostring(gotEndsIn), id, endsIn)
		)
	end

	local function summaryEvent(): any
		return actOk(R.userId, "Company.GetSummary", {}).event
	end

	local function cash(): number
		return snap(R.userId).cash
	end

	local function decorCounts(): { [string]: number }
		local inventory = snap(R.userId).decorInventory
		local counts = {}
		for _, id in DECOR_IDS do
			counts[id] = if type(inventory) == "table" then inventory[id] or 0 else 0
		end
		return counts
	end

	local function expectDecor(expected: { [string]: number }, label: string)
		local counts = decorCounts()
		for _, id in DECOR_IDS do
			check(
				counts[id] == expected[id],
				string.format("%s: %s %d, expected %d", label, id, counts[id], expected[id])
			)
		end
	end

	local function body(): string
		-- (1) before the event: nothing open, nothing sold.
		call("pauseCustomers", true)
		check(call("eventReset", { userId = R.userId }) == true, "eventReset did not write")
		eventNow(NOV_28_NOON)
		expectAttributes("", 0)
		check(summaryEvent() == nil, "summary shows an event on Nov 28")
		local before = cash()
		refused(buy(pack()), "EventClosed", "buy on Nov 28")
		check(cash() == before, "cash moved on a closed event")

		-- (2) the 1st Advent is open with its rows.
		eventNow(NOV_29_NOON)
		expectAttributes("Advent1", 561600)
		local event = summaryEvent()
		check(type(event) == "table" and type(event.items) == "table", "summary has no event on Nov 29")
		check(#event.items == 4, string.format("summary has %d items, expected 4", #event.items))
		local first = event.items[1]
		check(
			first.key == "CandlelightPack" and first.kind == "Cash" and first.price == 2000 and first.bought == 0,
			string.format(
				"first row %s %s %s bought %s",
				tostring(first.key),
				tostring(first.kind),
				tostring(first.price),
				tostring(first.bought)
			)
		)
		for index, key in ROBUX_KEYS do
			local row = event.items[index + 1]
			check(
				row.key == key and row.kind == "Robux" and row.ready == false,
				string.format("Robux row %d is %s ready %s", index, tostring(row.key), tostring(row.ready))
			)
		end

		-- (3) the pack costs $2000 once per save.
		call("setProgression", { userId = R.userId, cash = 1999 })
		refused(buy(pack()), "InsufficientFunds", "buy with $1999")
		check(cash() == 1999, "cash moved without enough cash")
		call("setProgression", { userId = R.userId, cash = 5000 })
		local decorBefore = decorCounts()
		local requestId = newId()
		local bought = buy(pack(), requestId)
		check(type(bought) == "table" and bought.ok == true, "pack purchase failed: " .. codeOf(bought))
		check(cash() == 3000, string.format("cash %d after the pack, expected 3000", cash()))
		local decorAfter = {}
		for _, id in DECOR_IDS do
			decorAfter[id] = decorBefore[id] + 3
		end
		expectDecor(decorAfter, "after the pack")
		refused(buy(pack(), requestId), "DuplicateRequest", "replayed buy")
		refused(buy(pack()), "PurchaseLimit", "second buy")
		check(cash() == 3000, string.format("cash %d after the refusals, expected 3000", cash()))

		-- (4) Robux items and forged fields never pass.
		refused(buy({ eventId = "Advent1", itemKey = "EventTreeCandlelight" }), "InvalidItem", "Robux item buy")
		refused(
			buy({ eventId = "Advent1", itemKey = "CandlelightPack", price = 1 }),
			"UnexpectedField",
			"buy with a price"
		)

		-- (5) the purchase survives a rejoin.
		call("flush", nil)
		rejoin(R.userId)
		check(cash() == 3000, string.format("cash %d after rejoin, expected 3000", cash()))
		expectDecor(decorAfter, "after rejoin")
		local purchases = snap(R.userId).eventPurchases
		local count = type(purchases) == "table"
			and type(purchases.Advent1) == "table"
			and purchases.Advent1.CandlelightPack
		check(count == 1, string.format("CandlelightPack count %s after rejoin, expected 1", tostring(count)))

		-- (6) after the event: closed, the decor stays.
		eventNow(DEC_6)
		expectAttributes("", 0)
		check(summaryEvent() == nil, "summary shows an event on Dec 6")
		refused(buy(pack()), "EventClosed", "buy on Dec 6")
		expectDecor(decorAfter, "after the event")
		return "Nov 28 closed, Nov 29 open 4 rows, $1999 refused, pack -$2000 +5x3 decor once, "
			.. "Robux and price refused, kept after rejoin, closed on Dec 6"
	end

	addStep("72", "EVENT_SHOP", { "03" }, function()
		local ok, result = pcall(body)
		pcall(call, "eventNow", { clear = true })
		if not ok then
			error(result, 0)
		end
		return result
	end)
end
