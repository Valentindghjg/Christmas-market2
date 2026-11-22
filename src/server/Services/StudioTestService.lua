--!strict
-- Studio-only test hook for reproducible playtests (docs/TEST_PLAN.md section 3b).
-- main.server.lua installs it only when RunService:IsStudio() and this module exists; the
-- release build (release.project.json) leaves the file out. The hook is a BindableFunction
-- in ServerStorage, so clients cannot reach it.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))
local SaveProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SaveProfile"))
local PersistenceService = require(script.Parent:WaitForChild("PersistenceService"))

local StudioTestService = {}

-- Synthetic second player for the playtest; far above real Roblox user IDs.
StudioTestService.SHADOW_USER_ID = 999999999001
-- Synthetic third player for the co-op playtest steps (CM2-S2).
StudioTestService.SHADOW_2_USER_ID = 999999999002

-- Job ID of the fake foreign server that lockSave uses to steal a save's lock.
local THIEF_JOB_ID = "studio-test-thief"
local THIEF_LOCK_SECONDS = 300

local function failure(errorCode: string)
	return { ok = false, errorCode = errorCode }
end

local function success(data: any?)
	return { ok = true, data = data }
end

function StudioTestService.install(context)
	local companies = context.companies
	local saveSlots = context.saveSlots
	local companyIdFor = context.companyIdFor
	local shadowUserId = StudioTestService.SHADOW_USER_ID
	local shadow2UserId = StudioTestService.SHADOW_2_USER_ID

	-- Both synthetic users act directly on the services, like a real client's requests.
	local function isShadow(userId: unknown): boolean
		return userId == shadowUserId or userId == shadow2UserId
	end

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
			local companyId = companyIdFor(arg)
			if companyId == nil then
				return failure("NoActiveSave")
			end
			return companies:getCustomerOrders(companyId)
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
		local companyId = companyIdFor(arg)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		local snapshot = companies:snapshotForTest(companyId)
		if snapshot == nil then
			return failure("NoSession")
		end
		return success(snapshot)
	end

	function commands.act(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local companyId = companyIdFor(arg.userId)
		if companyId == nil then
			return failure("NoActiveSave")
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
		if isShadow(arg.userId) then
			return companies:handle(companyId, arg.userId, request)
		end
		return failure("NoPlayer")
	end

	function commands.visit(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local companyId = companyIdFor(arg.userId)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		local ok, result = companies:visitForTest(companyId, arg.profile)
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

	-- Reloads the player's active save from the DataStore, as a rejoin would.
	function commands.rejoin(arg)
		local player = realPlayer(arg)
		if not player then
			return failure("NoPlayer")
		end
		local companyId = companyIdFor(player.UserId)
		local activeSaveId = companyId and string.match(companyId, "^save:(.+)$")
		if not activeSaveId then
			return failure("NoActiveSave")
		end
		local played, playError, data = saveSlots:play(player.UserId, activeSaveId, { reload = true })
		if not played then
			return failure(tostring(playError))
		end
		return success({ plotId = data and data.plotId })
	end

	-- The shadow plays its saves like a real player: its legacy personal record migrates
	-- into "Tree Lot 1" on the first open.
	function commands.shadowJoin()
		local profile, profileError = saveSlots:openProfile(shadowUserId)
		if not profile then
			return failure(tostring(profileError))
		end
		if #profile.saves == 0 then
			local created = saveSlots:handle(shadowUserId, {
				version = Protocol.VERSION,
				requestId = "studio_" .. HttpService:GenerateGUID(false),
				action = Protocol.SaveActions.Create,
				payload = {},
			})
			if not created.ok then
				return failure(tostring(created.errorCode))
			end
		end
		local first = saveSlots:listFor(shadowUserId)[1]
		if not first then
			return failure("NoSave")
		end
		local played, playError, data = saveSlots:play(shadowUserId, first.saveId)
		if not played then
			return failure(tostring(playError))
		end
		return success({ userId = shadowUserId, plotId = data and data.plotId })
	end

	function commands.shadowLeave()
		local unloaded, unloadError = saveSlots:leave(shadowUserId, true)
		companies:forgetUser(shadowUserId)
		if not unloaded then
			return failure("UnloadFailed:" .. tostring(unloadError))
		end
		return success()
	end

	function commands.shadow2Leave()
		local unloaded, unloadError = saveSlots:leave(shadow2UserId, true)
		companies:forgetUser(shadow2UserId)
		if not unloaded then
			return failure("UnloadFailed:" .. tostring(unloadError))
		end
		return success()
	end

	function commands.setStaff(arg)
		if type(arg) ~= "table" then
			return failure("BadStaff")
		end
		local companyId = companyIdFor(shadowUserId)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		if not companies:setStaffForTest(companyId, arg.employeeId, arg.count) then
			return failure("BadStaff")
		end
		return success()
	end

	-- One Save.* request: through the remote handler for a real player, directly for the shadow.
	function commands.saveAction(arg)
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
			return context.handleSaveAction(player, request)
		end
		if isShadow(arg.userId) then
			return saveSlots:handle(arg.userId, request)
		end
		return failure("NoPlayer")
	end

	function commands.saves(arg)
		if type(arg) ~= "number" then
			return failure("BadArgument")
		end
		return success(saveSlots:listFor(arg))
	end

	function commands.flush()
		local ok, saved, failures = companies:flushDirty(true)
		return success({ ok = ok, saved = saved, failures = failures })
	end

	-- Only saves listed in that user's profile can be locked or unlocked.
	local function ownedSaveId(arg): string?
		if type(arg) ~= "table" or type(arg.userId) ~= "number" or not SaveProfile.isSaveId(arg.saveId) then
			return nil
		end
		for _, entry in saveSlots:listFor(arg.userId) do
			if entry.saveId == arg.saveId then
				return arg.saveId
			end
		end
		return nil
	end

	local function updateSaveRecord(saveId: string, transform)
		local store = DataStoreService:GetDataStore(context.persistenceStoreName)
		local ok, err = pcall(function()
			store:UpdateAsync(PersistenceService.keyFor("save:" .. saveId), transform)
		end)
		if not ok then
			return failure("StoreError:" .. tostring(err))
		end
		return success()
	end

	-- Simulates another server holding the save's session lock.
	function commands.lockSave(arg)
		local saveId = ownedSaveId(arg)
		if not saveId then
			return failure("NotOwnSave")
		end
		return updateSaveRecord(saveId, function(previous)
			if type(previous) ~= "table" then
				return nil
			end
			previous._session = { jobId = THIEF_JOB_ID, expiresAt = os.time() + THIEF_LOCK_SECONDS }
			return previous
		end)
	end

	function commands.unlockSave(arg)
		local saveId = ownedSaveId(arg)
		if not saveId then
			return failure("NotOwnSave")
		end
		return updateSaveRecord(saveId, function(previous)
			if
				type(previous) ~= "table"
				or type(previous._session) ~= "table"
				or previous._session.jobId ~= THIEF_JOB_ID
			then
				return nil
			end
			previous._session = nil
			return previous
		end)
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
