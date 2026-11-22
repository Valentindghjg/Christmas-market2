--!strict
-- Save slots per player (CM2-S1) and co-op saves (CM2-S2). Owns the player profile
-- (`profile:<userId>` in the profiles store), the legacy migration call, the `Save.*` actions,
-- play/switch/leave and the active-save registry. It fills the "SessionService" role of
-- TECHNICAL_ARCHITECTURE §2.
--
-- The profile is lock-free: every change is one UpdateAsync transform applied to the stored
-- value, so a second server can never lose an update. Company records keep their own
-- per-save session lock (PersistenceService). Several players on one server can share one
-- live session of a co-op save; the last one to leave unloads it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))

local SaveSlotService = {}
SaveSlotService.__index = SaveSlotService

-- v2 since CM2-S1 Fix round 2 (R2): v1 held only Studio test profiles with old 32-hex save
-- IDs that the current isSaveId rejects; it is abandoned and never read.
SaveSlotService.PROFILE_STORE_NAME = "ChristmasMarket2_Profiles_v2"

local SAVES = GameConfig.Saves
local PROFILE_ATTEMPTS = 3
local LEGACY_SAVE_NAME = string.format(SAVES.DefaultNameFormat, 1)
local LEAVE_POLL_SECONDS = 0.1
-- Rate-limiter key for wrong invite codes; the server-wide limiter counts them under user 0.
local JOIN_FAILURE_ACTION = "fail"
local SERVER_LIMITER_USER = 0
-- Internal refusal so a Join by a member (or the owner) writes nothing.
local ALREADY_MEMBER = "AlreadyMember"

-- Join outcomes that all look like a wrong code to the player and count toward the lockout.
local JOIN_INVALID = { InviteCodeInvalid = true, SaveDeleted = true, SaveNotFound = true }
-- LeaveTeam: these record results mean the seat is already free.
local LEAVE_DONE = { NotAMember = true, SaveDeleted = true, SaveNotFound = true }

local function profileKey(userId: number): string
	return "profile:" .. SaveProfile.userIdText(userId)
end
SaveSlotService.profileKey = profileKey

local function companyIdOf(saveId: string): string
	return "save:" .. saveId
end

local function saveIdOf(companyId: string?): string?
	if type(companyId) ~= "string" then
		return nil
	end
	return string.match(companyId, "^save:(.+)$")
end

local function failure(errorCode: string?)
	return { ok = false, errorCode = errorCode or "InternalError" }
end

local function newEntry(saveId: string, name: string, now: number, size: string?)
	return {
		saveId = saveId,
		name = name,
		role = "Owner",
		size = size or "Solo",
		createdAt = now,
		lastPlayedAt = 0,
	}
end

local function memberEntry(saveId: string, size: string, now: number)
	return {
		saveId = saveId,
		name = SAVES.SharedEntryName,
		role = "Member",
		size = size,
		createdAt = now,
		lastPlayedAt = 0,
	}
end

local function sortedKeys(map): { number }
	local keys = {}
	for key in pairs(map) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function SaveSlotService.new(deps)
	local self = setmetatable({}, SaveSlotService)
	self._profileStore = deps.profileStore
	self._persistence = deps.persistence
	self._companies = deps.companies
	self._plots = deps.plots
	self._invites = deps.invites
	self._userName = deps.userName
	self._clock = deps.clock or os.time
	self._wait = deps.wait or function(seconds: number)
		task.wait(seconds)
	end
	self._newSaveId = deps.newSaveId
	self._filterName = deps.filterName
	self._teleport = deps.teleport
	self._limiters = {}
	for action, rule in pairs(SAVES.RateLimits) do
		self._limiters[action] = Protocol.newRateLimiter(rule.limit, rule.window)
	end
	-- Wrong invite codes per player and per server. Never cleared on leave, so a rejoin
	-- does not reset the lockout.
	self._joinFailures = Protocol.newRateLimiter(SAVES.JoinFailureLimit.limit, SAVES.JoinFailureLimit.window)
	self._serverJoinFailures =
		Protocol.newRateLimiter(SAVES.JoinServerFailureLimit.limit, SAVES.JoinServerFailureLimit.window)
	self._profiles = {}
	self._busy = {}
	self._leaving = {}
	self._active = {}
	self._members = {}
	-- Removed members who were busy when the owner removed them; kicked once they are idle.
	self._pendingKicks = {}
	-- Loads in progress per company and companies whose last session is being unloaded
	-- (Amendment A3: the plot hand-over between a last leaver and a waiting loader).
	self._pendingLoads = {}
	self._unloading = {}
	self._onActivated = nil
	self._onDeactivated = nil
	self._onRemoved = nil
	self._onTeamChanged = nil
	self._closing = false
	self._finalLeaves = 0
	return self
end

-- Shutdown: refuse new save work from now on (BindToClose).
function SaveSlotService:beginShutdown()
	self._closing = true
end

-- Final leaves in progress plus save actions in flight; BindToClose waits for zero.
function SaveSlotService:pendingCount(): number
	local count = self._finalLeaves
	for _ in pairs(self._busy) do
		count += 1
	end
	return count
end

function SaveSlotService:setActivationHandlers(onActivated, onDeactivated)
	self._onActivated = onActivated
	self._onDeactivated = onDeactivated
end

-- onRemoved(userId, saveId): the owner removed a member who played the save here.
-- onTeamChanged(companyId, size): a team change on a save that someone plays here.
function SaveSlotService:setTeamHandlers(onRemoved, onTeamChanged)
	self._onRemoved = onRemoved
	self._onTeamChanged = onTeamChanged
end

local function callHandler(handler, label: string, ...)
	if handler then
		local ok, err = pcall(handler, ...)
		if not ok then
			warn(string.format("[ChristmasMarket2] %s handler errored: %s", label, tostring(err)))
		end
	end
end

-- Profile I/O -------------------------------------------------------------------------------

-- Applies one transform to the stored profile with retries. mutate(stored) returns
-- (profile, write) to keep or write a profile, or (nil, false, errorCode) to refuse without
-- writing. The transform can run more than once, so its results are reset at its start.
function SaveSlotService:_updateProfile(userId: number, mutate): (any, string?)
	local result = nil
	local refusal = nil
	for attempt = 1, PROFILE_ATTEMPTS do
		local called = pcall(function()
			self._profileStore:UpdateAsync(profileKey(userId), function(stored)
				result = nil
				refusal = nil
				local profile, write, errorCode = mutate(stored)
				if profile == nil then
					refusal = errorCode or "ProfileCorrupt"
					return nil
				end
				if not write then
					result = profile
					return nil
				end
				profile.updatedAt = self._clock()
				if not SaveProfile.validate(profile) then
					refusal = "ProfileCorrupt"
					return nil
				end
				result = profile
				return profile
			end)
		end)
		if called then
			if refusal then
				return nil, refusal
			end
			if self._profiles[userId] ~= nil then
				self._profiles[userId] = result
			end
			return result, nil
		end
		if attempt < PROFILE_ATTEMPTS then
			self._wait(attempt)
		end
	end
	return nil, "ProfileUnavailable"
end

-- Every transform after the profile exists starts from a valid stored profile.
local function storedProfile(stored)
	if stored == nil then
		return nil, "ProfileUnavailable"
	end
	if not SaveProfile.validate(stored) then
		return nil, "ProfileCorrupt"
	end
	return stored, nil
end

function SaveSlotService:_openProfile(userId: number): (any, string?)
	local cached = self._profiles[userId]
	if cached then
		return cached, nil
	end
	local now = self._clock()
	local pendingId = self._newSaveId(userId)
	local profile, openError = self:_updateProfile(userId, function(stored)
		if stored == nil then
			local fresh = SaveProfile.new(userId, now)
			fresh.legacySaveId = pendingId
			return fresh, true
		end
		if not SaveProfile.validate(stored) then
			return nil, false, "ProfileCorrupt"
		end
		if stored.legacyState == "Pending" and stored.legacySaveId == nil then
			stored.legacySaveId = pendingId
			return stored, true
		end
		return stored, false
	end)
	if not profile then
		return nil, openError
	end

	if profile.legacyState == "Pending" then
		local legacySaveId = profile.legacySaveId
		local outcome, migratedId, migrateError =
			self._persistence:migrateLegacy(userId, legacySaveId, LEGACY_SAVE_NAME)
		if outcome == nil then
			-- Nothing is cached, so the next open retries the migration.
			return nil, migrateError or "MigrationFailed"
		end
		profile, openError = self:_updateProfile(userId, function(stored)
			local current, storedError = storedProfile(stored)
			if not current then
				return nil, false, storedError
			end
			if current.legacyState ~= "Pending" then
				return current, false
			end
			if outcome == "Migrated" then
				if SaveProfile.find(current, migratedId) == nil then
					table.insert(current.saves, 1, newEntry(migratedId, LEGACY_SAVE_NAME, now))
				end
				current.nextSaveNumber = math.max(current.nextSaveNumber, 2)
				current.legacyState = "Done"
			else
				current.legacyState = "None"
				local starterId = current.legacySaveId or legacySaveId
				if current.nextSaveNumber == 1 and #current.saves == 0 then
					table.insert(current.saves, newEntry(starterId, LEGACY_SAVE_NAME, now))
					current.nextSaveNumber = 2
				end
			end
			current.legacySaveId = nil
			return current, true
		end)
		if not profile then
			return nil, openError
		end
	end

	self._profiles[userId] = profile
	return profile, nil
end

function SaveSlotService:openProfile(userId: number): (any, string?)
	if self._closing then
		return nil, "ServerShuttingDown"
	end
	if self._busy[userId] then
		return nil, "SaveActionBusy"
	end
	self._busy[userId] = true
	local called, profile, openError = pcall(self._openProfile, self, userId)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] openProfile failed for %d: %s", userId, tostring(profile)))
		return nil, "InternalError"
	end
	return profile, openError
end

function SaveSlotService:closeProfile(userId: number)
	self._profiles[userId] = nil
end

function SaveSlotService:_removeEntry(userId: number, saveId: string): (any, string?)
	return self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local _, index = SaveProfile.find(current, saveId)
		if index == nil then
			return current, false
		end
		table.remove(current.saves, index)
		if current.lastSaveId == saveId then
			current.lastSaveId = nil
		end
		return current, true
	end)
end

-- How a server writes another player's profile (CM2-S2): one lock-free, validated transform
-- that removes only a Member entry of this save and a matching lastSaveId. Failures only warn;
-- a stale entry heals on the member's next Play (NotAMember).
function SaveSlotService:_dropMemberEntry(userId: number, saveId: string)
	local _, dropError = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local entry, index = SaveProfile.find(current, saveId)
		if entry == nil or entry.role ~= "Member" then
			return current, false
		end
		table.remove(current.saves, index)
		if current.lastSaveId == saveId then
			current.lastSaveId = nil
		end
		return current, true
	end)
	if dropError then
		warn(
			string.format(
				"[ChristmasMarket2] could not drop shared save %s for %s: %s",
				saveId,
				SaveProfile.userIdText(userId),
				dropError
			)
		)
	end
end

-- Registry ----------------------------------------------------------------------------------

function SaveSlotService:activeCompanyId(userId: number): string?
	return self._active[userId]
end

function SaveSlotService:activeUserIds(): { number }
	return sortedKeys(self._active)
end

function SaveSlotService:playersOn(companyId: string): { number }
	local members = self._members[companyId]
	return if members then sortedKeys(members) else {}
end

-- A player name for co-op views; nil when unknown (no lookup configured or it failed).
function SaveSlotService:_nameOf(userId: number?): string?
	if userId == nil or self._userName == nil then
		return nil
	end
	local called, name = pcall(self._userName, userId)
	if called and type(name) == "string" then
		return name
	end
	return nil
end

-- Picker rows: seats per row; a Member row never carries the save name (filter rule, CM2-S2).
function SaveSlotService:_listView(profile, activeSaveId: string?)
	local rows = SaveProfile.listView(profile, activeSaveId)
	for _, row in ipairs(rows) do
		row.seats = SAVES.Seats[row.size]
		if row.role == "Member" then
			row.name = nil
			row.ownerName = self:_nameOf(SaveProfile.ownerUserIdOf(row.saveId))
		end
	end
	return rows
end

function SaveSlotService:listFor(userId: number)
	local profile = self._profiles[userId]
	if not profile then
		return {}
	end
	return self:_listView(profile, saveIdOf(self._active[userId]))
end

function SaveSlotService:_register(userId: number, companyId: string)
	self._active[userId] = companyId
	local members = self._members[companyId] or {}
	members[userId] = true
	self._members[companyId] = members
end

function SaveSlotService:_deregister(userId: number, companyId: string)
	self._active[userId] = nil
	local members = self._members[companyId]
	if members then
		members[userId] = nil
		if next(members) == nil then
			self._members[companyId] = nil
		end
	end
end

function SaveSlotService:_deactivated(userId: number, companyId: string, plotId: string?, plotReleased: boolean)
	callHandler(self._onDeactivated, "save deactivation", userId, companyId, plotId, plotReleased)
end

-- Unloads the shared session (Amendment A3). The plot is released only when nobody plays
-- the save here and no load of it is waiting, so a waiting loader keeps the plot.
function SaveSlotService:_unloadShared(companyId: string): (boolean, string?, boolean)
	self._unloading[companyId] = true
	local ok, unloadError = self._companies:unloadCompany(companyId)
	local plotReleased = self._members[companyId] == nil
		and (self._pendingLoads[companyId] or 0) == 0
		and self._plots:release(companyId)
	self._unloading[companyId] = nil
	return ok, unloadError, plotReleased == true
end

-- Every player on a failed shared session leaves it; the session unloads once.
function SaveSlotService:_evict(companyId: string)
	local userIds = self:playersOn(companyId)
	local plotId = self._plots:getPlot(companyId)
	for _, userId in ipairs(userIds) do
		self:_deregister(userId, companyId)
	end
	local _, _, plotReleased = self:_unloadShared(companyId)
	for index, userId in ipairs(userIds) do
		self:_deactivated(userId, companyId, plotId, index == #userIds and plotReleased)
	end
end

-- Team notifications (Amendment A1): only after a successful team change.
function SaveSlotService:_teamChanged(companyId: string)
	if self._members[companyId] == nil then
		return
	end
	local info = self._companies:teamInfo(companyId)
	callHandler(self._onTeamChanged, "team change", companyId, info and info.saveSize)
end

-- Names -------------------------------------------------------------------------------------

-- Filters a normalized name at submission; a changed text means the name is not allowed.
function SaveSlotService:_filtered(userId: number, name: string): (boolean, string?)
	local allowed, filtered = self._filterName(userId, name)
	if not allowed then
		return false, filtered or "FilterUnavailable"
	end
	if filtered ~= name then
		return false, "NameNotAllowed"
	end
	return true, nil
end

-- Records -----------------------------------------------------------------------------------

-- One team change on a save record: through the live session when this server plays it,
-- refused while a session here is loading or unloading, else on the unlocked stored record.
-- Returns (ok, errorCode?, result?, saved).
function SaveSlotService:_changeRecord(saveId: string, mutate): (boolean, string?, any, boolean)
	local companyId = companyIdOf(saveId)
	if self._companies:isAvailable(companyId) then
		local ok, changeError, result, saved = self._companies:changeTeam(companyId, mutate, true)
		if not ok and changeError == "CompanyUnavailable" then
			changeError = "SaveInUse"
		end
		return ok, changeError, result, saved
	end
	if self._companies:hasSession(companyId) then
		return false, "SaveInUse", nil, false
	end
	local ok, changeError, result =
		self._persistence:updateUnlocked(companyId, SaveProfile.ownerUserIdOf(saveId) :: number, mutate)
	return ok, changeError, result, ok
end

-- Releases a code unless the live record still uses it (Amendment A2). Without a healthy
-- live record nothing is released; a stale map entry is harmless.
function SaveSlotService:_releaseUnused(companyId: string, saveId: string, code: string?)
	if code == nil then
		return
	end
	local live = self._companies:teamInfo(companyId)
	if live ~= nil and code ~= live.inviteCode then
		self._invites:release(code, saveId)
	end
end

-- Gives a Duo or larger save without a code a fresh code.
function SaveSlotService:_ensureInviteCode(companyId: string, saveId: string): boolean
	local code, claimError = self._invites:claim(saveId, nil)
	if not code then
		warn(string.format("[ChristmasMarket2] no invite code for %s: %s", saveId, tostring(claimError)))
		return false
	end
	local ok, changeError = self._companies:changeTeam(companyId, function(state)
		return BusinessState.setInviteCode(state, code, nil)
	end, true)
	if not ok then
		self:_releaseUnused(companyId, saveId, code)
		warn(string.format("[ChristmasMarket2] could not store invite code for %s: %s", saveId, tostring(changeError)))
		return false
	end
	self:_teamChanged(companyId)
	return true
end

-- Actions -----------------------------------------------------------------------------------

function SaveSlotService:_create(userId: number, request)
	local name = request.payload.name
	local size = request.payload.size or "Solo"
	local useDefault = name == nil or name == ""
	local normalized = nil
	if not useDefault then
		local nameError
		normalized, nameError = SaveProfile.normalizeName(name)
		if not normalized then
			return failure(nameError)
		end
		local allowed, filterError = self:_filtered(userId, normalized)
		if not allowed then
			return failure(filterError)
		end
	end
	local saveId = self._newSaveId(userId)
	local now = self._clock()
	local created = nil
	local profile, createError = self:_updateProfile(userId, function(stored)
		created = nil
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		for _, previous in ipairs(current.recentCreates) do
			if previous.requestId == request.requestId then
				local existing = SaveProfile.find(current, previous.saveId)
				created = { saveId = previous.saveId, name = existing and existing.name }
				return current, false
			end
		end
		if #current.saves >= SAVES.MaxSavesPerPlayer then
			return nil, false, "SaveLimit"
		end
		local finalName = normalized or string.format(SAVES.DefaultNameFormat, current.nextSaveNumber)
		if SaveProfile.nameTaken(current, finalName) then
			return nil, false, "NameInUse"
		end
		table.insert(current.saves, newEntry(saveId, finalName, now, size))
		current.nextSaveNumber += 1
		table.insert(current.recentCreates, { requestId = request.requestId, saveId = saveId })
		while #current.recentCreates > SAVES.RecentCreates do
			table.remove(current.recentCreates, 1)
		end
		created = { saveId = saveId, name = finalName }
		return current, true
	end)
	if not profile or not created then
		return failure(createError)
	end
	return { ok = true, data = created }
end

function SaveSlotService:_rename(userId: number, profile, payload)
	local saveId = payload.saveId
	local listed = SaveProfile.find(profile, saveId)
	if listed == nil then
		return failure("SaveNotFound")
	end
	if listed.role ~= "Owner" then
		return failure("OwnerOnly")
	end
	local normalized, nameError = SaveProfile.normalizeName(payload.name)
	if not normalized then
		return failure(nameError)
	end
	if SaveProfile.nameTaken(profile, normalized, saveId) then
		return failure("NameInUse")
	end
	local allowed, filterError = self:_filtered(userId, normalized)
	if not allowed then
		return failure(filterError)
	end
	local updated, renameError = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local entry = SaveProfile.find(current, saveId)
		if entry == nil then
			return nil, false, "SaveNotFound"
		end
		if SaveProfile.nameTaken(current, normalized, saveId) then
			return nil, false, "NameInUse"
		end
		entry.name = normalized
		return current, true
	end)
	if not updated then
		return failure(renameError)
	end
	local companyId = companyIdOf(saveId)
	if self._members[companyId] ~= nil then
		self._companies:setSaveName(companyId, normalized)
	end
	return { ok = true, data = { saveId = saveId, name = normalized } }
end

function SaveSlotService:_delete(userId: number, profile, payload)
	local saveId = payload.saveId
	local entry = SaveProfile.find(profile, saveId)
	if entry == nil then
		return failure("SaveNotFound")
	end
	if entry.role ~= "Owner" then
		return failure("OwnerOnly")
	end
	if not SaveProfile.confirmMatches(entry.name, payload.confirmName) then
		return failure("ConfirmationMismatch")
	end
	local companyId = companyIdOf(saveId)
	if self._active[userId] == companyId then
		return failure("SaveActive")
	end
	-- A member plays it here while the owner is elsewhere.
	if self._members[companyId] ~= nil then
		return failure("SaveInUse")
	end
	local marked, markError, info = self._persistence:markDeleted(companyId)
	if not marked then
		return failure(markError)
	end
	-- Best effort: a stale code or member entry is harmless (both are refused later).
	if info and info.inviteCode ~= nil then
		self._invites:release(info.inviteCode, saveId)
	end
	for _, memberUserId in ipairs(if info then info.memberUserIds else {}) do
		self:_dropMemberEntry(memberUserId, saveId)
	end
	local updated, removeError = self:_removeEntry(userId, saveId)
	if not updated then
		return failure(removeError)
	end
	return { ok = true, data = { saveId = saveId } }
end

-- Wrong-code lockout: per player and per server, checked before any store call.
function SaveSlotService:_joinLocked(userId: number): boolean
	local now = self._clock()
	return Protocol.recentCount(self._joinFailures, userId, JOIN_FAILURE_ACTION, now) >= SAVES.JoinFailureLimit.limit
		or Protocol.recentCount(self._serverJoinFailures, SERVER_LIMITER_USER, JOIN_FAILURE_ACTION, now)
			>= SAVES.JoinServerFailureLimit.limit
end

function SaveSlotService:_recordJoinFailure(userId: number)
	local now = self._clock()
	Protocol.allowRequest(self._joinFailures, userId, JOIN_FAILURE_ACTION, now)
	Protocol.allowRequest(self._serverJoinFailures, SERVER_LIMITER_USER, JOIN_FAILURE_ACTION, now)
end

-- Inserts the member entry for a joined save. No write when an entry exists; SaveLimit at the cap.
function SaveSlotService:_addMemberEntry(userId: number, saveId: string, size: string, now: number): string?
	local _, entryError = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		if SaveProfile.find(current, saveId) ~= nil then
			return current, false
		end
		if #current.saves >= SAVES.MaxSavesPerPlayer then
			return nil, false, "SaveLimit"
		end
		table.insert(current.saves, memberEntry(saveId, size, now))
		return current, true
	end)
	return entryError
end

function SaveSlotService:_join(userId: number, profile, payload)
	if #profile.saves >= SAVES.MaxSavesPerPlayer then
		return failure("SaveLimit")
	end
	local code = payload.code
	local saveId, lookupError = self._invites:lookup(code)
	if not saveId then
		if lookupError == "InviteCodeInvalid" then
			self:_recordJoinFailure(userId)
		end
		return failure(lookupError)
	end
	local joinedSize = nil
	local joinedRole = nil
	local ok, changeError, result = self:_changeRecord(saveId, function(state)
		joinedSize = nil
		joinedRole = nil
		local added, outcome = BusinessState.addMember(state, userId, code)
		if not added then
			return false, outcome
		end
		joinedSize = outcome.size
		if outcome.outcome == "AlreadyMember" then
			-- No write for a member or the owner typing the save's own code.
			joinedRole = state.members[SaveProfile.userIdText(userId)]
			return false, ALREADY_MEMBER
		end
		return true, outcome
	end)
	if not ok then
		if changeError == ALREADY_MEMBER then
			-- Amendment B F1: a member whose entry was lost (failed Join rollback) gets it back.
			-- No rollback on failure, because the seat was there before this request.
			if joinedRole == "Member" and SaveProfile.find(profile, saveId) == nil then
				local restoreError = self:_addMemberEntry(userId, saveId, joinedSize, self._clock())
				if restoreError then
					return failure(restoreError)
				end
			end
			return { ok = true, data = { saveId = saveId, size = joinedSize, alreadyMember = true } }
		end
		if changeError and JOIN_INVALID[changeError] then
			self:_recordJoinFailure(userId)
			return failure("InviteCodeInvalid")
		end
		return failure(changeError)
	end
	local size = result.size
	local entryError = self:_addMemberEntry(userId, saveId, size, self._clock())
	if entryError then
		-- Best-effort rollback: give the seat back.
		local rolledBack, rollbackError = self:_changeRecord(saveId, function(state)
			return BusinessState.removeMember(state, userId)
		end)
		if not rolledBack then
			warn(string.format("[ChristmasMarket2] join rollback failed for %s: %s", saveId, tostring(rollbackError)))
		end
		return failure(entryError)
	end
	self:_teamChanged(companyIdOf(saveId))
	return { ok = true, data = { saveId = saveId, size = size, alreadyMember = false } }
end

function SaveSlotService:_leaveTeam(userId: number, profile, payload)
	local saveId = payload.saveId
	local entry = SaveProfile.find(profile, saveId)
	if entry == nil then
		return failure("SaveNotFound")
	end
	if entry.role == "Owner" then
		return failure("OwnerCannotLeave")
	end
	local companyId = companyIdOf(saveId)
	if self._active[userId] == companyId then
		self:_leaveActive(userId)
	end
	local removed, removeError = self:_changeRecord(saveId, function(state)
		return BusinessState.removeMember(state, userId)
	end)
	if not removed and not (removeError and LEAVE_DONE[removeError]) then
		return failure(removeError)
	end
	local updated, entryError = self:_removeEntry(userId, saveId)
	if not updated then
		return failure(entryError)
	end
	if removed then
		self:_teamChanged(companyId)
	end
	return { ok = true, data = { saveId = saveId } }
end

-- Team management acts only on the requester's active, healthy save (Amendment A6).
function SaveSlotService:_activeTeam(userId: number, ownerOnly: boolean): (string?, string?)
	local companyId = self._active[userId]
	if companyId == nil then
		return nil, "SaveNotActive"
	end
	if not self._companies:isAvailable(companyId) then
		return nil, "CompanyUnavailable"
	end
	if ownerOnly and self._companies:memberRole(companyId, userId) ~= "Owner" then
		return nil, "OwnerOnly"
	end
	return companyId, nil
end

function SaveSlotService:_team(userId: number)
	local companyId, teamError = self:_activeTeam(userId, false)
	if not companyId then
		return failure(teamError)
	end
	local info = self._companies:teamInfo(companyId)
	if info == nil then
		return failure("CompanyUnavailable")
	end
	local role = self._companies:memberRole(companyId, userId)
	local online = self._members[companyId] or {}
	local rows = {}
	for key, memberRole in pairs(info.members) do
		local memberId = tonumber(key) :: number
		table.insert(rows, { userId = memberId, role = memberRole, online = online[memberId] == true })
	end
	table.sort(rows, function(a, b)
		if (a.role == "Owner") ~= (b.role == "Owner") then
			return a.role == "Owner"
		end
		return a.userId < b.userId
	end)
	for _, row in ipairs(rows) do
		row.name = self:_nameOf(row.userId)
	end
	return {
		ok = true,
		data = {
			saveId = saveIdOf(companyId),
			size = info.saveSize,
			seats = SAVES.Seats[info.saveSize],
			inviteCode = info.inviteCode,
			role = role,
			members = rows,
		},
	}
end

-- Leaves the active save for a removed member and tells them why.
function SaveSlotService:_kick(userId: number, companyId: string)
	if self._active[userId] ~= companyId then
		return
	end
	self:_leaveActive(userId)
	callHandler(self._onRemoved, "member removal", userId, saveIdOf(companyId))
end

-- Runs a kick that waited for the member's own save action to finish.
function SaveSlotService:_runPendingKick(userId: number)
	local companyId = self._pendingKicks[userId]
	if companyId == nil then
		return
	end
	self._pendingKicks[userId] = nil
	self:_kick(userId, companyId)
end

function SaveSlotService:_removeMember(userId: number, payload)
	local companyId, teamError = self:_activeTeam(userId, true)
	if not companyId then
		return failure(teamError)
	end
	local target = payload.userId
	if target == userId then
		return failure("CannotRemoveOwner")
	end
	local ok, removeError = self._companies:changeTeam(companyId, function(state)
		return BusinessState.removeMember(state, target)
	end, true)
	if not ok then
		return failure(removeError)
	end
	local saveId = saveIdOf(companyId) :: string
	self:_dropMemberEntry(target, saveId)
	if self._active[target] == companyId then
		if self._busy[target] then
			self._pendingKicks[target] = companyId
		else
			self:_kick(target, companyId)
		end
	end
	self:_teamChanged(companyId)
	return { ok = true, data = { userId = target } }
end

function SaveSlotService:_regenerateCode(userId: number)
	local companyId, teamError = self:_activeTeam(userId, true)
	if not companyId then
		return failure(teamError)
	end
	local info = self._companies:teamInfo(companyId)
	if info == nil then
		return failure("CompanyUnavailable")
	end
	if info.saveSize == "Solo" then
		return failure("SoloHasNoCode")
	end
	local saveId = saveIdOf(companyId) :: string
	local old = info.inviteCode
	local code, claimError = self._invites:claim(saveId, old)
	if not code then
		return failure(claimError)
	end
	local ok, changeError, _, saved = self._companies:changeTeam(companyId, function(state)
		return BusinessState.setInviteCode(state, code, old)
	end, true)
	if not ok then
		self:_releaseUnused(companyId, saveId, code)
		return failure(changeError)
	end
	-- Unsaved: keep the old map entry; the record check already refuses the old code.
	if saved then
		self:_releaseUnused(companyId, saveId, old)
	end
	self:_teamChanged(companyId)
	return { ok = true, data = { inviteCode = code } }
end

function SaveSlotService:_setSize(userId: number, payload)
	local companyId, teamError = self:_activeTeam(userId, true)
	if not companyId then
		return failure(teamError)
	end
	local size = payload.size
	local saveId = saveIdOf(companyId) :: string
	local ok, sizeError, previousCode, saved = self._companies:changeTeam(companyId, function(state)
		return BusinessState.setSaveSize(state, size)
	end, true)
	if not ok then
		return failure(sizeError)
	end
	-- Amendment A4: the cleared code is released only after the change was saved.
	if saved then
		self:_releaseUnused(companyId, saveId, previousCode)
	end
	local live = self._companies:teamInfo(companyId)
	if live ~= nil and live.saveSize ~= "Solo" and live.inviteCode == nil then
		self:_ensureInviteCode(companyId, saveId)
	end
	local _, entryError = self:_updateProfile(userId, function(stored)
		local current, storedError = storedProfile(stored)
		if not current then
			return nil, false, storedError
		end
		local entry = SaveProfile.find(current, saveId)
		if entry == nil or entry.size == size then
			return current, false
		end
		entry.size = size
		return current, true
	end)
	if entryError then
		warn(string.format("[ChristmasMarket2] could not store the size of %s: %s", saveId, entryError))
	end
	self:_teamChanged(companyId)
	return { ok = true, data = { size = size, seats = SAVES.Seats[size] } }
end

function SaveSlotService:_handle(userId: number, request)
	local action = request.action
	local payload = request.payload
	-- Amendment A8: a locked-out join makes no store call at all.
	if action == Protocol.SaveActions.Join and self:_joinLocked(userId) then
		return failure("JoinLocked")
	end
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return failure(profileError)
	end
	if action == Protocol.SaveActions.List then
		local activeSaveId = saveIdOf(self._active[userId])
		return {
			ok = true,
			data = {
				saves = self:_listView(profile, activeSaveId),
				activeSaveId = activeSaveId,
				maxSaves = SAVES.MaxSavesPerPlayer,
			},
		}
	elseif action == Protocol.SaveActions.Create then
		return self:_create(userId, request)
	elseif action == Protocol.SaveActions.Rename then
		return self:_rename(userId, profile, payload)
	elseif action == Protocol.SaveActions.Delete then
		return self:_delete(userId, profile, payload)
	elseif action == Protocol.SaveActions.Play then
		local played, playError, data = self:_play(userId, payload.saveId, nil)
		if not played then
			return failure(playError)
		end
		return { ok = true, data = data }
	elseif action == Protocol.SaveActions.Join then
		return self:_join(userId, profile, payload)
	elseif action == Protocol.SaveActions.LeaveTeam then
		return self:_leaveTeam(userId, profile, payload)
	elseif action == Protocol.SaveActions.Team then
		return self:_team(userId)
	elseif action == Protocol.SaveActions.RemoveMember then
		return self:_removeMember(userId, payload)
	elseif action == Protocol.SaveActions.RegenerateCode then
		return self:_regenerateCode(userId)
	elseif action == Protocol.SaveActions.SetSize then
		return self:_setSize(userId, payload)
	end
	return failure("UnknownAction")
end

-- Validates, rate-limits and serializes one untrusted `Save.*` request.
function SaveSlotService:handle(userId: number, request)
	local valid, validationError = Protocol.validateSaveRequest(request)
	if not valid then
		return failure(validationError)
	end
	if not Protocol.allowRequest(self._limiters[request.action], userId, request.action, self._clock()) then
		return failure("RateLimited")
	end
	if self._closing then
		return failure("ServerShuttingDown")
	end
	if self._busy[userId] then
		return failure("SaveActionBusy")
	end
	self._busy[userId] = true
	local called, response = pcall(self._handle, self, userId, request)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] save action failed for %d: %s", userId, tostring(response)))
		return failure("InternalError")
	end
	return response
end

-- Play, switch and leave --------------------------------------------------------------------

-- Another player plays this save here and its session is live: join that session.
function SaveSlotService:_canAttach(companyId: string): boolean
	return self._companies:isAvailable(companyId) and self._members[companyId] ~= nil and not self._unloading[companyId]
end

-- Marks the save as played: lastPlayedAt, lastSaveId and the entry size from the record.
-- The owner of a Duo or larger save without a code gets one.
function SaveSlotService:_touch(userId: number, saveId: string, companyId: string)
	local info = self._companies:teamInfo(companyId)
	local now = self._clock()
	local _, touchError = self:_updateProfile(userId, function(stored)
		local currentProfile, storedError = storedProfile(stored)
		if not currentProfile then
			return nil, false, storedError
		end
		local stamped = SaveProfile.find(currentProfile, saveId)
		if stamped then
			stamped.lastPlayedAt = now
			if info then
				stamped.size = info.saveSize
			end
		end
		currentProfile.lastSaveId = saveId
		return currentProfile, true
	end)
	if touchError then
		warn(string.format("[ChristmasMarket2] could not mark save %s as played: %s", saveId, touchError))
	end
	if
		info
		and self._companies:memberRole(companyId, userId) == "Owner"
		and info.saveSize ~= "Solo"
		and info.inviteCode == nil
	then
		self:_ensureInviteCode(companyId, saveId)
	end
end

function SaveSlotService:_activated(userId: number, saveId: string, companyId: string, plotId: string, state, entry)
	local info = self._companies:teamInfo(companyId)
	local role = self._companies:memberRole(companyId, userId) or entry.role
	local view = {
		saveName = if role == "Owner" then entry.name else nil,
		role = role,
		size = if info then info.saveSize else entry.size,
		ownerName = if role == "Member" then self:_nameOf(SaveProfile.ownerUserIdOf(saveId)) else nil,
	}
	callHandler(self._onActivated, "save activation", userId, companyId, plotId, state, view)
end

-- Step d: joins the live shared session on its plot.
function SaveSlotService:_attach(userId: number, saveId: string, companyId: string, entry): (boolean, string?, any)
	if self._companies:memberRole(companyId, userId) == nil then
		self:_dropMemberEntry(userId, saveId)
		return false, "NotAMember", nil
	end
	local plotId = self._plots:getPlot(companyId) :: string
	self:_register(userId, companyId)
	self:_touch(userId, saveId, companyId)
	self:_activated(userId, saveId, companyId, plotId, nil, entry)
	return true, nil, { saveId = saveId, plotId = plotId }
end

function SaveSlotService:_endLoad(companyId: string)
	local count = (self._pendingLoads[companyId] or 0) - 1
	self._pendingLoads[companyId] = if count > 0 then count else nil
end

function SaveSlotService:_play(userId: number, saveId: string, options): (boolean, string?, any)
	local settings = options or {}
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return false, profileError, nil
	end
	local entry = SaveProfile.find(profile, saveId)
	if entry == nil then
		return false, "SaveNotFound", nil
	end
	local companyId = companyIdOf(saveId)
	local current = self._active[userId]
	if current == companyId and self._companies:isAvailable(companyId) and not settings.reload then
		return true, nil, { saveId = saveId, plotId = self._plots:getPlot(companyId) }
	end

	-- a/b. Another save, a failed session or a forced reload: leave it, keeping its plot
	-- preferred. A reload never unloads a session that another player here plays.
	local preferred = nil
	if current then
		if current == companyId and settings.reload then
			for other in pairs(self._members[companyId] or {}) do
				if other ~= userId then
					return false, "SaveInUse", nil
				end
			end
		end
		preferred = self._plots:getPlot(current)
		self:_leaveActive(userId)
	end

	-- c. A failed shared session is evicted before the save loads again.
	if self._companies:isFailed(companyId) then
		self:_evict(companyId)
	end

	-- d. Attach to the live shared session.
	if self:_canAttach(companyId) then
		return self:_attach(userId, saveId, companyId, entry)
	end

	-- e. Claim the plot and load (Amendment A3).
	self._pendingLoads[companyId] = (self._pendingLoads[companyId] or 0) + 1
	local ownerUserId = SaveProfile.ownerUserIdOf(saveId) :: number
	local loadName = if entry.role == "Owner" then entry.name else nil
	local loadOptions = { saveSize = entry.size, requireExisting = entry.role == "Member" }
	local plotId = nil
	local state, loadError = nil, nil
	for attempt = 1, SAVES.LoadAttempts do
		if self:_canAttach(companyId) then
			self:_endLoad(companyId)
			return self:_attach(userId, saveId, companyId, entry)
		end
		if self._unloading[companyId] then
			-- The last leaver's unload is still in flight; never load under it.
			loadError = "SessionBusy"
		else
			plotId = self._plots:claim(companyId, preferred)
			if not plotId then
				self:_endLoad(companyId)
				local teleportAttempt = settings.attempt or 0
				if attempt == 1 and teleportAttempt < SAVES.MaxPlotTeleports then
					local teleported = self._teleport(userId, { saveId = saveId, attempt = teleportAttempt + 1 })
					return false, if teleported then "NoFreePlotTeleporting" else "NoFreePlot", nil
				end
				return false, "NoFreePlot", nil
			end
			state, loadError = self._companies:loadCompany(companyId, ownerUserId, loadName, loadOptions)
		end
		-- SessionBusy: this server is still saving a previous session of the save. A shutdown
		-- stops the retries.
		if state or loadError ~= "SessionBusy" or self._closing then
			break
		end
		if attempt < SAVES.LoadAttempts then
			self._wait(attempt)
		end
	end
	if not state then
		self:_endLoad(companyId)
		if
			self._members[companyId] == nil
			and (self._pendingLoads[companyId] or 0) == 0
			and not self._unloading[companyId]
			and not self._companies:hasSession(companyId)
		then
			self._plots:release(companyId)
		end
		if loadError == "SaveDeleted" then
			local _, removeError = self:_removeEntry(userId, saveId)
			if removeError then
				warn(string.format("[ChristmasMarket2] could not drop deleted save %s: %s", saveId, removeError))
			end
		end
		return false, loadError or "LoadFailed", nil
	end

	-- f. The record no longer lists this player.
	if self._companies:memberRole(companyId, userId) == nil then
		self:_endLoad(companyId)
		self:_unloadShared(companyId)
		self:_dropMemberEntry(userId, saveId)
		return false, "NotAMember", nil
	end

	-- g. The player left or the server began shutting down while the load yielded; nobody
	-- else will unload this session.
	if self._leaving[userId] or self._closing then
		local leaving = self._leaving[userId] == true
		self:_endLoad(companyId)
		self:_unloadShared(companyId)
		return false, if leaving then "PlayerLeft" else "ServerShuttingDown", nil
	end

	-- h. Register, then mark the save as played.
	self:_register(userId, companyId)
	self:_endLoad(companyId)
	self:_touch(userId, saveId, companyId)
	-- i.
	self:_activated(userId, saveId, companyId, plotId :: string, state, entry)
	return true, nil, { saveId = saveId, plotId = plotId }
end

function SaveSlotService:play(userId: number, saveId: string, options): (boolean, string?, any)
	if self._closing then
		return false, "ServerShuttingDown", nil
	end
	if self._busy[userId] then
		return false, "SaveActionBusy", nil
	end
	self._busy[userId] = true
	local called, played, playError, data = pcall(self._play, self, userId, saveId, options)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] play failed for %d: %s", userId, tostring(played)))
		return false, "InternalError", nil
	end
	return played, playError, data
end

-- Leaves the active save. The last player on it saves it, releases its lock and frees its
-- plot (unless a load of it is waiting); other players keep the shared session.
function SaveSlotService:_leaveActive(userId: number): (boolean, string?)
	local ok, leaveError = true, nil
	local companyId = self._active[userId]
	if companyId then
		self:_deregister(userId, companyId)
		-- Computed before any yield, so a member attaching meanwhile cannot be missed.
		local last = self._members[companyId] == nil
		if last then
			self._unloading[companyId] = true
		end
		local plotId = self._plots:getPlot(companyId)
		self._companies:releaseCarried(companyId, userId)
		local plotReleased = false
		if last then
			ok, leaveError, plotReleased = self:_unloadShared(companyId)
		end
		self:_deactivated(userId, companyId, plotId, plotReleased)
	end
	return ok, leaveError
end

-- final (PlayerRemoving, shutdown) first waits for an in-flight save action and counts as
-- pending work until the save is written, so BindToClose waits for it.
function SaveSlotService:leave(userId: number, final: boolean?): (boolean, string?)
	if not final then
		return self:_leaveActive(userId)
	end
	self._finalLeaves += 1
	local called, ok, leaveError = pcall(function()
		self._leaving[userId] = true
		while self._busy[userId] do
			self._wait(LEAVE_POLL_SECONDS)
		end
		self._pendingKicks[userId] = nil
		local left, err = self:_leaveActive(userId)
		for _, limiter in pairs(self._limiters) do
			Protocol.forgetUser(limiter, userId)
		end
		self._profiles[userId] = nil
		return left, err
	end)
	self._leaving[userId] = nil
	self._finalLeaves -= 1
	if not called then
		warn(string.format("[ChristmasMarket2] final leave failed for %d: %s", userId, tostring(ok)))
		return false, "InternalError"
	end
	return ok, leaveError
end

return SaveSlotService
