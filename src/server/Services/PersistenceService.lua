--!strict
-- Session-locked persistence. Financial callers must fail closed when load/save fails.
--
-- Keys (CM2-S1): `company:save:<saveId>` holds one company per save. The legacy
-- `company:personal:<userId>` record is copied into the first save by migrateLegacy and then
-- only carries `_migratedTo`/`_migratedAt`; it is never deleted or overwritten again.
-- A deleted save keeps its data and gains a `_deletedAt` tombstone.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local SaveProfile = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SaveProfile"))

local PersistenceService = {}
PersistenceService.__index = PersistenceService

local STORE_NAME = "ChristmasMarket2_CompanyState_v1"
local LOCK_SECONDS = GameConfig.SessionLockSeconds
local MAX_RETRIES = 3

PersistenceService.STORE_NAME = STORE_NAME

function PersistenceService.keyFor(companyId: string): string
	return "company:" .. companyId
end

local function now(): number
	return os.time()
end

-- Resolved lazily: the headless runner (Lune) has no `task` library.
local function defaultWait(seconds: number)
	task.wait(seconds)
end

local function copyState(state)
	return table.clone(state)
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[deepCopy(key)] = deepCopy(inner)
	end
	return copy
end

function PersistenceService.new(store, jobId: string?, clock, wait)
	local self = setmetatable({}, PersistenceService)
	self._store = store or DataStoreService:GetDataStore(STORE_NAME)
	self._jobId = jobId or game.JobId
	self._clock = clock or now
	self._wait = wait or defaultWait
	self._sessions = {}
	return self
end

function PersistenceService:_retry(operation)
	local lastError = "Unknown"
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		if attempt < MAX_RETRIES then
			self._wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

function PersistenceService:_key(companyId: string): string
	return PersistenceService.keyFor(companyId)
end

-- True when another server holds an unexpired lock on the record.
function PersistenceService:_lockedByOther(record, currentTime: number): boolean
	local session = record._session
	return type(session) == "table" and session.jobId ~= self._jobId and (session.expiresAt or 0) > currentTime
end

-- Acquires a lock atomically. A lock held by another non-expired server never loads writable state.
-- options (CM2-S2): saveSize for a fresh record (default Solo); requireExisting refuses a
-- missing record with "SaveNotFound" and writes nothing (members never create a save).
-- saveName == nil keeps the stored name.
function PersistenceService:load(companyId: string, ownerUserId: number, saveName: string?, options)
	if type(companyId) ~= "string" or #companyId == 0 or type(ownerUserId) ~= "number" then
		return nil, "InvalidIdentity"
	end
	local settings = options or {}
	local loadedState = nil
	local lockDenied = false
	local refusal = nil
	local success, result = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			-- The transform can run more than once; reset its results first.
			loadedState = nil
			lockDenied = false
			refusal = nil
			local currentTime = self._clock()
			if previous == nil then
				if settings.requireExisting then
					refusal = "SaveNotFound"
					return nil
				end
				loadedState = BusinessState.new(companyId, ownerUserId, saveName)
				loadedState.saveSize = settings.saveSize or "Solo"
			elseif type(previous) ~= "table" then
				error("CorruptRecord")
			else
				if previous._deletedAt ~= nil then
					refusal = "SaveDeleted"
					return nil
				end
				if previous._migratedTo ~= nil then
					refusal = "SaveMigrated"
					return nil
				end
				if self:_lockedByOther(previous, currentTime) then
					lockDenied = true
					return nil
				end
				local migratedFrom = previous._migratedFrom
				local migrated, migrationError = BusinessState.migrate(previous, companyId, ownerUserId)
				if not migrated then
					error("MigrationFailed:" .. tostring(migrationError))
				end
				if saveName ~= nil then
					migrated.saveName = saveName
				end
				migrated._migratedFrom = migratedFrom
				loadedState = migrated
			end

			loadedState.updatedAt = currentTime
			loadedState._session = { jobId = self._jobId, expiresAt = currentTime + LOCK_SECONDS }
			return loadedState
		end)
	end)

	if not success then
		return nil, "LoadFailed:" .. tostring(result)
	end
	if refusal then
		return nil, refusal
	end
	if lockDenied or loadedState == nil then
		return nil, "SessionLocked"
	end
	self._sessions[companyId] = true
	return loadedState, nil
end

-- Writes only when this server still owns the session. Callers must stop economic mutations on failure.
function PersistenceService:save(companyId: string, state)
	if not self._sessions[companyId] or not BusinessState.validate(state) then
		return false, "NotLoaded"
	end
	local lockLost = false
	local success, result = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			lockLost = false
			if type(previous) ~= "table" then
				lockLost = true
				return nil
			end
			local session = previous._session
			if type(session) ~= "table" or session.jobId ~= self._jobId then
				lockLost = true
				return nil
			end
			local persisted = copyState(state)
			persisted.updatedAt = self._clock()
			persisted._session = { jobId = self._jobId, expiresAt = persisted.updatedAt + LOCK_SECONDS }
			return persisted
		end)
	end)
	if not success then
		return false, "SaveFailed:" .. tostring(result)
	end
	if lockLost then
		self._sessions[companyId] = nil
		return false, "SessionLocked"
	end
	return true, nil
end

function PersistenceService:release(companyId: string)
	if not self._sessions[companyId] then
		return true, nil
	end
	local success, result = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			if
				type(previous) == "table"
				and type(previous._session) == "table"
				and previous._session.jobId == self._jobId
			then
				previous._session = nil
			end
			return previous
		end)
	end)
	self._sessions[companyId] = nil
	if not success then
		return false, "ReleaseFailed:" .. tostring(result)
	end
	return true, nil
end

-- Whether a stored save already received a Robux purchase (CM2-46a cross-save receipts). One
-- read through UpdateAsync whose transform never writes. "Applied": the receipt is in the
-- record (checked first, a deleted save included); "Held": an unexpired lock of any server,
-- this one included; else "Free" (also for a missing record). A store error is "LoadFailed".
function PersistenceService:peekReceipt(companyId: string, purchaseId: string): (string?, string?)
	local status = "Free"
	local success = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			status = "Free"
			if type(previous) ~= "table" then
				return nil
			end
			local purchases = previous.purchases
			if type(purchases) == "table" and type(purchases.receipts) == "table" then
				for _, received in ipairs(purchases.receipts) do
					if received == purchaseId then
						status = "Applied"
						return nil
					end
				end
			end
			local session = previous._session
			if
				type(session) == "table"
				and type(session.expiresAt) == "number"
				and session.expiresAt > self._clock()
			then
				status = "Held"
			end
			return nil
		end)
	end)
	if not success then
		return nil, "LoadFailed"
	end
	return status, nil
end

-- Non-owner member IDs (ascending) and the invite code of a stored record (CM2-S2).
local function deletionInfo(record)
	local memberUserIds = {}
	if type(record.members) == "table" then
		for key, role in pairs(record.members) do
			if role ~= "Owner" and type(key) == "string" and string.match(key, "^%d+$") then
				table.insert(memberUserIds, tonumber(key) :: number)
			end
		end
	end
	table.sort(memberUserIds)
	return {
		memberUserIds = memberUserIds,
		inviteCode = if type(record.inviteCode) == "string" then record.inviteCode else nil,
	}
end

-- Changes a record that no server holds, without taking its lock (CM2-S2: joins, leaves and
-- the profile-independent team changes). mutate(state) returns (true, result) or
-- (false, errorCode); a refusal writes nothing. An expired lock is dropped, so a stalled
-- holder fails closed on its next save. The service's own _sessions map is never touched.
-- Returns (true, nil, result) or (false, errorCode).
function PersistenceService:updateUnlocked(companyId: string, ownerUserId: number, mutate): (boolean, string?, any)
	local refusal = nil
	local outcome = nil
	local success = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			refusal = nil
			outcome = nil
			if previous == nil then
				refusal = "SaveNotFound"
				return nil
			end
			if type(previous) ~= "table" then
				refusal = "LoadFailed"
				return nil
			end
			if previous._deletedAt ~= nil then
				refusal = "SaveDeleted"
				return nil
			end
			if previous._migratedTo ~= nil then
				refusal = "SaveNotFound"
				return nil
			end
			local currentTime = self._clock()
			local session = previous._session
			-- Any unexpired lock, this server's included, means a live session owns the record.
			if type(session) == "table" and (session.expiresAt or 0) > currentTime then
				refusal = "SaveInUse"
				return nil
			end
			local copy = deepCopy(previous)
			local migratedFrom = copy._migratedFrom
			copy._session = nil
			local migrated = BusinessState.migrate(copy, companyId, ownerUserId)
			if not migrated then
				refusal = "LoadFailed"
				return nil
			end
			local changed, result = mutate(migrated)
			if not changed then
				refusal = if type(result) == "string" then result else "LoadFailed"
				return nil
			end
			migrated._migratedFrom = migratedFrom
			migrated.updatedAt = currentTime
			if not BusinessState.validate(migrated) then
				refusal = "LoadFailed"
				return nil
			end
			outcome = result
			return migrated
		end)
	end)
	if not success then
		return false, "LoadFailed", nil
	end
	if refusal then
		return false, refusal, nil
	end
	return true, nil, outcome
end

-- Tombstones a save that no server holds. The data stays; load() refuses it from now on.
-- On success info = {memberUserIds, inviteCode} of the record (CM2-S2), read in the transform.
function PersistenceService:markDeleted(companyId: string): (boolean, string?, any)
	local refusal = nil
	local info = nil
	local success = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			refusal = nil
			info = nil
			if previous == nil then
				info = { memberUserIds = {}, inviteCode = nil }
				return nil
			end
			if type(previous) ~= "table" then
				refusal = "DeleteFailed"
				return nil
			end
			local session = previous._session
			if type(session) == "table" and session.jobId == self._jobId then
				refusal = "SaveActive"
				return nil
			end
			if self:_lockedByOther(previous, self._clock()) then
				refusal = "SaveInUse"
				return nil
			end
			info = deletionInfo(previous)
			previous._deletedAt = self._clock()
			return previous
		end)
	end)
	if not success then
		return false, "DeleteFailed", nil
	end
	if refusal then
		return false, refusal, nil
	end
	return true, nil, info
end

-- Clears our own lock on the legacy record after a failed migration step.
function PersistenceService:_clearLegacyLock(legacyKey: string)
	self:_retry(function()
		return self._store:UpdateAsync(legacyKey, function(previous)
			if
				type(previous) == "table"
				and type(previous._session) == "table"
				and previous._session.jobId == self._jobId
			then
				previous._session = nil
				return previous
			end
			return nil
		end)
	end)
end

-- Copies `company:personal:<userId>` into `company:save:<saveId>` without losing data.
-- Returns ("Migrated", saveId), ("NoLegacy", nil) or (nil, nil, errorCode). Every step is
-- idempotent, so a crash between steps is repaired by the next call.
function PersistenceService:migrateLegacy(userId: number, saveId: string, saveName: string)
	local legacyKey = self:_key("personal:" .. SaveProfile.userIdText(userId))

	-- a. Lock the legacy record and take a copy of its data.
	local outcome = nil
	local migratedTo = nil
	local copy = nil
	local locked = self:_retry(function()
		return self._store:UpdateAsync(legacyKey, function(previous)
			outcome = nil
			migratedTo = nil
			copy = nil
			if previous == nil then
				outcome = "NoLegacy"
				return nil
			end
			if type(previous) ~= "table" then
				outcome = "MigrationFailed"
				return nil
			end
			if previous._migratedTo ~= nil then
				outcome = "Migrated"
				migratedTo = previous._migratedTo
				return nil
			end
			local currentTime = self._clock()
			if self:_lockedByOther(previous, currentTime) then
				outcome = "SessionLocked"
				return nil
			end
			copy = deepCopy(previous)
			copy._session = nil
			previous._session = { jobId = self._jobId, expiresAt = currentTime + LOCK_SECONDS }
			outcome = "Copied"
			return previous
		end)
	end)
	if not locked then
		return nil, nil, "LoadFailed"
	end
	if outcome == "NoLegacy" then
		return "NoLegacy", nil
	end
	if outcome == "Migrated" then
		return "Migrated", migratedTo
	end
	if outcome ~= "Copied" or copy == nil then
		return nil, nil, outcome or "MigrationFailed"
	end

	-- Every failure after step a tries one clear of our legacy lock (Fix round 2, R3). If the
	-- clear fails too, the lock expires after SessionLockSeconds.
	local called, finished, finishedId, finishError =
		pcall(self._finishMigration, self, legacyKey, copy, userId, saveId, saveName)
	if not called then
		warn(
			string.format(
				"[ChristmasMarket2] migrateLegacy failed for %s: %s",
				SaveProfile.userIdText(userId),
				tostring(finished)
			)
		)
		finished, finishError = nil, "MigrationFailed"
	end
	if finished == nil then
		self:_clearLegacyLock(legacyKey)
		return nil, nil, finishError
	end
	return finished, finishedId
end

-- Steps b-d of migrateLegacy; same return values. Runs while we hold the legacy lock.
function PersistenceService:_finishMigration(legacyKey: string, copy, userId: number, saveId: string, saveName: string)
	local targetCompanyId = "save:" .. saveId
	local targetKey = self:_key(targetCompanyId)

	-- b. Migrate the copy to the current schema under the save's company ID.
	local migrated = BusinessState.migrate(copy, targetCompanyId, userId)
	if not migrated then
		return nil, nil, "MigrationFailed"
	end
	migrated.companyId = targetCompanyId
	migrated.saveName = saveName
	migrated.saveSize = "Solo"
	migrated._migratedFrom = legacyKey
	if not BusinessState.validate(migrated) then
		return nil, nil, "MigrationFailed"
	end

	-- c. Write the save record unless this migration already wrote it.
	local conflict = false
	local written = self:_retry(function()
		return self._store:UpdateAsync(targetKey, function(previous)
			conflict = false
			if previous == nil then
				return deepCopy(migrated)
			end
			if type(previous) == "table" and previous._migratedFrom == legacyKey then
				return nil
			end
			conflict = true
			return nil
		end)
	end)
	if not written then
		return nil, nil, "LoadFailed"
	end
	if conflict then
		return nil, nil, "MigrationConflict"
	end

	-- d. Mark the legacy record as moved and release our lock; its data stays unchanged.
	local refusal = nil
	local marked = self:_retry(function()
		return self._store:UpdateAsync(legacyKey, function(previous)
			refusal = nil
			if type(previous) ~= "table" then
				refusal = "MigrationFailed"
				return nil
			end
			local session = previous._session
			if session ~= nil and not (type(session) == "table" and session.jobId == self._jobId) then
				refusal = "SessionLocked"
				return nil
			end
			previous._migratedTo = saveId
			previous._migratedAt = self._clock()
			previous._session = nil
			return previous
		end)
	end)
	if not marked then
		return nil, nil, "LoadFailed"
	end
	if refusal ~= nil then
		return nil, nil, refusal
	end
	return "Migrated", saveId
end

return PersistenceService
