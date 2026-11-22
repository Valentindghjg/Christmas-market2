--!strict
-- Studio-only test hook for reproducible playtests (docs/TEST_PLAN.md section 3b).
-- main.server.lua installs it only when RunService:IsStudio() and this module exists; the
-- release build (release.project.json) leaves the file out. The hook is a BindableFunction
-- in ServerStorage, so clients cannot reach it.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))

local StudioTestService = {}

-- Synthetic second player for the playtest; far above real Roblox user IDs.
StudioTestService.SHADOW_USER_ID = 999999999001

local function failure(errorCode: string)
	return { ok = false, errorCode = errorCode }
end

local function success(data: any?)
	return { ok = true, data = data }
end

function StudioTestService.install(context)
	local companies = context.companies
	local plots = context.plots
	local companyIdFor = context.companyIdFor
	local shadowUserId = StudioTestService.SHADOW_USER_ID

	local hook = Instance.new("BindableFunction")
	hook.Name = "StudioTestHook"

	local function realPlayer(userId: unknown): Player?
		if type(userId) ~= "number" then
			return nil
		end
		return Players:GetPlayerByUserId(userId)
	end

	local commands: { [string]: (arg: any) -> any } = {}

	-- Existing commands (moved from main.server.lua, behaviour unchanged).
	function commands.forceCustomer(arg)
		if type(arg) == "number" and arg >= 1 then
			-- The next arriving customer has profile `arg` and always converts.
			companies:setCustomerSequence(math.floor(arg) - 1)
			context.setForcedRolls(1)
			return true
		end
		return nil
	end

	function commands.advanceClock(arg)
		if type(arg) == "number" and arg > 0 and arg <= 3600 then
			return context.advanceClock(arg)
		end
		return nil
	end

	function commands.customerOrders(arg)
		if type(arg) == "number" then
			return companies:getCustomerOrders(companyIdFor(arg))
		end
		return nil
	end

	function commands.pauseCustomers(arg)
		if type(arg) ~= "boolean" then
			return failure("BadArgument")
		end
		context.setCustomersPaused(arg)
		return success(arg)
	end

	function commands.clock()
		return success(context.businessClock())
	end

	function commands.snapshot(arg)
		if type(arg) ~= "number" then
			return failure("BadArgument")
		end
		local snapshot = companies:snapshotForTest(companyIdFor(arg))
		if snapshot == nil then
			return failure("NoSession")
		end
		return success(snapshot)
	end

	function commands.act(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local request = {
			version = Protocol.VERSION,
			requestId = arg.requestId or ("studio_" .. HttpService:GenerateGUID(false)),
			action = arg.action,
			payload = arg.payload,
		}
		local player = realPlayer(arg.userId)
		if player then
			return context.handleBusinessAction(player, request)
		end
		if arg.userId == shadowUserId and context.shadowUsers[shadowUserId] then
			return companies:handle(companyIdFor(shadowUserId), shadowUserId, request)
		end
		return failure("NoPlayer")
	end

	function commands.visit(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local ok, result = companies:visitForTest(companyIdFor(arg.userId), arg.profile)
		if not ok then
			return failure(tostring(result))
		end
		return success(result)
	end

	function commands.prompt(arg)
		if type(arg) ~= "table" then
			return failure("BadArgument")
		end
		local player = realPlayer(arg.userId)
		if not player then
			return failure("NoPlayer")
		end
		if arg.kind ~= "carry" and arg.kind ~= "load" then
			return failure("BadKind")
		end
		-- The same call the ProximityPrompt Triggered handlers make.
		context.orderCallbacks[arg.kind](player, arg.number)
		return success()
	end

	function commands.respawn(arg)
		local player = realPlayer(arg)
		if not player then
			return failure("NoPlayer")
		end
		player:LoadCharacter()
		return success()
	end

	function commands.rejoin(arg)
		local player = realPlayer(arg)
		if not player then
			return failure("NoPlayer")
		end
		local companyId = companyIdFor(player.UserId)
		player:SetAttribute("CompanyReady", false)
		local unloaded, unloadError = companies:unloadCompany(companyId)
		if not unloaded then
			return failure("UnloadFailed:" .. tostring(unloadError))
		end
		local state, errorCode
		for attempt = 1, context.loadAttempts do
			state, errorCode = companies:loadPersonalCompany(player.UserId)
			-- SessionBusy: the unload above may still be finishing on this server.
			if state or errorCode ~= "SessionBusy" then
				break
			end
			task.wait(attempt)
		end
		if not state then
			player:SetAttribute("CompanyLoadError", errorCode)
			return failure(tostring(errorCode))
		end
		local plotId = player:GetAttribute("PlotId")
		if type(plotId) == "string" then
			context.syncPlotWorld(plotId, companyId, state)
		end
		player:SetAttribute("CompanyReady", true)
		player:SetAttribute("CompanyLoadError", nil)
		return success({ plotId = plotId })
	end

	function commands.shadowJoin()
		local companyId = companyIdFor(shadowUserId)
		local knownPlot = plots:getPlotForUser(shadowUserId)
		if context.shadowUsers[shadowUserId] and knownPlot and companies:isAvailable(companyId) then
			return success({ userId = shadowUserId, plotId = knownPlot })
		end
		local state, errorCode
		for attempt = 1, context.loadAttempts do
			state, errorCode = companies:loadPersonalCompany(shadowUserId)
			if state or errorCode ~= "SessionBusy" then
				break
			end
			task.wait(attempt)
		end
		if not state then
			return failure(tostring(errorCode))
		end
		local plotId, plotError = plots:claim(shadowUserId)
		if not plotId then
			companies:unloadCompany(companyId)
			return failure(tostring(plotError))
		end
		context.syncPlotWorld(plotId, companyId, state)
		context.shadowUsers[shadowUserId] = true
		return success({ userId = shadowUserId, plotId = plotId })
	end

	function commands.shadowLeave()
		local companyId = companyIdFor(shadowUserId)
		local unloaded, unloadError = companies:unloadCompany(companyId)
		companies:forgetUser(shadowUserId)
		local plotId = plots:getPlotForUser(shadowUserId)
		if plotId then
			context.clearPlotVisuals(plotId)
		end
		plots:release(shadowUserId)
		context.shadowUsers[shadowUserId] = nil
		if not unloaded then
			return failure("UnloadFailed:" .. tostring(unloadError))
		end
		return success()
	end

	function commands.setStaff(arg)
		if type(arg) ~= "table" then
			return failure("BadStaff")
		end
		if not companies:setStaffForTest(companyIdFor(shadowUserId), arg.employeeId, arg.count) then
			return failure("BadStaff")
		end
		return success()
	end

	function commands.runPlaytest(arg)
		local unitTest = ServerStorage:FindFirstChild("UnitTest")
		local folder = unitTest and unitTest:FindFirstChild("Playtest")
		local runner = folder and folder:FindFirstChild("RunPlaytest")
		if not (runner and runner:IsA("ModuleScript")) then
			return "refused: RunPlaytest not found"
		end
		if ServerStorage:GetAttribute("PlaytestStatus") == "running" then
			return "refused: already running"
		end
		-- Spawned from the hook callback (main script context) so it outlives the caller.
		task.spawn((require(runner) :: any).run, hook, arg)
		return "started"
	end

	hook.OnInvoke = function(command: string, arg: any)
		local handler = if type(command) == "string" then commands[command] else nil
		if handler == nil then
			return nil
		end
		return handler(arg)
	end
	hook.Parent = ServerStorage
	return hook
end

return StudioTestService
