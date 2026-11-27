--!strict
-- Day/night clock maths of one save (CM2-G12a, docs/archive/plans/CM2-G12a.md). Pure functions over the
-- saved `dayCycle = { day, elapsed }` (schema 20): the server advances it while the save is
-- loaded and the client turns the synced elapsed time into the sky and the night lights.
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.DayCycle

local DayCycle = {}

export type Cycle = { day: number, elapsed: number }

local function length(): number
	return Config.DaySeconds + Config.NightSeconds
end

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function DayCycle.new(): Cycle
	return { day = 1, elapsed = 0 }
end

function DayCycle.length(): number
	return length()
end

function DayCycle.isValid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local day, elapsed = value.day, value.elapsed
	if not isFinite(day) or day ~= math.floor(day) or day < 1 then
		return false
	end
	return type(elapsed) == "number" and elapsed == elapsed and elapsed >= 0 and elapsed < length()
end

-- Wraps an elapsed time past the end of the day back into the day; nothing else changes.
function DayCycle.normalize(state: any)
	local cycle = state.dayCycle
	if type(cycle) == "table" and isFinite(cycle.elapsed) and cycle.elapsed >= length() then
		cycle.elapsed = cycle.elapsed % length()
	end
end

-- Adds at most MaxTickSeconds and returns the number of days rolled over.
function DayCycle.advance(cycle: Cycle, seconds: number): number
	if not isFinite(seconds) or seconds <= 0 then
		return 0
	end
	cycle.elapsed += math.min(seconds, Config.MaxTickSeconds)
	local added = 0
	while cycle.elapsed >= length() do
		cycle.elapsed -= length()
		cycle.day += 1
		added += 1
	end
	return added
end

function DayCycle.isNight(elapsed: number): boolean
	return elapsed >= Config.DaySeconds
end

function DayCycle.arrivalRate(elapsed: number): number
	return if DayCycle.isNight(elapsed) then Config.NightArrivalRate else 1
end

function DayCycle.clockTime(elapsed: number): number
	local dayStart, nightStart = Config.DayStartClockTime, Config.NightStartClockTime
	if elapsed < Config.DaySeconds then
		return dayStart + (nightStart - dayStart) * elapsed / Config.DaySeconds
	end
	return (nightStart + (24 - (nightStart - dayStart)) * (elapsed - Config.DaySeconds) / Config.NightSeconds) % 24
end

-- 1 at full night, 0 by day; ramps over TwilightSeconds after dusk and after dawn.
function DayCycle.nightBlend(elapsed: number): number
	local twilight = Config.TwilightSeconds
	if elapsed < twilight then
		return 1 - elapsed / twilight
	end
	if elapsed < Config.DaySeconds then
		return 0
	end
	return math.min(1, (elapsed - Config.DaySeconds) / twilight)
end

function DayCycle.lightsOn(elapsed: number): boolean
	return DayCycle.nightBlend(elapsed) > 0
end

-- The client's elapsed time from the last server sync.
function DayCycle.extrapolate(syncElapsed: number, syncAt: number, now: number): number
	return (syncElapsed + math.max(0, now - syncAt)) % length()
end

return DayCycle
