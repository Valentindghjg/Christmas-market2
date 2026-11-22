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

	t.test("guard refuses a concurrent run and accepts a valid call", function()
		local busyOk, busyReason = RunPlaytest.guard(true, true, true, "running")
		expect.falsy(busyOk)
		expect.equal(busyReason, "AlreadyRunning")
		local ok, reason = RunPlaytest.guard(true, true, true, "done")
		expect.truthy(ok)
		expect.equal(reason, nil)
	end)
end
