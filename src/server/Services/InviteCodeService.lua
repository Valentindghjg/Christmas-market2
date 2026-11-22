--!strict
-- Invite-code index for co-op saves (CM2-S2). Key `invite:<code>` (12 chars) holds
-- `{saveId, issuedAt}` while a save holds the code and the tombstone `{freedAt}` after release.
--
-- The map is only an index: the company record's `inviteCode` is the authority. A join is
-- valid only when the record's code equals the typed code, so a stale map entry is harmless.
-- Every read and write is one UpdateAsync; a read returns nil from its transform, so nothing
-- is written.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))

local InviteCodeService = {}
InviteCodeService.__index = InviteCodeService

InviteCodeService.STORE_NAME = "ChristmasMarket2_Invites_v1"

local ATTEMPTS = 3

function InviteCodeService.keyFor(code: string): string
	return "invite:" .. code
end

function InviteCodeService.new(store, clock, wait, randomCode)
	local self = setmetatable({}, InviteCodeService)
	self._store = store
	self._clock = clock
	self._wait = wait
	self._randomCode = randomCode
	return self
end

-- One UpdateAsync with 3 attempts; waits 1 s and then 2 s between them.
function InviteCodeService:_update(key: string, transform): boolean
	for attempt = 1, ATTEMPTS do
		local called = pcall(function()
			self._store:UpdateAsync(key, transform)
		end)
		if called then
			return true
		end
		if attempt < ATTEMPTS then
			self._wait(attempt)
		end
	end
	return false
end

-- Claims a free code for the save. Returns (code, nil) or (nil, "InviteCodeUnavailable").
-- A drawn code equal to `exclude` (the save's current code) counts as taken: it uses one
-- attempt and makes no store call (Amendment A2).
function InviteCodeService:claim(saveId: string, exclude: string?): (string?, string?)
	for _ = 1, GameConfig.Saves.InviteClaimAttempts do
		local code = string.format("%d", self._randomCode())
		if code == exclude then
			continue
		end
		local claimed = false
		local updated = self:_update(InviteCodeService.keyFor(code), function(previous)
			claimed = false
			if previous == nil or (type(previous) == "table" and previous.saveId == nil) then
				claimed = true
				return { saveId = saveId, issuedAt = self._clock() }
			end
			if type(previous) == "table" and previous.saveId == saveId then
				-- Already ours: success without a write.
				claimed = true
				return nil
			end
			return nil
		end)
		if not updated then
			return nil, "InviteCodeUnavailable"
		end
		if claimed then
			return code, nil
		end
	end
	return nil, "InviteCodeUnavailable"
end

-- Frees the code only when this save still holds it.
function InviteCodeService:release(code: string?, saveId: string): boolean
	if type(code) ~= "string" then
		return false
	end
	local released = false
	local updated = self:_update(InviteCodeService.keyFor(code), function(previous)
		released = false
		if type(previous) == "table" and previous.saveId == saveId then
			released = true
			return { freedAt = self._clock() }
		end
		return nil
	end)
	return updated and released
end

-- The save holding the code, or nil plus "InviteCodeInvalid" (unknown or freed) or
-- "LoadFailed" (store error).
function InviteCodeService:lookup(code: string): (string?, string?)
	local found = nil
	local updated = self:_update(InviteCodeService.keyFor(code), function(previous)
		found = nil
		if type(previous) == "table" and SaveProfile.isSaveId(previous.saveId) then
			found = previous.saveId
		end
		return nil
	end)
	if not updated then
		return nil, "LoadFailed"
	end
	if found == nil then
		return nil, "InviteCodeInvalid"
	end
	return found, nil
end

return InviteCodeService
