--!strict
-- SaveSlotCrossServer: save-to-server map, Save.Teleport/arrive and the teammate finder (CM2-S3).
-- Methods of SaveSlotService, merged by SaveSlotService.lua (CM2-RF).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local SaveSlotShared = require(script.Parent:WaitForChild("SaveSlotShared"))

local SaveSlotService: any = {}

local SAVES = GameConfig.Saves
local failure = SaveSlotShared.failure
local companyIdOf = SaveSlotShared.companyIdOf
local saveIdOf = SaveSlotShared.saveIdOf
local sortedKeys = SaveSlotShared.sortedKeys
-- Save-to-server map (CM2-S3) ------------------------------------------------------------------

-- The location of a save played on another server, cached for LocatorCacheSeconds. A lookup
-- error caches "unknown" (false) as well, so a store outage does not cost a call per row.
function SaveSlotService:_cachedLocation(saveId: string)
	local now = self._clock()
	local cached = self._locationCache[saveId]
	if cached ~= nil and now - cached.at < SAVES.LocatorCacheSeconds then
		return if cached.location then cached.location else nil
	end
	local location = self._locator:lookup(saveId)
	self._locationCache[saveId] = { at = now, location = location or false }
	return location
end

-- "X" of "Being played by X": the owner when they play the save on this server, else the
-- registered player who has played it here longest.
function SaveSlotService:_hostOf(companyId: string): number?
	local members = self._members[companyId]
	if members == nil then
		return nil
	end
	local ownerUserId = SaveProfile.ownerUserIdOf(saveIdOf(companyId))
	if ownerUserId ~= nil and members[ownerUserId] then
		return ownerUserId
	end
	local host, hostSince = nil, nil
	for userId in pairs(members) do
		local since = self._since[userId]
		if since ~= nil and (hostSince == nil or since < hostSince) then
			host, hostSince = userId, since
		end
	end
	return host
end

-- Pre-check before a load: refuses when another live server holds the save. Fails open: a
-- store error lets the load go on, and the session lock decides.
function SaveSlotService:_claimLocation(saveId: string, companyId: string, userId: number, saveSize: string)
	if self._locator == nil then
		return true, nil, nil
	end
	local outcome, location = self._locator:claim(saveId, self:_hostOf(companyId) or userId)
	self._locationCache[saveId] = nil
	if outcome == "HeldElsewhere" then
		if saveSize == "Solo" then
			-- Its only player is this one, so the other session is stale.
			return false, "SaveInUse", nil
		end
		return false, "SaveInUseElsewhere", { hostName = self:_nameOf(location.hostUserId) }
	end
	if outcome == "Unavailable" then
		warn(string.format("[ChristmasMarket2] save locator unavailable for %s; loading under the lock", saveId))
	end
	return true, nil, nil
end

function SaveSlotService:_releaseLocation(saveId: string?)
	if self._locator == nil or saveId == nil then
		return
	end
	self._locator:release(saveId)
	self._locationCache[saveId] = nil
end

-- Drops the cached lookup (Studio test instrument after a direct map write).
function SaveSlotService:forgetLocation(saveId: string)
	self._locationCache[saveId] = nil
end

-- Renews the entry of every save played here (main runs it every LocatorRenewSeconds).
function SaveSlotService:renewLocations(): (boolean, number, number)
	if self._locator == nil then
		return true, 0, 0
	end
	local renewed, failures = 0, 0
	local companyIds = {}
	for companyId in pairs(self._members) do
		table.insert(companyIds, companyId)
	end
	table.sort(companyIds)
	for _, companyId in ipairs(companyIds) do
		local saveId = saveIdOf(companyId)
		local host = self:_hostOf(companyId)
		if saveId ~= nil and host ~= nil and not self._unloading[companyId] then
			local outcome = self._locator:claim(saveId, host)
			self._locationCache[saveId] = nil
			if outcome == "Claimed" then
				renewed += 1
			else
				if outcome == "HeldElsewhere" then
					warn(string.format("[ChristmasMarket2] save %s is located on another server", saveId))
				end
				failures += 1
			end
		end
	end
	return failures == 0, renewed, failures
end

-- Cross-server join (CM2-S3) ---------------------------------------------------------------------

-- Save.Teleport {saveId | code}: sends the player to the server that plays the save. The code
-- path has the same lockout and wrong-code count as Save.Join.
function SaveSlotService:_teleportToSave(userId: number, profile, payload)
	if self._locator == nil then
		return failure("TeleportUnavailable")
	end
	local saveId = payload.saveId
	if payload.code ~= nil then
		if self:_joinLocked(userId) then
			return failure("JoinLocked")
		end
		if #profile.saves >= SAVES.MaxSavesPerPlayer then
			return failure("SaveLimit")
		end
		local found, lookupError = self._invites:lookup(payload.code)
		if not found then
			if lookupError == "InviteCodeInvalid" then
				self:_recordJoinFailure(userId)
			end
			return failure(lookupError)
		end
		saveId = found
	elseif SaveProfile.find(profile, saveId) == nil then
		return failure("SaveNotFound")
	end
	if self._members[companyIdOf(saveId)] ~= nil then
		return failure("SaveNotElsewhere")
	end
	local location, lookupError = self._locator:lookup(saveId)
	self._locationCache[saveId] = { at = self._clock(), location = location or false }
	if lookupError then
		return failure("TeleportFailed")
	end
	if location == nil then
		return failure("SaveNotElsewhere")
	end
	local sent, sendError =
		self._teleportToServer(userId, location.placeId, location.jobId, { saveId = saveId, code = payload.code })
	if not sent then
		return failure(if sendError == "TeleportUnavailable" then "TeleportUnavailable" else "TeleportFailed")
	end
	return { ok = true, data = { teleporting = true } }
end

-- Arrival from Save.Teleport. data = {saveId, code?} is shape-checked by main and trusted for
-- nothing: Play needs the profile entry, and a code goes through the Save.Join checks.
function SaveSlotService:_arrive(userId: number, data): (boolean, string?, any)
	local profile, profileError = self:_openProfile(userId)
	if not profile then
		return false, profileError, nil
	end
	local saveId = data.saveId
	if data.code ~= nil then
		if self:_joinLocked(userId) then
			return false, "JoinLocked", nil
		end
		local joined = self:_join(userId, profile, { code = data.code })
		if not joined.ok then
			return false, joined.errorCode, nil
		end
		-- The code wins over data.saveId.
		saveId = joined.data.saveId
	end
	return self:_play(userId, saveId, nil)
end

function SaveSlotService:arrive(userId: number, data): (boolean, string?, any)
	if self._closing then
		return false, "ServerShuttingDown", nil
	end
	if self._busy[userId] then
		return false, "SaveActionBusy", nil
	end
	self._busy[userId] = true
	local called, arrived, arriveError, result = pcall(self._arrive, self, userId, data)
	self._busy[userId] = nil
	self:_runPendingKick(userId)
	if not called then
		warn(string.format("[ChristmasMarket2] arrival failed for %d: %s", userId, tostring(arrived)))
		return false, "InternalError", nil
	end
	return arrived, arriveError, result
end

-- Teammate finder (CM2-S3) -----------------------------------------------------------------------

-- A listing stays valid while its owner plays the owned co-op save here with a free seat.
-- An invalid listing is removed. Returns (listing, info) or nil.
function SaveSlotService:_validListing(ownerUserId: number)
	local listing = self._listings[ownerUserId]
	if listing == nil then
		return nil, nil
	end
	local companyId = listing.companyId
	local info = nil
	if
		self._active[ownerUserId] == companyId
		and self._companies:isAvailable(companyId)
		and self._companies:memberRole(companyId, ownerUserId) == "Owner"
	then
		info = self._companies:teamInfo(companyId)
	end
	if
		info == nil
		or info.saveSize == "Solo"
		or BusinessState.memberCount(info) >= (SAVES.Seats[info.saveSize] or 0)
	then
		self._listings[ownerUserId] = nil
		self:_listingsChanged()
		return nil, nil
	end
	return listing, info
end

-- The active save qualifies for a listing: owned, healthy, co-op, with a free seat.
function SaveSlotService:_listableActive(userId: number): string?
	local companyId = self._active[userId]
	if companyId == nil or not self._companies:isAvailable(companyId) then
		return nil
	end
	if self._companies:memberRole(companyId, userId) ~= "Owner" then
		return nil
	end
	local info = self._companies:teamInfo(companyId)
	if
		info == nil
		or info.saveSize == "Solo"
		or BusinessState.memberCount(info) >= (SAVES.Seats[info.saveSize] or 0)
	then
		return nil
	end
	return companyId
end

function SaveSlotService:_list(userId: number, companyId: string)
	self._listings[userId] = { saveId = saveIdOf(companyId), companyId = companyId, createdAt = self._clock() }
	self:_listingsChanged()
end

function SaveSlotService:_finderStart(userId: number, payload)
	local own = self:_validListing(userId)
	if own ~= nil then
		return { ok = true, data = { saveId = own.saveId, created = false } }
	end
	local active = self:_listableActive(userId)
	if active ~= nil then
		self:_list(userId, active)
		return { ok = true, data = { saveId = saveIdOf(active), created = false } }
	end
	self._finderSeq += 1
	local created = self:_create(userId, {
		requestId = string.format("finder_%d_%d_%d", userId, self._clock(), self._finderSeq),
		payload = { size = payload.size or SAVES.FinderDefaultSize },
	})
	if not created.ok then
		return created
	end
	local newSaveId = created.data.saveId
	local played, playError = self:_play(userId, newSaveId, nil)
	if not played then
		return failure(playError)
	end
	self:_list(userId, companyIdOf(newSaveId))
	return { ok = true, data = { saveId = newSaveId, created = true } }
end

function SaveSlotService:_finderStop(userId: number)
	if self._listings[userId] ~= nil then
		self._listings[userId] = nil
		self:_listingsChanged()
	end
	return { ok = true, data = { stopped = true } }
end

-- Listings on this server without save names; the requester's own listing and saves the
-- requester already sits on are left out.
function SaveSlotService:_finderList(userId: number)
	local requesterKey = SaveProfile.userIdText(userId)
	local rows = {}
	local ownSaveId = nil
	for _, ownerUserId in ipairs(sortedKeys(self._listings)) do
		local listing, info = self:_validListing(ownerUserId)
		if listing ~= nil and info ~= nil then
			if ownerUserId == userId then
				ownSaveId = listing.saveId
			elseif info.members[requesterKey] == nil then
				table.insert(rows, {
					saveId = listing.saveId,
					ownerUserId = ownerUserId,
					ownerName = self:_nameOf(ownerUserId),
					size = info.saveSize,
					seats = SAVES.Seats[info.saveSize],
					taken = BusinessState.memberCount(info),
					createdAt = listing.createdAt,
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.createdAt ~= b.createdAt then
			return a.createdAt < b.createdAt
		end
		return a.ownerUserId < b.ownerUserId
	end)
	for _, row in ipairs(rows) do
		row.createdAt = nil
	end
	return { ok = true, data = { listings = rows, ownSaveId = ownSaveId } }
end

function SaveSlotService:_finderJoin(userId: number, profile, payload)
	local saveId = payload.saveId
	local ownerUserId = nil
	for listedOwner, listing in pairs(self._listings) do
		if listing.saveId == saveId then
			ownerUserId = listedOwner
		end
	end
	if ownerUserId == nil or self:_validListing(ownerUserId) == nil then
		return failure("ListingGone")
	end
	if ownerUserId == userId then
		return failure("OwnListing")
	end
	local joined = self:_joinSave(userId, profile, saveId, nil)
	if not joined.ok then
		return joined
	end
	local played, playError, data = self:_play(userId, saveId, nil)
	if not played then
		return failure(playError)
	end
	-- A full save stops being listed.
	self:_validListing(ownerUserId)
	return { ok = true, data = { saveId = saveId, plotId = data.plotId } }
end

return SaveSlotService
