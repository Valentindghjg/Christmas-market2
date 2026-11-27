--!strict
-- Event shop calendar (CM2-45, docs/plans/CM2-45.md): which EventConfig event is open at a
-- UTC time, the client's countdown parts, and the shape check of the save field
-- `eventPurchases = { [eventId]: { [itemKey]: count } }` (schema 23). Pure functions; dates
-- are fixed integers in EventConfig, never os.date.
local EventConfig = require(script.Parent.EventConfig)

local EventCalendar = {}

export type View = { id: string, titleKey: string, endsIn: number }

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isInteger(value: unknown): boolean
	return isFinite(value) and (value :: number) == math.floor(value :: number)
end

-- A letter, then letters or digits, at most 32 bytes (the format only, never the config).
local function isKey(value: unknown): boolean
	return type(value) == "string" and #value <= 32 and string.match(value, "^%a%w*$") ~= nil
end

-- The event with startsAt <= now < endsAt; nil outside every window and for NaN or inf.
function EventCalendar.active(now: number): EventConfig.Event?
	if not isFinite(now) then
		return nil
	end
	for _, event in ipairs(EventConfig.Events) do
		if event.startsAt <= now and now < event.endsAt then
			return event
		end
	end
	return nil
end

-- The open event's id, title key and whole seconds left; {"", "", 0} without one.
function EventCalendar.view(now: number): View
	local event = EventCalendar.active(now)
	if event == nil then
		return { id = "", titleKey = "", endsIn = 0 }
	end
	return { id = event.id, titleKey = event.titleKey, endsIn = math.max(0, math.ceil(event.endsAt - now)) }
end

-- The event's cash item with this key, or nil.
function EventCalendar.item(event: EventConfig.Event, key: unknown): EventConfig.Item?
	if type(key) ~= "string" then
		return nil
	end
	for _, entry in ipairs(event.items) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- The countdown's localization key and two numbers: days and hours, hours and minutes, or
-- minutes and seconds. Negative, NaN and inf count as 0.
function EventCalendar.countdown(seconds: number): (string, number, number)
	local left = if isFinite(seconds) and seconds > 0 then math.floor(seconds) else 0
	if left >= 86400 then
		return "eventEndsDays", left // 86400, (left % 86400) // 3600
	end
	if left >= 3600 then
		return "eventEndsHours", left // 3600, (left % 3600) // 60
	end
	return "eventEndsMinutes", left // 60, left % 60
end

-- Schema 23: at most MaxEvents events of at most MaxItemsPerEvent items, keys by format,
-- counts integers 1..MaxBuyCount.
function EventCalendar.isPurchases(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local events = 0
	for eventId, items in pairs(value :: { [unknown]: unknown }) do
		events += 1
		if events > EventConfig.MaxEvents or not isKey(eventId) or type(items) ~= "table" then
			return false
		end
		local count = 0
		for itemKey, bought in pairs(items :: { [unknown]: unknown }) do
			count += 1
			if count > EventConfig.MaxItemsPerEvent or not isKey(itemKey) then
				return false
			end
			if not isInteger(bought) or (bought :: number) < 1 or (bought :: number) > EventConfig.MaxBuyCount then
				return false
			end
		end
	end
	return true
end

return EventCalendar
