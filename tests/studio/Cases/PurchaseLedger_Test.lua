--!strict
-- CM2-46a: the player purchase ledger (bind before grant, finish once, passes counted once).
return function(t)
	local PurchaseLedgerService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PurchaseLedgerService")
	)
	local expect = t.expect

	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local MAX_USER_ID = 9223372036854774784
	local USER = 42
	local SAVE_A = "42_" .. string.rep("0a", 8)
	local SAVE_B = "42_" .. string.rep("0b", 8)

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

	-- Deep-copies on read and write like a real DataStore; counts writes.
	local function fakeStore()
		local store: any = { records = {}, writes = 0, failCount = 0 }
		function store.UpdateAsync(_, key: string, transform)
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit")
			end
			if store.failCount > 0 then
				store.failCount -= 1
				error("Throttled")
			end
			local nextValue = transform(deepCopy(store.records[key]))
			if nextValue ~= nil then
				store.records[key] = deepCopy(nextValue)
				store.writes += 1
			end
			return deepCopy(store.records[key])
		end
		return store
	end

	local function noWait() end

	local function entry(purchaseId: string, saveId: string)
		return { purchaseId = purchaseId, productKey = "CashPinecone", saveId = saveId, robux = 29, at = 100 }
	end

	t.test("binds and finishes a purchase once", function()
		local store = fakeStore()
		local ledger = PurchaseLedgerService.new(store, noWait)
		expect.equal(ledger:bind(USER, entry("p1", SAVE_A)), "Bound")
		expect.equal(ledger:bind(USER, entry("p1", SAVE_A)), "Bound")
		local first = ledger:finish(USER, entry("p1", SAVE_A), false)
		local second = ledger:finish(USER, entry("p1", SAVE_A), false)
		expect.truthy(first)
		expect.truthy(second)
		expect.equal(second.robuxSpent, 29)
		expect.equal(#second.done, 1)
		expect.equal(second.done[1].purchaseId, "p1")
		expect.equal(second.pending.p1, nil)
		local stored = store.records[PurchaseLedgerService.keyFor(USER)]
		expect.equal(stored.robuxSpent, 29)
		expect.equal(#stored.done, 1)
	end)

	t.test("reports a finished purchase as done", function()
		local store = fakeStore()
		local ledger = PurchaseLedgerService.new(store, noWait)
		ledger:bind(USER, entry("p1", SAVE_A))
		ledger:finish(USER, entry("p1", SAVE_A), true)
		local writes = store.writes
		expect.equal(ledger:bind(USER, entry("p1", SAVE_B)), "Done")
		expect.equal(store.writes, writes)
		local record = ledger:read(USER)
		expect.equal(record.unlocks.CashPinecone, true)
		expect.equal(store.writes, writes)
	end)

	t.test("reports and rebinds a purchase of another save", function()
		local ledger = PurchaseLedgerService.new(fakeStore(), noWait)
		expect.equal(ledger:bind(USER, entry("p1", SAVE_A)), "Bound")
		local status, other = ledger:bind(USER, entry("p1", SAVE_B))
		expect.equal(status, "Other")
		expect.equal(other, SAVE_A)
		expect.equal(ledger:bind(USER, entry("p1", SAVE_B), SAVE_A), "Bound")
		local record = ledger:read(USER)
		expect.equal(record.pending.p1.saveId, SAVE_B)
	end)

	t.test("refuses a full pending list", function()
		local ledger = PurchaseLedgerService.new(fakeStore(), noWait)
		for index = 1, 20 do
			expect.equal(ledger:bind(USER, entry("p" .. index, SAVE_A)), "Bound")
		end
		expect.equal(ledger:bind(USER, entry("p21", SAVE_A)), "Full")
		local record = ledger:read(USER)
		expect.equal(record.pending.p21, nil)
	end)

	t.test("never overwrites a corrupt ledger", function()
		local store = fakeStore()
		local ledger = PurchaseLedgerService.new(store, noWait)
		local key = PurchaseLedgerService.keyFor(USER)
		store.records[key] = { ledgerVersion = 1, userId = USER, robuxSpent = -5 }
		local status, code = ledger:bind(USER, entry("p1", SAVE_A))
		expect.equal(status, nil)
		expect.equal(code, "LedgerCorrupt")
		local record, finishCode = ledger:finish(USER, entry("p1", SAVE_A), false)
		expect.equal(record, nil)
		expect.equal(finishCode, "LedgerCorrupt")
		expect.equal(store.records[key].robuxSpent, -5)
		expect.equal(store.records[key].pending, nil)
		expect.equal(store.writes, 0)
		store.failCount = 3
		local _, loadCode = ledger:read(USER)
		expect.equal(loadCode, "LoadFailed")
		expect.equal(PurchaseLedgerService.keyFor(MAX_USER_ID), "purchases:9223372036854774784")
		expect.truthy(#PurchaseLedgerService.keyFor(MAX_USER_ID) <= KEY_NAME_LIMIT)
	end)

	t.test("counts each pass once", function()
		local store = fakeStore()
		local ledger = PurchaseLedgerService.new(store, noWait)
		local first = ledger:countPasses(USER, { PassVip = 199 })
		expect.equal(first.robuxSpent, 199)
		local writes = store.writes
		local second = ledger:countPasses(USER, { PassVip = 199 })
		expect.equal(second.robuxSpent, 199)
		expect.equal(store.writes, writes)
		local third = ledger:countPasses(USER, { PassVip = 199, PassCashX2 = 99 })
		expect.equal(third.robuxSpent, 298)
		expect.equal(third.passesCounted.PassVip, true)
		expect.equal(third.passesCounted.PassCashX2, true)
	end)
end
