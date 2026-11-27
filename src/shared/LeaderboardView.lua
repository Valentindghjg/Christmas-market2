--!strict
-- Pure leaderboard view helpers (CM2-G12b, docs/archive/plans/CM2-G12b.md): sanitizes the published
-- rows from `ReplicatedStorage.Leaderboards` and formats a board's value per board key.
local GameConfig = require(script.Parent.GameConfig)
local UiTheme = require(script.Parent.UiTheme)

local LeaderboardView = {}

local Config = GameConfig.Leaderboards

export type Row = { rank: number, name: string?, value: number }

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Keeps entries with an integer rank 1..TopCount (first per rank) and a finite value >= 0; a
-- name stays only when it is a string of 1..NameMaxLength chars. Sorted by rank.
function LeaderboardView.rows(decoded: any): { Row }
	local result: { Row } = {}
	if type(decoded) ~= "table" then
		return result
	end
	local seen: { [number]: boolean } = {}
	for _, entry in ipairs(decoded) do
		if type(entry) == "table" then
			local rank = entry.rank
			local value = entry.value
			if
				isFinite(rank)
				and rank == math.floor(rank)
				and rank >= 1
				and rank <= Config.TopCount
				and not seen[rank]
				and isFinite(value)
				and value >= 0
			then
				seen[rank] = true
				local name = entry.name
				local keptName: string? = nil
				if type(name) == "string" and #name >= 1 and #name <= Config.NameMaxLength then
					keptName = name
				end
				table.insert(result, { rank = rank, name = keptName, value = value })
			end
		end
	end
	table.sort(result, function(a: Row, b: Row): boolean
		return a.rank < b.rank
	end)
	return result
end

-- The localization key and its argument for a board's value.
function LeaderboardView.valueText(boardKey: string, value: number): (string, string)
	if boardKey == "CashEarned" then
		return "hudCash", UiTheme.formatMoney(value)
	elseif boardKey == "Reputation" then
		return "lbReputation", UiTheme.formatMoney(value)
	elseif boardKey == "HoursPlayed" then
		return "lbHours", string.format("%.1f", value / 3600)
	end
	return "lbRobux", UiTheme.formatMoney(value)
end

-- "4" for an integer rank >= 1, else nil.
function LeaderboardView.rankText(rank: any): string?
	if isFinite(rank) and rank == math.floor(rank) and rank >= 1 then
		return tostring(rank)
	end
	return nil
end

return LeaderboardView
