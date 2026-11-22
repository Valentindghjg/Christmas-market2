--!strict
-- Save slots per player (CM2-S1). Owns the player profile (`profile:<userId>` in the
-- profiles store), the legacy migration call, the `Save.*` actions, play/switch/leave and
-- the active-save registry. It fills the "SessionService" role of TECHNICAL_ARCHITECTURE §2.
--
-- The profile is lock-free: every change is one UpdateAsync transform applied to the stored
-- value, so a second server can never lose an update. Company records keep their own
-- per-save session lock (PersistenceService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local function newEntry(saveId: string, name: string, now: number)
	return { saveId = saveId, name = name, role = "Owner", size = "Solo", createdAt = now, lastPlayedAt = 0 }
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
	self._profiles = {}
	self._busy = {}
	self._leaving = {}
	self._active = {}
	self._members = {}
	self._onActivated = nil
	self._onDeactivated = nil
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

function SaveSlotService:listFor(userId: number)
	local profile = self._profiles[userId]
	if not profile then
		return {}
	end
	return SaveProfile.listView(profile, saveIdOf(self._active[userId]))
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

-- Actions -----------------------------------------------------------------------------------

function SaveSlotService:_create(userId: number, request)
	local name = request.payload.name
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
		table.insert(current.saves, newEntry(saveId, finalName, now))
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
	if SaveProfile.find(profile, saveId) == nil then
		return failure("SaveNotFound")
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
	if not SaveProfile.confirmMatches(entry.name, payload.confirmName) then
		return failure("ConfirmationMismatch")
	end
	local companyId = companyIdOf(saveId)
	if self._active[userId] == companyId then
		return failure("SaveActive")
	end
	local marked, markError = self._persistence:markDeleted(companyId)
	if not marked then
		return failure(markError)
	end
	local updated, removeError = self:_removeEntry(userId, saveId)
	if not updated then
		return failure(removeError)
	end
	return { ok = true, data = { saveId = saveId } }
end

function SaveSlotService:_handle(userId: number, request)
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return failure(profileError)
	end
	local action = request.action
	local payload = request.payload
	if action == Protocol.SaveActions.List then
		local activeSaveId = saveIdOf(self._active[userId])
		return {
			ok = true,
			data = {
				saves = SaveProfile.listView(profile, activeSaveId),
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
	if not called then
		warn(string.format("[ChristmasMarket2] save action failed for %d: %s", userId, tostring(response)))
		return failure("InternalError")
	end
	return response
end

-- Play, switch and leave --------------------------------------------------------------------

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

	-- Another save, a failed session or a forced reload: leave it, keeping its plot preferred.
	local preferred = nil
	if current then
		preferred = self._plots:getPlot(current)
		self:leave(userId)
	end

	local plotId = self._plots:claim(companyId, preferred)
	if not plotId then
		local attempt = settings.attempt or 0
		if attempt < SAVES.MaxPlotTeleports then
			local teleported = self._teleport(userId, { saveId = saveId, attempt = attempt + 1 })
			return false, if teleported then "NoFreePlotTeleporting" else "NoFreePlot", nil
		end
		return false, "NoFreePlot", nil
	end

	local state, loadError = nil, nil
	for attempt = 1, SAVES.LoadAttempts do
		state, loadError = self._companies:loadCompany(companyId, userId, entry.name)
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
		self._plots:release(companyId)
		if loadError == "SaveDeleted" then
			local _, removeError = self:_removeEntry(userId, saveId)
			if removeError then
				warn(string.format("[ChristmasMarket2] could not drop deleted save %s: %s", saveId, removeError))
			end
		end
		return false, loadError or "LoadFailed", nil
	end

	if self._leaving[userId] or self._closing then
		-- The player left or the server began shutting down while the load yielded; nobody
		-- else will unload this session.
		local leaving = self._leaving[userId] == true
		self._companies:unloadCompany(companyId)
		self._plots:release(companyId)
		return false, if leaving then "PlayerLeft" else "ServerShuttingDown", nil
	end

	self:_register(userId, companyId)
	local now = self._clock()
	local _, touchError = self:_updateProfile(userId, function(stored)
		local currentProfile, storedError = storedProfile(stored)
		if not currentProfile then
			return nil, false, storedError
		end
		local stamped = SaveProfile.find(currentProfile, saveId)
		if stamped then
			stamped.lastPlayedAt = now
		end
		currentProfile.lastSaveId = saveId
		return currentProfile, true
	end)
	if touchError then
		warn(string.format("[ChristmasMarket2] could not mark save %s as played: %s", saveId, touchError))
	end
	local handler = self._onActivated
	if handler then
		local ok, err = pcall(handler, userId, companyId, plotId, state, entry.name)
		if not ok then
			warn(string.format("[ChristmasMarket2] save activation handler errored: %s", tostring(err)))
		end
	end
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
	if not called then
		warn(string.format("[ChristmasMarket2] play failed for %d: %s", userId, tostring(played)))
		return false, "InternalError", nil
	end
	return played, playError, data
end

-- Leaves the active save: saves it, releases its lock and frees its plot when nobody else
-- plays it.
function SaveSlotService:_leaveActive(userId: number): (boolean, string?)
	local ok, leaveError = true, nil
	local companyId = self._active[userId]
	if companyId then
		self:_deregister(userId, companyId)
		local plotId = self._plots:getPlot(companyId)
		self._companies:releaseCarried(companyId, userId)
		ok, leaveError = self._companies:unloadCompany(companyId)
		local plotReleased = false
		if self._members[companyId] == nil then
			plotReleased = self._plots:release(companyId)
		end
		local handler = self._onDeactivated
		if handler then
			local called, err = pcall(handler, userId, companyId, plotId, plotReleased)
			if not called then
				warn(string.format("[ChristmasMarket2] save deactivation handler errored: %s", tostring(err)))
			end
		end
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
