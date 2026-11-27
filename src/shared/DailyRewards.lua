--!strict
-- Daily reward streak maths (CM2-G11, docs/archive/plans/CM2-G11.md). Pure functions over the player
-- profile field `daily = { lastDay, streak }`; the server's UTC day decides the streak.
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.DailyRewards

local DailyRewards = {}

export type Daily = { lastDay: number, streak: number }
export type Status = { claimable: boolean, nextIndex: number }
export type Reward = { cash: number, reputation: number, doubled: boolean }

local function isInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

function DailyRewards.dayOf(now: number): number
	return math.floor(now / Config.DaySeconds)
end

function DailyRewards.secondsLeft(now: number): number
	return Config.DaySeconds - (math.floor(now) % Config.DaySeconds)
end

-- nil (never claimed) or exactly { lastDay: integer >= 0, streak: integer 1..#Days }.
function DailyRewards.isValid(daily: any): boolean
	if daily == nil then
		return true
	end
	if type(daily) ~= "table" then
		return false
	end
	for key in pairs(daily) do
		if key ~= "lastDay" and key ~= "streak" then
			return false
		end
	end
	return isInteger(daily.lastDay)
		and daily.lastDay >= 0
		and isInteger(daily.streak)
		and daily.streak >= 1
		and daily.streak <= #Config.Days
end

function DailyRewards.status(daily: any, today: number): Status
	if daily == nil then
		return { claimable = true, nextIndex = 1 }
	end
	local following = daily.streak % #Config.Days + 1
	if daily.lastDay >= today then
		return { claimable = false, nextIndex = following }
	end
	if daily.lastDay == today - 1 then
		return { claimable = true, nextIndex = following }
	end
	return { claimable = true, nextIndex = 1 }
end

function DailyRewards.claim(daily: any, today: number): (any?, number | string)
	local status = DailyRewards.status(daily, today)
	if not status.claimable then
		return nil, "AlreadyClaimed"
	end
	return { lastDay = today, streak = status.nextIndex }, status.nextIndex
end

function DailyRewards.rewardFor(index: number, member: boolean): Reward
	local day = Config.Days[index]
	local factor = if member then Config.GroupMultiplier else 1
	return { cash = day.cash * factor, reputation = day.reputation * factor, doubled = member }
end

function DailyRewards.groupState(groupId: number, member: boolean): string
	if groupId == 0 then
		return "Hidden"
	end
	return if member then "Active" else "Join"
end

return DailyRewards
