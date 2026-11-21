--!strict
-- Session-locked persistence. Financial callers must fail closed when load/save fails.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PersistenceService = {}
PersistenceService.__index = PersistenceService

local STORE_NAME = "ChristmasMarket2_CompanyState_v1"
local LOCK_SECONDS = GameConfig.SessionLockSeconds
local MAX_RETRIES = 3

local function now(): number
	return os.time()
end

local function copyState(state)
	return table.clone(state)
end

function PersistenceService.new(store, jobId: string?, clock)
	local self = setmetatable({}, PersistenceService)
	self._store = store or DataStoreService:GetDataStore(STORE_NAME)
	self._jobId = jobId or game.JobId
	self._clock = clock or now
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
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false, lastError
end

function PersistenceService:_key(companyId: string): string
	return "company:" .. companyId
end

-- Acquires a lock atomically. A lock held by another non-expired server never loads writable state.
function PersistenceService:load(companyId: string, ownerUserId: number)
	if type(companyId) ~= "string" or #companyId == 0 or type(ownerUserId) ~= "number" then
		return nil, "InvalidIdentity"
	end
	local loadedState = nil
	local lockDenied = false
	local success, result = self:_retry(function()
		return self._store:UpdateAsync(self:_key(companyId), function(previous)
			local currentTime = self._clock()
			if previous == nil then
				loadedState = BusinessState.new(companyId, ownerUserId)
			elseif type(previous) ~= "table" then
				error("CorruptRecord")
			else
				local session = previous._session
				if
					type(session) == "table"
					and session.jobId ~= self._jobId
					and (session.expiresAt or 0) > currentTime
				then
					lockDenied = true
					return nil
				end
				local migrated, migrationError = BusinessState.migrate(previous, companyId, ownerUserId)
				if not migrated then
					error("MigrationFailed:" .. tostring(migrationError))
				end
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

return PersistenceService
