--!strict
-- CM2-HOOKSA: the argument shape of StudioTestHook "saveAction" (docs/TEST_PLAN.md).
-- The hook is installed with a fake save-slot service that applies the real
-- Protocol.validateSaveRequest, so each documented payload is checked against the real rules.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Protocol = require(Shared:WaitForChild("Protocol"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local StudioTestService = require(Services:WaitForChild("StudioTestService"))
	local expect = t.expect

	local SHADOW = StudioTestService.SHADOW_USER_ID
	local SAVE_ID = "42_0000000000000001"

	local function install(): any
		local saveSlots = {}
		function saveSlots:handle(_userId: number, request: any)
			local ok, errorCode = Protocol.validateSaveRequest(request)
			if not ok then
				return { ok = false, errorCode = errorCode }
			end
			return { ok = true, data = { action = request.action } }
		end
		return StudioTestService.install({
			companies = {},
			saveSlots = saveSlots,
			companyIdFor = function()
				return nil
			end,
			handleSaveAction = function()
				return { ok = false, errorCode = "NoPlayer" }
			end,
		})
	end

	t.test("saveAction accepts the documented shape for Create, Play and Delete", function()
		local hook = install()
		local create =
			hook:Invoke("saveAction", { userId = SHADOW, action = "Save.Create", payload = { name = "Hook Test" } })
		expect.truthy(create.ok)
		local play =
			hook:Invoke("saveAction", { userId = SHADOW, action = "Save.Play", payload = { saveId = SAVE_ID } })
		expect.truthy(play.ok)
		local delete = hook:Invoke(
			"saveAction",
			{ userId = SHADOW, action = "Save.Delete", payload = { saveId = SAVE_ID, confirmName = "Hook Test" } }
		)
		expect.truthy(delete.ok)
	end)

	t.test("saveAction refuses a wrong shape with BadArgument", function()
		local hook = install()
		expect.equal(hook:Invoke("saveAction", nil).errorCode, "BadArgument")
		expect.equal(hook:Invoke("saveAction", "Save.Create").errorCode, "BadArgument")
		expect.equal(
			hook:Invoke("saveAction", { action = "Save.Create", payload = { name = "x" } }).errorCode,
			"BadArgument"
		)
		expect.equal(
			hook:Invoke("saveAction", { userId = tostring(SHADOW), action = "Save.Create", payload = {} }).errorCode,
			"BadArgument"
		)
	end)

	t.test("saveAction passes a payload with a wrong field through to the validator", function()
		local hook = install()
		local response = hook:Invoke(
			"saveAction",
			{ userId = SHADOW, action = "Save.Delete", payload = { saveId = SAVE_ID, name = "Hook Test" } }
		)
		expect.equal(response.errorCode, "UnexpectedField")
	end)
end
