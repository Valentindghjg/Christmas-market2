--!strict
-- CM2-G20: the Studio-only guard of the repeatable playtest.
return function(t)
	local RunPlaytest = require(
		game:GetService("ServerStorage"):WaitForChild("UnitTest"):WaitForChild("Playtest"):WaitForChild("RunPlaytest")
	)
	local expect = t.expect

	t.test("guard refuses outside Studio", function()
		local ok, reason = RunPlaytest.guard(false, true, true, nil)
		expect.falsy(ok)
		expect.equal(reason, "NotStudio")
	end)

	t.test("guard refuses outside the server or without the hook", function()
		local clientOk, clientReason = RunPlaytest.guard(true, false, true, nil)
		expect.falsy(clientOk)
		expect.equal(clientReason, "NotServer")
		local hookOk, hookReason = RunPlaytest.guard(true, true, false, nil)
		expect.falsy(hookOk)
		expect.equal(hookReason, "NoHook")
	end)

	t.test("gives every step a finite timeout", function()
		expect.equal(RunPlaytest.stepTimeout("full", 10, "SOAK_FAST"), 600)
		expect.equal(RunPlaytest.stepTimeout("full", 10, "CLEANUP"), 120)
		expect.equal(RunPlaytest.stepTimeout("soak", 10, "SOAK_REALTIME"), 1200)
	end)

	t.test("guard refuses a concurrent run and accepts a valid call", function()
		local busyOk, busyReason = RunPlaytest.guard(true, true, true, "running")
		expect.falsy(busyOk)
		expect.equal(busyReason, "AlreadyRunning")
		local ok, reason = RunPlaytest.guard(true, true, true, "done")
		expect.truthy(ok)
		expect.equal(reason, nil)
	end)

	-- Fake steps: every SMOKE ID plus 06, 12 and 36; chain 08 -> 07 -> 06 -> 05 -> 04 -> 03 -> 02.
	local function fakeSteps(): { { id: string, needs: { string } } }
		local needsById: { [string]: { string } } = {
			["02a"] = {},
			["02"] = {},
			["03"] = { "02" },
			["04"] = { "03" },
			["05"] = { "04" },
			["06"] = { "05" },
			["07"] = { "06" },
			["08"] = { "07" },
			["09"] = { "08" },
			["12"] = { "09" },
			["13"] = { "12" },
			["19"] = {},
			["36"] = { "08" },
			["41"] = { "03" },
			["22"] = { "02" },
			["23"] = {},
		}
		local ids = { "02a", "02", "03", "04", "05", "06", "07", "08", "09", "12", "13", "19", "36", "41", "22", "23" }
		local list = {}
		for _, id in ids do
			table.insert(list, { id = id, needs = needsById[id] or {} })
		end
		return list
	end

	local function countKeys(set: { [string]: boolean }): number
		local count = 0
		for _ in set do
			count += 1
		end
		return count
	end

	t.test("smoke selects the fixed core list", function()
		local selected, unknown = RunPlaytest.selectSteps(fakeSteps(), "smoke", nil)
		expect.equal(unknown, nil)
		expect.equal(#RunPlaytest.SMOKE, 13)
		local set = selected :: { [string]: boolean }
		expect.equal(countKeys(set), 13)
		for _, id in RunPlaytest.SMOKE do
			expect.truthy(set[id])
		end
		expect.falsy(set["06"])
		expect.falsy(set["12"])
		expect.falsy(set["36"])
	end)

	t.test("only adds the named steps and their needs", function()
		for _, mode in { "smoke", "full" } do
			local selected = RunPlaytest.selectSteps(fakeSteps(), mode, { "36" }) :: { [string]: boolean }
			expect.equal(countKeys(selected), 15)
			expect.truthy(selected["36"])
			expect.truthy(selected["06"])
			expect.falsy(selected["12"])
		end
		local all = RunPlaytest.selectSteps(fakeSteps(), "full", nil) :: { [string]: boolean }
		expect.equal(countKeys(all), #fakeSteps())
	end)

	t.test("an unknown step id refuses", function()
		local selected, unknown = RunPlaytest.selectSteps(fakeSteps(), "smoke", { "36", "77" })
		expect.equal(selected, nil)
		expect.equal(unknown, "77")
	end)

	t.test("a need outside the run counts as met", function()
		expect.truthy(RunPlaytest.needMet({ ["07"] = true }, {}, "06"))
		expect.falsy(RunPlaytest.needMet({ ["06"] = true }, { ["06"] = "FAIL" }, "06"))
		expect.truthy(RunPlaytest.needMet({ ["06"] = true }, { ["06"] = "PASS" }, "06"))
	end)

	t.test("parses smoke, full, soak and only", function()
		local smokeMode, _, _, smokeOnly = RunPlaytest.parseOptions({ mode = "smoke", only = { "36", "12" } })
		expect.equal(smokeMode, "smoke")
		expect.equal(#(smokeOnly :: { string }), 2)
		local fullMode, minutes, holdSeconds, fullOnly = RunPlaytest.parseOptions({ mode = "full", holdSeconds = 20 })
		expect.equal(fullMode, "full")
		expect.equal(minutes, 10)
		expect.equal(holdSeconds, 20)
		expect.equal(fullOnly, nil)
		local soakMode, soakMinutes, _, soakOnly = RunPlaytest.parseOptions({ mode = "soak", minutes = 5 })
		expect.equal(soakMode, "soak")
		expect.equal(soakMinutes, 5)
		expect.equal(soakOnly, nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "soak", only = { "36" } })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "smoke", only = {} })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "smoke", only = { 1 } })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "smoke", only = { "12345" } })), nil)
		local tooMany = {}
		for index = 1, 21 do
			tooMany[index] = "a" .. tostring(index)
		end
		expect.equal((RunPlaytest.parseOptions({ mode = "smoke", only = tooMany })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "full", minutes = 31 })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "full", holdSeconds = 61 })), nil)
		expect.equal((RunPlaytest.parseOptions({ mode = "other" })), nil)
	end)
end
