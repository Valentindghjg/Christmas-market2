--!strict
-- CM2-SP1: the save picker's request gate and list refresh. Remote calls yield in a coroutine
-- until the test answers them; deferred calls and timers are queued and fired by hand.
return function(t)
	local SaveListSync =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SaveListSync"))
	local expect = t.expect

	local BUSY = { ok = false, errorCode = "SaveActionBusy" }
	local OK = { ok = true, data = { saves = { { saveId = "a", name = "N1 Phone" } } } }

	type Harness = {
		calls: { string },
		deferred: { () -> () },
		delayed: { { seconds: number, callback: () -> () } },
		renders: { any },
		status: string,
		open: boolean,
		busy: number,
		waiting: thread?,
		fail: boolean,
	}

	local function make(open: boolean?): (Harness, SaveListSync.Sync)
		local h: Harness = {
			calls = {},
			deferred = {},
			delayed = {},
			renders = {},
			status = "",
			open = if open == nil then true else open,
			busy = 0,
			waiting = nil,
			fail = false,
		}
		local sync = SaveListSync.new({
			invoke = function(action: string, _payload: { [string]: any }): any
				table.insert(h.calls, action)
				if h.fail then
					error("invoke failed")
				end
				h.waiting = coroutine.running()
				return coroutine.yield()
			end,
			defer = function(callback: () -> ())
				table.insert(h.deferred, callback)
			end,
			delay = function(seconds: number, callback: () -> ())
				table.insert(h.delayed, { seconds = seconds, callback = callback })
			end,
			isOpen = function(): boolean
				return h.open
			end,
			render = function(saves: { any }?)
				table.insert(h.renders, if saves == nil then "last" else saves)
			end,
			getStatus = function(): string
				return h.status
			end,
			setStatus = function(text: string)
				h.status = text
			end,
			errorText = function(code: unknown): string
				return "err:" .. tostring(code)
			end,
			onBusyAnswer = function(count: number)
				h.busy = count
			end,
		})
		return h, sync
	end

	local function answer(h: Harness, response: any)
		local waiting = h.waiting
		h.waiting = nil
		assert(waiting ~= nil, "no request is waiting for an answer")
		local resumed, err = coroutine.resume(waiting, response)
		assert(resumed, tostring(err))
	end

	local function flushDeferred(h: Harness)
		local queue = h.deferred
		h.deferred = {}
		for _, callback in ipairs(queue) do
			coroutine.wrap(callback)()
		end
	end

	local function fireDelayed(h: Harness)
		local queue = h.delayed
		h.delayed = {}
		for _, entry in ipairs(queue) do
			coroutine.wrap(entry.callback)()
		end
	end

	local function startRefresh(sync: SaveListSync.Sync)
		coroutine.wrap(sync.refresh)()
	end

	local function lastRender(h: Harness): any
		return h.renders[#h.renders]
	end

	t.test("busy list then ProfileReady during flight ends with rows and a clear status", function()
		local h, sync = make()
		startRefresh(sync)
		expect.equal(#h.calls, 1)
		-- The ProfileReady refresh arrives while the first list is in flight.
		sync.refresh()
		expect.equal(#h.calls, 1)
		answer(h, BUSY)
		expect.equal(h.status, "err:SaveActionBusy")
		expect.equal(lastRender(h), "last")
		expect.equal(h.busy, 1)
		expect.equal(sync.busyAnswers(), 1)
		expect.equal(#h.deferred, 1)
		flushDeferred(h)
		expect.equal(#h.calls, 2)
		answer(h, OK)
		local rendered = lastRender(h)
		expect.equal(type(rendered), "table")
		expect.equal(#rendered, 1)
		expect.equal(h.status, "")
		-- The retry scheduled by the first chain is stale now.
		fireDelayed(h)
		expect.equal(#h.calls, 2)
	end)

	t.test("busy list is retried after RetrySeconds", function()
		local h, sync = make()
		startRefresh(sync)
		answer(h, BUSY)
		expect.equal(#h.delayed, 1)
		expect.equal(h.delayed[1].seconds, SaveListSync.RetrySeconds)
		fireDelayed(h)
		expect.equal(#h.calls, 2)
		expect.equal(h.calls[2], SaveListSync.ListAction)
		answer(h, OK)
		local rendered = lastRender(h)
		expect.equal(type(rendered), "table")
		expect.equal(#rendered, 1)
		expect.equal(h.status, "")
	end)

	t.test("busy retries stop after RetryLimit", function()
		local h, sync = make()
		startRefresh(sync)
		for index = 1, SaveListSync.RetryLimit + 1 do
			answer(h, BUSY)
			if index <= SaveListSync.RetryLimit then
				expect.equal(#h.delayed, 1)
				fireDelayed(h)
			end
		end
		expect.equal(#h.calls, SaveListSync.RetryLimit + 1)
		expect.equal(#h.delayed, 0)
		expect.equal(h.status, "err:SaveActionBusy")
		expect.equal(h.busy, SaveListSync.RetryLimit + 1)
		expect.equal(sync.busyAnswers(), SaveListSync.RetryLimit + 1)
	end)

	t.test("other errors are not retried and clear on the next success", function()
		local h, sync = make()
		startRefresh(sync)
		answer(h, { ok = false, errorCode = "RateLimited" })
		expect.equal(#h.delayed, 0)
		expect.equal(h.status, "err:RateLimited")
		expect.equal(h.busy, 0)
		startRefresh(sync)
		answer(h, OK)
		expect.equal(h.status, "")
	end)

	t.test("a successful list keeps a status it did not set", function()
		local h, sync = make()
		h.status = "other"
		startRefresh(sync)
		answer(h, OK)
		expect.equal(h.status, "other")
	end)

	t.test("a transient busy status from outside is cleared by the next list", function()
		local h, sync = make()
		sync.showTransient("SaveActionBusy")
		expect.equal(h.status, "err:SaveActionBusy")
		startRefresh(sync)
		answer(h, OK)
		expect.equal(h.status, "")
	end)

	t.test("closed picker neither refreshes nor retries", function()
		local h, sync = make(false)
		sync.refresh()
		expect.equal(#h.calls, 0)
		h.open = true
		startRefresh(sync)
		answer(h, BUSY)
		h.open = false
		fireDelayed(h)
		expect.equal(#h.calls, 1)
	end)

	t.test("request during flight returns nil and queues no refresh", function()
		local h, sync = make()
		local response: any = nil
		coroutine.wrap(function()
			response = sync.request("Save.Play", { saveId = "a" })
		end)()
		expect.truthy(sync.inFlight())
		expect.equal(sync.request("Save.Create", {}), nil)
		expect.equal(#h.calls, 1)
		answer(h, { ok = true, data = {} })
		expect.equal(#h.deferred, 0)
		expect.falsy(sync.inFlight())
		expect.equal(response.ok, true)
	end)

	t.test("a throwing invoke becomes ConnectionError and releases the gate", function()
		local h, sync = make()
		h.fail = true
		local response = sync.request("Save.List", {})
		expect.equal(response.errorCode, "ConnectionError")
		expect.falsy(sync.inFlight())
		sync.refresh()
		expect.equal(h.status, "err:ConnectionError")
		expect.equal(#h.delayed, 0)
	end)
end
