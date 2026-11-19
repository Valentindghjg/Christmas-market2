--!strict
return function(t)
	local PersistenceService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PersistenceService")
	)
	local expect = t.expect

	local function fakeStore()
		local records = {}
		return {
			UpdateAsync = function(_, key, transform)
				local nextValue = transform(records[key])
				if nextValue ~= nil then
					records[key] = nextValue
				end
				return records[key]
			end,
		}
	end

	-- A company can have one writable session until its holder releases the lock.
	t.test("prevents simultaneous writers", function()
		local store = fakeStore()
		local first = PersistenceService.new(store, "job-a", function()
			return 100
		end)
		local second = PersistenceService.new(store, "job-b", function()
			return 100
		end)
		local state = first:load("personal:42", 42)
		expect.truthy(state)
		local blocked, reason = second:load("personal:42", 42)
		expect.equal(blocked, nil)
		expect.equal(reason, "SessionLocked")
		expect.truthy(first:release("personal:42"))
		expect.truthy(second:load("personal:42", 42))
	end)

	-- A stale writer cannot overwrite a session it no longer owns.
	t.test("fails closed after lock loss", function()
		local store = fakeStore()
		local first = PersistenceService.new(store, "job-a", function()
			return 100
		end)
		local state = first:load("personal:77", 77)
		expect.truthy(state)
		first._sessions["personal:77"] = true
		local replacement = PersistenceService.new(store, "job-b", function()
			return 300
		end)
		expect.truthy(replacement:load("personal:77", 77))
		local saved, reason = first:save("personal:77", state)
		expect.falsy(saved)
		expect.equal(reason, "SessionLocked")
	end)
end
