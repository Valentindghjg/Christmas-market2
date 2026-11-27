--!strict
-- Advent calendar maths (CM2-A1, docs/plans/CM2-A1.md). Pure functions over the player profile
-- field `advent = { year, opened }` (bit d-1 = door d) and the save's `decorInventory`. Dates
-- come from integer maths on the server's UTC time, never os.date/os.time(table), whose time
-- zone differs between Roblox and Lune.
local EventConfig = require(script.Parent.EventConfig)
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.Advent

local AdventCalendar = {}

local DAY_SECONDS = 86400
local MAX_MASK = 2 ^ 24 - 1

export type Advent = { year: number, opened: number }
export type Date = { year: number, month: number, day: number }
export type View = { year: number, phase: string, today: number, opened: number, claimable: number }
export type Reward = { cash: number, reputation: number, boostSeconds: number, decor: string? }

local function isInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function isDoor(value: unknown): boolean
	return isInteger(value) and (value :: number) >= 1 and (value :: number) <= Config.LastDay
end

local function isDecorItem(value: unknown): boolean
	-- CM2-45: event decor shares the crate
	return type(value) == "string" and table.find(Config.DecorItems, value) ~= nil or EventConfig.isDecorItem(value)
end

local function doorBit(door: number): number
	return bit32.lshift(1, door - 1)
end

-- Hinnant days-from-civil: days since 1970-01-01 for a proleptic Gregorian date.
local function daysFromCivil(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = y // 400
	local yoe = y - era * 400
	local mp = if month > 2 then month - 3 else month + 9
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- Hinnant civil-from-days: the inverse of daysFromCivil.
local function civilFromDays(days: number): (number, number, number)
	local z = days + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local day = doy - (153 * mp + 2) // 5 + 1
	local month = if mp < 10 then mp + 3 else mp - 9
	local year = yoe + era * 400
	if month <= 2 then
		year += 1
	end
	return year, month, day
end

function AdventCalendar.utcTime(year: number, month: number, day: number, hour: number): number
	return daysFromCivil(year, month, day) * DAY_SECONDS + hour * 3600
end

function AdventCalendar.dateOf(now: number): Date
	local year, month, day = civilFromDays(math.floor(now) // DAY_SECONDS)
	return { year = year, month = month, day = day }
end

-- The stored mask for this year; another year counts as empty.
local function maskFor(advent: any, year: number): number
	if type(advent) == "table" and advent.year == year and isInteger(advent.opened) then
		return advent.opened
	end
	return 0
end

function AdventCalendar.view(advent: any, now: number): View
	local date = AdventCalendar.dateOf(now)
	local phase, today = "Before", 0
	if date.month == Config.Month and date.day <= Config.LastDay then
		phase, today = "Open", date.day
	elseif date.month == Config.Month then
		phase = "Ended"
	end
	local opened = maskFor(advent, date.year)
	local claimable = 0
	for door = 1, today do
		if bit32.band(opened, doorBit(door)) == 0 then
			claimable += 1
		end
	end
	return { year = date.year, phase = phase, today = today, opened = opened, claimable = claimable }
end

function AdventCalendar.open(advent: any, now: number, door: unknown): (any?, string?)
	if not isDoor(door) then
		return nil, "InvalidDoor"
	end
	local doorNumber = door :: number
	local current = AdventCalendar.view(advent, now)
	if current.phase ~= "Open" then
		return nil, "CalendarClosed"
	end
	if doorNumber > current.today then
		return nil, "DoorLocked"
	end
	local bit = doorBit(doorNumber)
	if bit32.band(current.opened, bit) ~= 0 then
		return nil, "AlreadyClaimed"
	end
	return { year = current.year, opened = bit32.bor(current.opened, bit) }, nil
end

function AdventCalendar.rewardFor(door: number): Reward
	local entry = Config.Doors[door] :: any
	return {
		cash = entry.cash or 0,
		reputation = entry.reputation or 0,
		boostSeconds = entry.boostSeconds or 0,
		decor = entry.decor,
	}
end

-- nil (never opened) or exactly { year: integer 2000..9999, opened: integer 0..2^24-1 }.
function AdventCalendar.isValid(advent: any): boolean
	if advent == nil then
		return true
	end
	if type(advent) ~= "table" then
		return false
	end
	for key in pairs(advent) do
		if key ~= "year" and key ~= "opened" then
			return false
		end
	end
	return isInteger(advent.year)
		and advent.year >= 2000
		and advent.year <= 9999
		and isInteger(advent.opened)
		and advent.opened >= 0
		and advent.opened <= MAX_MASK
end

-- Schema 22: { [DecorItems id]: integer 1..DecorMaxCount }.
function AdventCalendar.isDecorInventory(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, count in pairs(value :: { [unknown]: unknown }) do
		if not isDecorItem(key) then
			return false
		end
		if not isInteger(count) or (count :: number) < 1 or (count :: number) > Config.DecorMaxCount then
			return false
		end
	end
	return true
end

return AdventCalendar
