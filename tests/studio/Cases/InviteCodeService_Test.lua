--!strict
-- CM2-S2: the invite-code index over a fake DataStore. No test touches a real DataStore.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local InviteCodeService = require(Services:WaitForChild("InviteCodeService"))
	local expect = t.expect

	local KEY_NAME_LIMIT = 50 -- real DataStore rule (KeyNameLimit)
	local SAVE_A = "42_" .. string.rep("0a", 8)
	local SAVE_B = "77_" .. string.rep("0b", 8)

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

	-- Deep-copies on read and write like a real DataStore; throws while failCount > 0.
	local function fakeStore()
		local store: any = { records = {}, failCount = 0, writes = 0, calls = 0 }
		function store.UpdateAsync(_, key: string, transform)
			store.calls += 1
			if #key > KEY_NAME_LIMIT then
				error("KeyNameLimit: Key name exceeds the 50 character limit.")
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

	-- randomCode returns the queued numbers in order, then repeats the last one.
	local function setup(codes: { number })
		local env: any = { store = fakeStore(), now = 500, waits = {}, index = 0 }
		env.service = InviteCodeService.new(env.store, function()
			return env.now
		end, function(seconds: number)
			table.insert(env.waits, seconds)
		end, function(): number
			env.index = math.min(env.index + 1, #codes)
			return codes[env.index]
		end)
		return env
	end

	t.test("claims a free code for a save", function()
		local env = setup({ 12345 })
		local code, reason = env.service:claim(SAVE_A)
		expect.equal(reason, nil)
		expect.equal(code, "12345")
		expect.truthy(BusinessState.isInviteCode(code))
		local key = InviteCodeService.keyFor(code :: string)
		expect.equal(key, "invite:12345")
		expect.equal(#key, 12)
		expect.equal(env.store.records[key].saveId, SAVE_A)
		expect.equal(env.store.records[key].issuedAt, 500)
		expect.equal(InviteCodeService.STORE_NAME, "ChristmasMarket2_Invites_v1")
	end)

	t.test("tries another code on a collision", function()
		local env = setup({ 11111, 22222 })
		env.store.records["invite:11111"] = { saveId = SAVE_B, issuedAt = 1 }
		local code = env.service:claim(SAVE_A)
		expect.equal(code, "22222")
		expect.equal(env.store.records["invite:11111"].saveId, SAVE_B)
		expect.equal(env.store.records["invite:22222"].saveId, SAVE_A)

		local codes = {}
		for number = 1, GameConfig.Saves.InviteClaimAttempts do
			table.insert(codes, 30000 + number)
		end
		local full = setup(codes)
		for _, number in codes do
			full.store.records["invite:" .. number] = { saveId = SAVE_B, issuedAt = 1 }
		end
		local writes = full.store.writes
		local none, reason = full.service:claim(SAVE_A)
		expect.equal(none, nil)
		expect.equal(reason, "InviteCodeUnavailable")
		expect.equal(full.store.writes, writes)
		expect.equal(full.index, GameConfig.Saves.InviteClaimAttempts)
		for _, number in codes do
			expect.equal(full.store.records["invite:" .. number].saveId, SAVE_B)
		end

		local failing = setup({ 44444 })
		failing.store.failCount = 3
		local failed, failedReason = failing.service:claim(SAVE_A)
		expect.equal(failed, nil)
		expect.equal(failedReason, "InviteCodeUnavailable")
		expect.equal(failing.waits[1], 1)
		expect.equal(failing.waits[2], 2)
		expect.equal(#failing.waits, 2)
	end)

	t.test("claiming again for the same save writes nothing", function()
		local env = setup({ 12345 })
		expect.equal(env.service:claim(SAVE_A), "12345")
		local writes = env.store.writes
		env.now = 900
		expect.equal(env.service:claim(SAVE_A), "12345")
		expect.equal(env.store.writes, writes)
		expect.equal(env.store.records["invite:12345"].issuedAt, 500)
	end)

	t.test("never returns the excluded code", function()
		local env = setup({ 11111, 22222 })
		env.store.records["invite:11111"] = { saveId = SAVE_A, issuedAt = 1 }
		local writes = env.store.writes
		local calls = env.store.calls
		local code, reason = env.service:claim(SAVE_A, "11111")
		expect.equal(reason, nil)
		expect.equal(code, "22222")
		expect.equal(env.store.records["invite:11111"].saveId, SAVE_A)
		expect.equal(env.store.records["invite:11111"].issuedAt, 1)
		expect.equal(env.store.writes, writes + 1)
		expect.equal(env.store.calls, calls + 1)
	end)

	t.test("releases only its own code", function()
		local env = setup({ 12345 })
		expect.equal(env.service:claim(SAVE_A), "12345")
		local writes = env.store.writes
		expect.falsy(env.service:release("12345", SAVE_B))
		expect.equal(env.store.writes, writes)
		expect.equal(env.store.records["invite:12345"].saveId, SAVE_A)
		env.now = 700
		expect.truthy(env.service:release("12345", SAVE_A))
		expect.equal(env.store.records["invite:12345"].saveId, nil)
		expect.equal(env.store.records["invite:12345"].freedAt, 700)
		expect.falsy(env.service:release(nil, SAVE_A))
		expect.equal(env.service:claim(SAVE_B), "12345")
		expect.equal(env.store.records["invite:12345"].saveId, SAVE_B)
	end)

	t.test("looks up held, unknown and freed codes", function()
		local env = setup({ 12345 })
		expect.equal(env.service:claim(SAVE_A), "12345")
		local writes = env.store.writes
		expect.equal(env.service:lookup("12345"), SAVE_A)
		local unknown, unknownReason = env.service:lookup("54321")
		expect.equal(unknown, nil)
		expect.equal(unknownReason, "InviteCodeInvalid")
		expect.equal(env.store.writes, writes)
		expect.truthy(env.service:release("12345", SAVE_A))
		local freed, freedReason = env.service:lookup("12345")
		expect.equal(freed, nil)
		expect.equal(freedReason, "InviteCodeInvalid")
		writes = env.store.writes
		env.store.failCount = 3
		local broken, brokenReason = env.service:lookup("12345")
		expect.equal(broken, nil)
		expect.equal(brokenReason, "LoadFailed")
		expect.equal(env.store.writes, writes)
		for key in pairs(env.store.records) do
			expect.truthy(#key <= KEY_NAME_LIMIT)
		end
	end)
end
