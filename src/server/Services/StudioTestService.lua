--!strict
-- Studio-only test hook for reproducible playtests (docs/TEST_PLAN.md section 3b).
-- main.server.lua installs it only when RunService:IsStudio() and this module exists; the
-- release build (release.project.json) leaves the file out. The hook is a BindableFunction
-- in ServerStorage, so clients cannot reach it.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Protocol"))
local SaveProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SaveProfile"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local PersistenceService = require(script.Parent:WaitForChild("PersistenceService"))

local StudioTestService = {}

-- Synthetic second player for the playtest; far above real Roblox user IDs.
StudioTestService.SHADOW_USER_ID = 999999999001
-- Synthetic third player for the co-op playtest steps (CM2-S2).
StudioTestService.SHADOW_2_USER_ID = 999999999002

-- Job ID of the fake foreign server that lockSave uses to steal a save's lock.
local THIEF_JOB_ID = "studio-test-thief"
local THIEF_LOCK_SECONDS = 300
-- Job ID of the fake foreign server that placeElsewhere writes into the save-to-server map.
local ELSEWHERE_JOB_ID = "studio-test-elsewhere"
local ELSEWHERE_SECONDS = 300

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

	-- Clears today's likers of a shadow user's lot so a playtest can like it again (CM2-G15).
	function commands.resetLikes(arg)
		if not isShadow(arg) then
			return failure("BadArgument")
		end
		local companyId = companyIdFor(arg)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		return success(companies:resetLikesForTest(companyId))
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
		if arg.kind ~= "carry" and arg.kind ~= "load" and arg.kind ~= "checkout" then
			return failure("BadKind")
		end
		-- The same call the ProximityPrompt Triggered handlers make.
		if arg.kind == "checkout" then
			-- CM2-N2: the counter prompt of the player's plot.
			local plotId = player:GetAttribute("PlotId")
			if type(plotId) ~= "string" then
				return failure("NoPlot")
			end
			context.checkoutAt(player, plotId)
		else
			context.orderCallbacks[arg.kind](player, arg.number)
		end
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

	-- Visible staff (CM2-25/26).
	local staff = context.staff

	function commands.staffSnapshot()
		return success(staff:snapshot())
	end

	-- Sets one role's energy of the shadow's company: the live record and the saved value.
	function commands.setStaffEnergy(arg)
		if
			type(arg) ~= "table"
			or type(arg.employeeId) ~= "string"
			or table.find(GameConfig.Staff.Roles, arg.employeeId) == nil
			or type(arg.energy) ~= "number"
			or arg.energy ~= math.floor(arg.energy)
			or arg.energy < 0
			or arg.energy > GameConfig.Staff.Energy.Max
		then
			return failure("BadStaff")
		end
		local companyId = companyIdFor(shadowUserId)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		local live = staff:setEnergyForTest(companyId, arg.employeeId, arg.energy)
		if not companies:setStaffEnergy(companyId, { [arg.employeeId] = arg.energy }) then
			return failure("NoSession")
		end
		return success({ live = live })
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

	-- Save-to-server map (CM2-S3). Only saves listed in that user's profile.
	local locatorMap = context.locatorMap
	local locatorKey = context.locatorKey

	-- The raw map value for the save, or nil.
	function commands.locatorEntry(arg)
		local saveId = ownedSaveId(arg)
		if not saveId then
			return failure("NotOwnSave")
		end
		local ok, value = pcall(function()
			return locatorMap:GetAsync(locatorKey(saveId))
		end)
		if not ok then
			return failure("LocatorUnavailable")
		end
		return success({ entry = value })
	end

	-- Simulates another live server holding the save.
	function commands.placeElsewhere(arg)
		local saveId = ownedSaveId(arg)
		if not saveId then
			return failure("NotOwnSave")
		end
		local ok = pcall(function()
			locatorMap:SetAsync(locatorKey(saveId), {
				jobId = ELSEWHERE_JOB_ID,
				placeId = game.PlaceId,
				hostUserId = shadowUserId,
				renewedAt = os.time(),
			}, ELSEWHERE_SECONDS)
		end)
		if not ok then
			return failure("LocatorUnavailable")
		end
		return success({ placed = true })
	end

	-- Removes the entry only when placeElsewhere wrote it.
	function commands.clearElsewhere(arg)
		local saveId = ownedSaveId(arg)
		if not saveId then
			return failure("NotOwnSave")
		end
		local ok, cleared = pcall(function()
			local key = locatorKey(saveId)
			local value = locatorMap:GetAsync(key)
			if type(value) ~= "table" or value.jobId ~= ELSEWHERE_JOB_ID then
				return false
			end
			locatorMap:RemoveAsync(key)
			return true
		end)
		if not ok then
			return failure("LocatorUnavailable")
		end
		return success({ cleared = cleared == true })
	end

	function commands.renewLocations()
		local ok, renewed, failures = saveSlots:renewLocations()
		return success({ ok = ok, renewed = renewed, failures = failures })
	end

	-- Walking customer NPCs (CM2-N1).
	local npc = context.npc

	-- One forced walking customer (roll 0) with the given profile number.
	function commands.npcVisit(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" or type(arg.profile) ~= "number" then
			return failure("BadArgument")
		end
		local companyId = companyIdFor(arg.userId)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		local ok, result = npc:spawnForTest(companyId, arg.profile)
		if not ok then
			return failure(tostring(result))
		end
		return success(result)
	end

	function commands.npcSnapshot()
		return success(npc:snapshot())
	end

	function commands.npcGiveUp(arg)
		if type(arg) ~= "string" or not npc:giveUpForTest(arg) then
			return failure("NotGivingUp")
		end
		return success()
	end

	-- Hard-removes every NPC visit at once, then sweeps and re-syncs each live company
	-- (Fix round 1, F8).
	function commands.npcReset()
		return success({ removed = npc:resetForTest() })
	end

	-- The company's next live arrival gets this profile number (Fix round 1, F8).
	function commands.npcNextArrival(arg)
		if
			type(arg) ~= "table"
			or type(arg.userId) ~= "number"
			or type(arg.profile) ~= "number"
			or arg.profile ~= math.floor(arg.profile)
			or arg.profile < 1
			or arg.profile == math.huge
		then
			return failure("BadArgument")
		end
		local companyId = companyIdFor(arg.userId)
		if companyId == nil then
			return failure("NoActiveSave")
		end
		npc:setArrivalOverrideForTest(companyId, arg.profile)
		return success()
	end

	-- Fills every plot to its NPC budget with load-test NPCs, counts Heartbeat frames in 5-s
	-- windows, then removes what is left. arg.staff == true (CM2-25/26) also walks 2 load
	-- staff per plot; their snaps count in `snaps`.
	function commands.npcLoadTest(arg)
		local Npc = GameConfig.Customers.Npc
		local seconds = 60
		if type(arg) == "table" and type(arg.seconds) == "number" and arg.seconds == arg.seconds then
			seconds = math.clamp(math.floor(arg.seconds), 10, 120)
		end
		local withStaff = type(arg) == "table" and arg.staff == true
		local before = npc:snapshot().loadSnaps
		local staffBefore = staff:snapshot().loadSnaps
		local spawned = 0
		for _, plotId in ipairs(GameConfig.PersonalPlotIds) do
			spawned += npc:spawnLoad(plotId, Npc.MaxPerPlot - npc:countOnPlot(plotId), seconds)
		end
		local staffSpawned = 0
		if withStaff then
			for _, plotId in ipairs(GameConfig.PersonalPlotIds) do
				staffSpawned += staff:spawnLoad(plotId, 2, seconds)
			end
		end
		local peakStaff = 0
		local windows = math.floor(seconds / 5)
		local peakLive = 0
		local minFps = math.huge
		local fpsSum = 0
		for _ = 1, windows do
			local frames = 0
			local connection = RunService.Heartbeat:Connect(function()
				frames += 1
			end)
			local started = os.clock()
			task.wait(5)
			connection:Disconnect()
			local fps = frames / math.max(os.clock() - started, 1e-3)
			minFps = math.min(minFps, fps)
			fpsSum += fps
			peakLive = math.max(peakLive, npc:count())
			peakStaff = math.max(peakStaff, staff:count())
		end
		local function loadLeft(): boolean
			for _, visit in npc:snapshot().visits do
				if visit.loadTest then
					return true
				end
			end
			return false
		end
		local deadline = os.clock() + Npc.DepartSeconds + 1
		while loadLeft() and os.clock() < deadline do
			task.wait(0.1)
		end
		local left = npc:clearLoad()
		staff:clearLoad()
		local staffSnaps = staff:snapshot().loadSnaps - staffBefore
		return success({
			spawned = spawned,
			peakLive = peakLive,
			windows = windows,
			minFps = if windows > 0 then minFps else 0,
			meanFps = if windows > 0 then fpsSum / windows else 0,
			snaps = npc:snapshot().loadSnaps - before + staffSnaps,
			left = left,
			staffSpawned = staffSpawned,
			peakStaff = peakStaff,
		})
	end

	-- Robux shop (CM2-46a). Nothing here prompts or charges: receipts are simulated.
	local monetization = context.monetization
	local ledger = context.ledger

	-- One simulated developer-product receipt through the real receipt path.
	function commands.shopReceipt(arg)
		if
			type(arg) ~= "table"
			or type(arg.userId) ~= "number"
			or type(arg.productKey) ~= "string"
			or type(arg.purchaseId) ~= "string"
			or (arg.robux ~= nil and type(arg.robux) ~= "number")
		then
			return failure("BadArgument")
		end
		local decision = monetization:processReceiptByKey(arg.productKey, {
			PlayerId = arg.userId,
			ProductId = 0,
			PurchaseId = arg.purchaseId,
			CurrencySpent = arg.robux or 0,
		}, { present = isShadow(arg.userId) or realPlayer(arg.userId) ~= nil })
		return success(decision)
	end

	-- Sets a user's pass ownership: passes = { [passKey] = true }.
	function commands.shopPasses(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" or type(arg.passes) ~= "table" then
			return failure("BadArgument")
		end
		monetization:setPassesForTest(arg.userId, arg.passes)
		return success()
	end

	-- A fresh copy of the user's purchase ledger.
	function commands.shopLedger(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local record, readError = ledger:read(arg.userId)
		if record == nil then
			return failure(tostring(readError))
		end
		return success(record)
	end

	-- One Shop.* request for the real player, like the ShopAction remote.
	function commands.shopAction(arg)
		if type(arg) ~= "table" or type(arg.userId) ~= "number" then
			return failure("BadArgument")
		end
		local player = realPlayer(arg.userId)
		if not player then
			return failure("NoPlayer")
		end
		return monetization:handle(player.UserId, {
			version = Protocol.VERSION,
			requestId = "studio_" .. HttpService:GenerateGUID(false),
			action = arg.action,
			payload = arg.payload,
		})
	end

	function commands.shopPrompts()
		return success(monetization:promptCountForTest())
	end

	-- Ends every live Cash Rush boost and saves at once (Amendment 1, playtest fixture).
	function commands.shopClearBoosts()
		local _, ticked = companies:tickBoostsAll(ShopConfig.BoostCapSeconds)
		companies:flushDirty(true)
		return success(ticked)
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
