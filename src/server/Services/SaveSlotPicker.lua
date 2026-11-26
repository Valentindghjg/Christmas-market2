--!strict
-- SaveSlotPicker: picker rows, save names, Save.Create/Rename/Delete and play/switch/leave.
-- Methods of SaveSlotService, merged by SaveSlotService.lua (CM2-RF).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local SaveSlotShared = require(script.Parent:WaitForChild("SaveSlotShared"))

local SaveSlotService: any = {}

local SAVES = GameConfig.Saves
local LEAVE_POLL_SECONDS = 0.1
local failure = SaveSlotShared.failure
local companyIdOf = SaveSlotShared.companyIdOf
local saveIdOf = SaveSlotShared.saveIdOf
local newEntry = SaveSlotShared.newEntry
local storedProfile = SaveSlotShared.storedProfile
local callHandler = SaveSlotShared.callHandler
-- Picker rows: seats per row; a Member row never carries the save name (filter rule, CM2-S2).
-- withLocations (Save.List only): co-op rows that another server plays carry elsewhere and
-- hostName.
function SaveSlotService:_listView(profile, activeSaveId: string?, withLocations: boolean?)
	local rows = SaveProfile.listView(profile, activeSaveId)
	local lookups = 0
	for _, row in ipairs(rows) do
		row.seats = SAVES.Seats[row.size]
		if row.role == "Member" then
			row.name = nil
			row.ownerName = self:_nameOf(SaveProfile.ownerUserIdOf(row.saveId))
		end
		if
			withLocations
			and self._locator ~= nil
			and lookups < SAVES.LocatorListLookups
			and not row.active
			and row.size ~= "Solo"
			and self._members[companyIdOf(row.saveId)] == nil
		then
			lookups += 1
			local location = self:_cachedLocation(row.saveId)
			if location then
				row.elsewhere = true
				row.hostName = self:_nameOf(location.hostUserId)
			end
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

-- Plot picker (CM2-PP) ----------------------------------------------------------------------

-- The save holds no plot here, nobody plays it here and no load or unload of it is in flight:
-- its first player on this server picks the plot.
function SaveSlotService:_needsPick(companyId: string): boolean
	return self._plots:getPlot(companyId) == nil
		and self._members[companyId] == nil
		and (self._pendingLoads[companyId] or 0) == 0
		and not self._unloading[companyId]
end

-- The holder is the caller's active save and the caller its only player here, with no load or
-- unload in flight: a switch releases its plot before the claim.
function SaveSlotService:_releasesOnLeave(userId: number, holder: string): boolean
	return holder == self._active[userId]
		and #self:playersOn(holder) == 1
		and (self._pendingLoads[holder] or 0) == 0
		and not self._unloading[holder]
end

function SaveSlotService:_plotFreeFor(userId: number, plotId: string): boolean
	if not self._plots:has(plotId) then
		return false
	end
	local holder = self._plots:holderOf(plotId)
	return holder == nil or self:_releasesOnLeave(userId, holder)
end

function SaveSlotService:_freeCountFor(userId: number): number
	local count = 0
	for _, plotId in ipairs(self._plots:plotIds()) do
		if self:_plotFreeFor(userId, plotId) then
			count += 1
		end
	end
	return count
end

-- The lot sign's public text of a plot; nil without a label lookup or for a bad value.
function SaveSlotService:_plotLabelOf(plotId: string): string?
	if self._plotLabel == nil then
		return nil
	end
	local called, label = pcall(self._plotLabel, plotId)
	if called and type(label) == "string" and #label >= 1 and #label <= 100 then
		return label
	end
	return nil
end

-- Save.Plots: the plot list for the picker, or pick = false when Save.Play attaches or takes
-- the automatic path. Nothing is reserved while the player browses.
function SaveSlotService:_plotChoices(userId: number, profile, payload)
	local saveId = payload.saveId
	local entry = SaveProfile.find(profile, saveId)
	if entry == nil then
		return failure("SaveNotFound")
	end
	local companyId = companyIdOf(saveId)
	local ids = self._plots:plotIds()
	if self._active[userId] == companyId or not self:_needsPick(companyId) or self:_freeCountFor(userId) == 0 then
		return { ok = true, data = { saveId = saveId, pick = false, total = #ids, plots = {} } }
	end
	local plots = {}
	local firstFree = nil
	for index, plotId in ipairs(ids) do
		local spot = MapLayout.PLOTS[index]
		local free = self:_plotFreeFor(userId, plotId)
		if free and firstFree == nil then
			firstFree = plotId
		end
		table.insert(plots, {
			plotId = plotId,
			number = index,
			side = if spot and spot.z < 0 then "South" else "North",
			free = free,
			name = if not free then self:_plotLabelOf(plotId) else nil,
		})
	end
	local lastPlotId = entry.lastPlotId
	local preselectId = if type(lastPlotId) == "string" and self:_plotFreeFor(userId, lastPlotId)
		then lastPlotId
		else firstFree
	return {
		ok = true,
		data = { saveId = saveId, pick = true, total = #ids, preselectId = preselectId, plots = plots },
	}
end

-- A chosen plot that cannot be had: InvalidPlotId for an id this server does not hold,
-- PlotTaken while another plot is free for the caller. nil lets the play go on (attach, the
-- chosen free plot, or the no-free-plot path).
function SaveSlotService:_plotRefusal(userId: number, companyId: string, plotId: string): string?
	if not self._plots:has(plotId) then
		return "InvalidPlotId"
	end
	if not self:_needsPick(companyId) then
		return nil
	end
	if self:_plotFreeFor(userId, plotId) then
		return nil
	end
	if self:_freeCountFor(userId) == 0 then
		return nil
	end
	return "PlotTaken"
end

-- A cm2NoFreePlot teleport arrival: the player picks a plot for this save, and the next
-- Save.Play of it carries the attempt, so MaxPlotTeleports still bounds the chain.
function SaveSlotService:noteArrival(userId: number, saveId: string, attempt: number)
	if not SaveProfile.isSaveId(saveId) then
		return
	end
	if
		type(attempt) ~= "number"
		or attempt ~= math.floor(attempt)
		or attempt < 1
		or attempt > SAVES.MaxPlotTeleports
	then
		return
	end
	self._arrivals[userId] = { saveId = saveId, attempt = attempt }
end

-- Play, switch and leave --------------------------------------------------------------------

-- Another player plays this save here and its session is live: join that session.
function SaveSlotService:_canAttach(companyId: string): boolean
	return self._companies:isAvailable(companyId) and self._members[companyId] ~= nil and not self._unloading[companyId]
end

-- Marks the save as played: lastPlayedAt, lastSaveId and the entry size from the record.
-- The owner of a Duo or larger save without a code gets one.
function SaveSlotService:_touch(userId: number, saveId: string, companyId: string, plotId: string)
	local info = self._companies:teamInfo(companyId)
	local now = self._clock()
	-- CM2-49: every owner play marks the player as offered the guided tutorial.
	local isOwner = self._companies:memberRole(companyId, userId) == "Owner"
	local _, touchError = self:_updateProfile(userId, function(stored)
		local currentProfile, storedError = storedProfile(stored)
		if not currentProfile then
			return nil, false, storedError
		end
		local stamped = SaveProfile.find(currentProfile, saveId)
		if stamped then
			stamped.lastPlayedAt = now
			-- CM2-PP: the plot the picker preselects next time.
			stamped.lastPlotId = plotId
			if info then
				stamped.size = info.saveSize
			end
		end
		currentProfile.lastSaveId = saveId
		if isOwner then
			currentProfile.tutorialOffered = true
		end
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
	self:_touch(userId, saveId, companyId, plotId)
	self:_activated(userId, saveId, companyId, plotId, nil, entry)
	return true, nil, { saveId = saveId, plotId = plotId }
end

-- Nobody plays, loads or unloads the save here and it has no session (Amendment A1.1).
function SaveSlotService:_idle(companyId: string): boolean
	return self._members[companyId] == nil
		and (self._pendingLoads[companyId] or 0) == 0
		and not self._unloading[companyId]
		and not self._companies:hasSession(companyId)
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
	-- CM2-PP: an obvious refusal of a chosen plot is decided before the current save is left.
	if settings.plotId ~= nil then
		local refusal = self:_plotRefusal(userId, companyId, settings.plotId)
		if refusal then
			return false, refusal, nil
		end
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
		-- CM2-R5: a healthy save that cannot be stored keeps the player on it.
		local _, leaveError = self:_leaveActive(userId, true)
		if leaveError == "SwitchSaveFailed" then
			return false, "SwitchSaveFailed", nil
		end
	end

	-- c. A failed shared session is evicted before the save loads again.
	if self._companies:isFailed(companyId) then
		self:_evict(companyId)
	end

	-- d. Attach to the live shared session.
	if self:_canAttach(companyId) then
		return self:_attach(userId, saveId, companyId, entry)
	end

	-- e. Claim the save-to-server map entry (CM2-S3), then the plot, and load (Amendment A3).
	local claimed, claimError, claimData = self:_claimLocation(saveId, companyId, userId, entry.size)
	if not claimed then
		return false, claimError, claimData
	end
	self._pendingLoads[companyId] = (self._pendingLoads[companyId] or 0) + 1
	local ownerUserId = SaveProfile.ownerUserIdOf(saveId) :: number
	local loadName = if entry.role == "Owner" then entry.name else nil
	-- CM2-49: only a fresh record of the first save a player owns starts the guided tutorial.
	local loadOptions = {
		saveSize = entry.size,
		requireExisting = entry.role == "Member",
		tutorial = entry.role == "Owner" and profile.tutorialOffered ~= true,
	}
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
			if settings.plotId ~= nil then
				-- CM2-PP: exactly the chosen plot; a taken one with none free goes on to the
				-- no-free-plot path below.
				local exactError
				plotId, exactError = self._plots:claimExact(companyId, settings.plotId)
				if not plotId and (exactError ~= "PlotTaken" or self._plots:freeCount() > 0) then
					self:_endLoad(companyId)
					if self:_idle(companyId) then
						self:_releaseLocation(saveId)
					end
					return false, if exactError == "PlotTaken" then "PlotTaken" else "InvalidPlotId", nil
				end
			else
				plotId = self._plots:claim(companyId, preferred)
			end
			if not plotId then
				self:_endLoad(companyId)
				-- Amendment A1.1: free the map entry before the player is sent on, so the next
				-- server's Play can claim it.
				if self:_idle(companyId) then
					self:_releaseLocation(saveId)
				end
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
		if self:_idle(companyId) then
			self._plots:release(companyId)
			self:_releaseLocation(saveId)
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
		self:_unloadShared(companyId, userId)
		self:_dropMemberEntry(userId, saveId)
		return false, "NotAMember", nil
	end

	-- g. The player left or the server began shutting down while the load yielded; nobody
	-- else will unload this session.
	if self._leaving[userId] or self._closing then
		local leaving = self._leaving[userId] == true
		self:_endLoad(companyId)
		self:_unloadShared(companyId, userId)
		return false, if leaving then "PlayerLeft" else "ServerShuttingDown", nil
	end

	-- h. Register, then mark the save as played.
	self:_register(userId, companyId)
	self:_endLoad(companyId)
	self:_touch(userId, saveId, companyId, plotId :: string)
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
-- abortOnFailure (CM2-R5, switch and Save.LeaveTeam): when the last player's final save of
-- a healthy session fails, the player stays registered on it and the result is
-- SwitchSaveFailed.
function SaveSlotService:_leaveActive(userId: number, abortOnFailure: boolean?): (boolean, string?)
	local ok, leaveError = true, nil
	local companyId = self._active[userId]
	if companyId then
		-- Before deregistering, so the carried-tree sync still reaches this player.
		self._companies:releaseCarried(companyId, userId)
		self:_deregister(userId, companyId)
		-- Computed before any yield, so a member attaching meanwhile cannot be missed.
		local last = self._members[companyId] == nil
		if last then
			self._unloading[companyId] = true
		end
		local plotId = self._plots:getPlot(companyId)
		local plotReleased = false
		if last then
			ok, leaveError, plotReleased = self:_unloadShared(companyId, userId, abortOnFailure)
			if leaveError == "UnloadAborted" then
				-- The session is live again; a finder listing removed by _deregister stays removed.
				self:_register(userId, companyId)
				return false, "SwitchSaveFailed"
			end
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
		-- CM2-S3: a listing never outlives its owner on this server.
		if self._listings[userId] ~= nil then
			self._listings[userId] = nil
			self:_listingsChanged()
		end
		for _, limiter in pairs(self._limiters) do
			Protocol.forgetUser(limiter, userId)
		end
		self._profiles[userId] = nil
		self._arrivals[userId] = nil
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

-- Studio test instrument only (StudioTestService, CM2-49): writes the tutorialOffered flag when
-- offered is a boolean and returns the resulting flag (the open profile's when offered is nil).
function SaveSlotService:tutorialOfferForTest(userId: number, offered: boolean?): (boolean?, string?)
	if type(offered) == "boolean" then
		local updated, updateError = self:_updateProfile(userId, function(stored)
			local currentProfile, storedError = storedProfile(stored)
			if not currentProfile then
				return nil, false, storedError
			end
			currentProfile.tutorialOffered = offered
			return currentProfile, true
		end)
		if not updated then
			return nil, updateError
		end
		return updated.tutorialOffered == true, nil
	end
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return nil, profileError
	end
	return profile.tutorialOffered == true, nil
end

return SaveSlotService
