--!strict
-- SaveSlotTeam: co-op records, invite codes, Save.Join/LeaveTeam and team management.
-- Methods of SaveSlotService, merged by SaveSlotService.lua (CM2-RF).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local SaveSlotShared = require(script.Parent:WaitForChild("SaveSlotShared"))

local SaveSlotService: any = {}

local SAVES = GameConfig.Saves
-- Rate-limiter key for wrong invite codes; the server-wide limiter counts them under user 0.
local JOIN_FAILURE_ACTION = "fail"
local SERVER_LIMITER_USER = 0
-- Internal refusal so a Join by a member (or the owner) writes nothing.
local ALREADY_MEMBER = "AlreadyMember"

-- Join outcomes that all look like a wrong code to the player and count toward the lockout.
local JOIN_INVALID = { InviteCodeInvalid = true, SaveDeleted = true, SaveNotFound = true }
-- LeaveTeam: these record results mean the seat is already free.
local LEAVE_DONE = { NotAMember = true, SaveDeleted = true, SaveNotFound = true }
local failure = SaveSlotShared.failure
local companyIdOf = SaveSlotShared.companyIdOf
local saveIdOf = SaveSlotShared.saveIdOf
local storedProfile = SaveSlotShared.storedProfile
local callHandler = SaveSlotShared.callHandler

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
	return self:_joinSave(userId, profile, saveId, code)
end

-- Takes a seat on a save: with the typed code (Save.Join), or without one for a trusted
-- caller (the teammate finder, code == nil).
function SaveSlotService:_joinSave(userId: number, profile, saveId: string, code: string?)
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
			if code == nil then
				return failure("ListingGone")
			end
			self:_recordJoinFailure(userId)
			return failure("InviteCodeInvalid")
		end
		-- CM2-S3: another server plays the save; offer that server (not a wrong code).
		if changeError == "SaveInUse" and self._locator ~= nil then
			local location = self._locator:lookup(saveId)
			if location then
				return {
					ok = false,
					errorCode = "SaveInUseElsewhere",
					data = { hostName = self:_nameOf(location.hostUserId) },
				}
			end
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
		local _, leaveError = self:_leaveActive(userId, true)
		if leaveError == "SwitchSaveFailed" then
			return failure("SwitchSaveFailed")
		end
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

return SaveSlotService
