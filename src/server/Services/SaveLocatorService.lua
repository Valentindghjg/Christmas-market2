--!strict
-- Save-to-server map (CM2-S3): which live server plays a save, over a MemoryStore HashMap.
-- A locator and a pre-check only: the DataStore session lock stays the only authority for
-- writing a save, so a wrong or missing entry can send a player to the wrong place but never
-- create a second writer. Every call fails open: it never throws, and a store error is
-- reported as "Unavailable" / "LocatorUnavailable" after LocatorAttempts tries.
--
-- Everything is injected (no GetService), so tests use a fake map.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local SaveLocatorService = {}
SaveLocatorService.__index = SaveLocatorService

local SAVES = GameConfig.Saves
local JOB_ID_MAX_BYTES = 64

function SaveLocatorService.keyFor(saveId: string): string
	return "save:" .. saveId
end

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value == math.floor(value)
		and (value :: number) >= 1
end

-- A stored value: a jobId string of 1-64 bytes and a positive integer placeId. A held value
-- (no releasedAt) also has a positive integer hostUserId.
local function valid(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local entry = value :: any
	if type(entry.jobId) ~= "string" or #entry.jobId < 1 or #entry.jobId > JOB_ID_MAX_BYTES then
		return false
	end
	if not isPositiveInteger(entry.placeId) then
		return false
	end
	if entry.releasedAt == nil and not isPositiveInteger(entry.hostUserId) then
		return false
	end
	return true
end

local function isHeld(value: unknown): boolean
	return valid(value) and (value :: any).releasedAt == nil
end

function SaveLocatorService.new(map, jobId: string, placeId: number, clock, wait)
	local self = setmetatable({}, SaveLocatorService)
	self._map = map
	self._jobId = jobId
	self._placeId = placeId
	self._clock = clock
	self._wait = wait
	return self
end

-- Runs operation up to LocatorAttempts times with a 1 s wait between tries; never throws.
function SaveLocatorService:_attempt(operation): (boolean, any)
	local lastError: any = nil
	for attempt = 1, SAVES.LocatorAttempts do
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < SAVES.LocatorAttempts then
			pcall(self._wait, 1)
		end
	end
	return false, lastError
end

-- Claims (or renews) the save for this server. Another live server's held entry is never
-- overwritten. Returns "Claimed", "HeldElsewhere" with {jobId, placeId, hostUserId}, or
-- "Unavailable" after a store error.
function SaveLocatorService:claim(saveId: string, hostUserId: number): (string, any)
	local location = nil
	local ok, err = self:_attempt(function()
		self._map:UpdateAsync(SaveLocatorService.keyFor(saveId), function(previous)
			-- The transform can run more than once; reset its results first.
			location = nil
			if isHeld(previous) and previous.jobId ~= self._jobId then
				location = {
					jobId = previous.jobId,
					placeId = previous.placeId,
					hostUserId = previous.hostUserId,
				}
				return nil
			end
			return {
				jobId = self._jobId,
				placeId = self._placeId,
				hostUserId = hostUserId,
				renewedAt = self._clock(),
			}
		end, SAVES.LocatorTtlSeconds)
	end)
	if not ok then
		warn(string.format("[ChristmasMarket2] save locator claim failed for %s: %s", saveId, tostring(err)))
		return "Unavailable", nil
	end
	if location ~= nil then
		return "HeldElsewhere", location
	end
	return "Claimed", nil
end

-- Turns this server's held entry into a short-lived tombstone, which counts as free.
-- Returns true only when this server's entry was released.
function SaveLocatorService:release(saveId: string): boolean
	local released = false
	local ok, err = self:_attempt(function()
		self._map:UpdateAsync(SaveLocatorService.keyFor(saveId), function(previous)
			released = false
			if not isHeld(previous) or previous.jobId ~= self._jobId then
				return nil
			end
			released = true
			return { jobId = self._jobId, placeId = self._placeId, releasedAt = self._clock() }
		end, SAVES.LocatorReleasedTtlSeconds)
	end)
	if not ok then
		warn(string.format("[ChristmasMarket2] save locator release failed for %s: %s", saveId, tostring(err)))
		return false
	end
	return released
end

-- The other server in this place that holds the save, or nil. A store error returns
-- nil, "LocatorUnavailable".
function SaveLocatorService:lookup(saveId: string): (any, string?)
	local ok, value = self:_attempt(function()
		return self._map:GetAsync(SaveLocatorService.keyFor(saveId))
	end)
	if not ok then
		warn(string.format("[ChristmasMarket2] save locator lookup failed for %s: %s", saveId, tostring(value)))
		return nil, "LocatorUnavailable"
	end
	if not isHeld(value) or value.jobId == self._jobId or value.placeId ~= self._placeId then
		return nil, nil
	end
	return { jobId = value.jobId, placeId = value.placeId, hostUserId = value.hostUserId }, nil
end

return SaveLocatorService
