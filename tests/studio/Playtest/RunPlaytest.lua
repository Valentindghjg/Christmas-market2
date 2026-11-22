--!strict
-- Repeatable Studio playtest (CM2-G20). Run in the Server data model of a Play session:
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "full" })
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "soak", minutes = 10 })
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "full", holdSeconds = 20 })
-- holdSeconds (0..60, default 0) pauses step 41 at the checkout queue for screen captures.
-- It drives the real player and a shadow company through StudioTestHook and prints
-- PASS/FAIL/SKIP per step prefixed with [PLAYTEST]. The runner installs helpers from
-- Playtest/Support and steps from Playtest/Steps (CM2-RF); none of them is under Cases, so the
-- unit-test runners never execute them. Nothing touches a game service at load time.
local RunPlaytest = {}
RunPlaytest.BUILD = "cm2-g15-f2"

local PREFIX = "[PLAYTEST]"

-- Refuses unless a Studio server with the test hook is idle. Order: Studio, server, hook, status.
function RunPlaytest.guard(
	isStudio: boolean,
	isServer: boolean,
	hookPresent: boolean,
	status: string?
): (boolean, string?)
	if not isStudio then
		return false, "NotStudio"
	end
	if not isServer then
		return false, "NotServer"
	end
	if not hookPresent then
		return false, "NoHook"
	end
	if status == "running" then
		return false, "AlreadyRunning"
	end
	return true, nil
end

local function validOptions(options: any): (string?, number?, number?)
	if type(options) ~= "table" then
		return nil, nil, nil
	end
	if options.mode ~= "full" and options.mode ~= "soak" then
		return nil, nil, nil
	end
	local minutes = options.minutes
	if minutes == nil then
		minutes = 10
	end
	if type(minutes) ~= "number" or minutes ~= math.floor(minutes) or minutes < 1 or minutes > 30 then
		return nil, nil, nil
	end
	local holdSeconds = options.holdSeconds
	if holdSeconds == nil then
		holdSeconds = 0
	end
	if
		type(holdSeconds) ~= "number"
		or holdSeconds ~= math.floor(holdSeconds)
		or holdSeconds < 0
		or holdSeconds > 60
	then
		return nil, nil, nil
	end
	return options.mode, minutes, holdSeconds
end

-- Requires one installer from Playtest/Support or Playtest/Steps (CM2-RF).
local function installer(group: string, name: string): (any) -> ()
	local folder = (script.Parent :: Instance):FindFirstChild(group)
	local module = folder and folder:FindFirstChild(name)
	assert(module ~= nil and module:IsA("ModuleScript"), "playtest module missing: " .. group .. "/" .. name)
	return require(module :: ModuleScript) :: any
end

local function execute(hook: any, mode: string, minutes: number, holdSeconds: number)
	local HttpService = game:GetService("HttpService")
	local ServerStorage = game:GetService("ServerStorage")

	local startedAt = os.clock()
	local results: { { id: string, name: string, result: string, detail: string } } = {}
	local outcome: { [string]: string } = {}

	-- Steps --------------------------------------------------------------------------------
	type Step = { id: string, name: string, needs: { string }, run: () -> string? }
	local steps: { Step } = {}
	local function addStep(id: string, name: string, needs: { string }, run: () -> string?)
		table.insert(steps, { id = id, name = name, needs = needs, run = run })
	end

	local ctx: any = setmetatable({}, {
		__index = function(_, key)
			error("playtest context has no field " .. tostring(key), 2)
		end,
	})
	ctx.PREFIX = PREFIX
	ctx.hook = hook
	ctx.minutes = minutes
	ctx.holdSeconds = holdSeconds
	ctx.results = results
	ctx.outcome = outcome
	ctx.addStep = addStep
	for _, name in { "Base", "Saves", "Fixtures" } do
		installer("Support", name)(ctx)
	end
	if mode == "full" then
		for _, name in { "Core", "Saves", "RowFill", "Npc", "Checkout", "Reviews" } do
			installer("Steps", name)(ctx)
		end
		addStep("22", "LEAK_CHECK", { "02" }, ctx.leakCheck)
		addStep("23", "CLEANUP", {}, ctx.cleanup)
	else
		installer("Steps", "Soak")(ctx)
	end
	local emit, record, R, player = ctx.emit, ctx.record, ctx.R, ctx.player

	-- Runner -------------------------------------------------------------------------------
	local plotText = tostring(R.plotId)
	emit(
		string.format(
			"START mode=%s player=%s (%d) plot=%s",
			mode,
			if player then player.Name else "none",
			R.userId,
			plotText
		)
	)

	for _, step in steps do
		local unmet: string? = nil
		for _, need in step.needs do
			if outcome[need] ~= "PASS" then
				unmet = need
				break
			end
		end
		if unmet then
			record(step.id, step.name, "SKIP", "needs " .. unmet)
		else
			local ok, detail = pcall(step.run)
			if ok then
				record(step.id, step.name, "PASS", if type(detail) == "string" then detail else "")
			else
				record(step.id, step.name, "FAIL", tostring(detail))
			end
		end
	end

	local passCount, failCount, skipCount = 0, 0, 0
	for _, entry in results do
		if entry.result == "PASS" then
			passCount += 1
		elseif entry.result == "FAIL" then
			failCount += 1
		else
			skipCount += 1
		end
	end
	local seconds = math.floor(os.clock() - startedAt + 0.5)
	local verdict = if failCount == 0 and skipCount == 0 then "PASS" else "FAIL"
	local summary = string.format(
		"SUMMARY mode=%s steps=%d pass=%d fail=%d skip=%d seconds=%d result=%s",
		mode,
		#results,
		passCount,
		failCount,
		skipCount,
		seconds,
		verdict
	)
	emit(summary)
	ServerStorage:SetAttribute("PlaytestSummary", summary)
	ServerStorage:SetAttribute("PlaytestReport", HttpService:JSONEncode(results))
end

function RunPlaytest.run(hook: any, options: any)
	local RunService = game:GetService("RunService")
	local ServerStorage = game:GetService("ServerStorage")
	local allowed, reason = RunPlaytest.guard(
		RunService:IsStudio(),
		RunService:IsServer(),
		hook ~= nil,
		ServerStorage:GetAttribute("PlaytestStatus")
	)
	if not allowed then
		print(string.format("%s REFUSED %s", PREFIX, tostring(reason)))
		return
	end
	local mode, minutes, holdSeconds = validOptions(options)
	if mode == nil or minutes == nil or holdSeconds == nil then
		print(string.format("%s REFUSED BadOptions", PREFIX))
		return
	end
	ServerStorage:SetAttribute("PlaytestStatus", "running")
	ServerStorage:SetAttribute("PlaytestSummary", nil)
	ServerStorage:SetAttribute("PlaytestReport", nil)
	local ok, message = pcall(execute, hook, mode, minutes, holdSeconds)
	if not ok then
		warn(string.format("%s runner error: %s", PREFIX, tostring(message)))
		ServerStorage:SetAttribute("PlaytestSummary", "SUMMARY runner error: " .. tostring(message))
	end
	ServerStorage:SetAttribute("PlaytestStatus", "done")
end

return RunPlaytest
