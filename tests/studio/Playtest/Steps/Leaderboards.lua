--!strict
-- Playtest steps 62-63 (full mode): leaderboards (CM2-G12b, docs/archive/plans/CM2-G12b.md).
-- Installed by RunPlaytest.execute after Steps/DayNight. Step 62 forces a collect and flush
-- into the `_Studio` ordered stores, checks the stored values against the save, the ledger and
-- the playtime, the rate limit, and the published rows and "You" attributes after a refresh;
-- step 63 checks the four boards on the square and the published attributes.
return function(ctx: any)
	local R = ctx.R
	local addStep = ctx.addStep
	local call = ctx.call
	local check = ctx.check
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local snap = ctx.snap

	local DataStoreService = game:GetService("DataStoreService")
	local HttpService = ctx.HttpService
	local ReplicatedStorage = ctx.ReplicatedStorage
	local LeaderboardView = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardView") :: any)
	local Config = ctx.GameConfig.Leaderboards

	local function studioStore(key: string): OrderedDataStore
		return DataStoreService:GetOrderedDataStore(string.format(Config.StoreFormat, key) .. Config.StudioSuffix)
	end

	local function stored(board: string, key: string): any
		return studioStore(board):GetAsync(key)
	end

	addStep("62", "LEADERBOARD_FLUSH", { "03" }, function()
		local userText = tostring(R.userId)
		local playerKey = "player_" .. userText

		-- (a) playtime accrues while the save is ready.
		local pendingOk = poll(function()
			local pending = call("leaderboardStats", nil).playtimePending[userText]
			return type(pending) == "number" and pending >= 1
		end, 15)
		check(pendingOk, "no pending playtime within 15 s")

		-- (b) the stored hours before the flush.
		local before = stored("HoursPlayed", playerKey) or 0

		-- (c) a forced collect writes.
		local forced = call("leaderboardCollect", { force = true })
		check(forced.skipped == nil, "forced collect skipped: " .. tostring(forced.skipped))

		-- (d) the stored values match the save, the ledger and the playtime.
		local state = snap(R.userId)
		local saveId = realPlayer():GetAttribute("ActiveSaveId")
		check(type(saveId) == "string", "ActiveSaveId " .. tostring(saveId))
		local saveKey = "save_" .. saveId
		local cash = stored("CashEarned", saveKey)
		local expectedCash = if state.revenue == 0 then nil else state.revenue
		check(cash == expectedCash, string.format("CashEarned %s, revenue %s", tostring(cash), tostring(state.revenue)))
		local reputation = stored("Reputation", saveKey)
		check(
			reputation == state.reputation,
			string.format("Reputation %s, save %s", tostring(reputation), tostring(state.reputation))
		)
		local spent = call("shopLedger", { userId = R.userId }).robuxSpent
		local robux = stored("RobuxSpent", playerKey)
		local expectedRobux = if spent == 0 then nil else spent
		check(robux == expectedRobux, string.format("RobuxSpent %s, ledger %s", tostring(robux), tostring(spent)))
		local hours = stored("HoursPlayed", playerKey)
		check(
			type(hours) == "number" and hours >= before + 1,
			string.format("HoursPlayed %s, before %s", tostring(hours), tostring(before))
		)

		-- (e) an unforced collect right after is rate-limited.
		local limited = call("leaderboardCollect", { force = false })
		check(limited.skipped == "RateLimited", "unforced collect skipped: " .. tostring(limited.skipped))
		check(limited.written == 0, "unforced collect wrote " .. tostring(limited.written))

		-- (f) a refresh publishes sorted rows and the "You" attributes.
		call("leaderboardRefresh", nil)
		local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
		local detail = "no published rows"
		local published = poll(function()
			local raw = folder and folder:GetAttribute("CashEarned")
			if type(raw) ~= "string" then
				detail = "CashEarned attribute " .. tostring(raw)
				return false
			end
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			local rows = LeaderboardView.rows(if ok then decoded else nil)
			if #rows > Config.TopCount then
				detail = #rows .. " rows"
				return false
			end
			for index = 2, #rows do
				if rows[index].value > rows[index - 1].value then
					detail = "rows not sorted at " .. index
					return false
				end
			end
			local player = realPlayer()
			local rank = player:GetAttribute("LbCashEarnedRank")
			local hoursValue = player:GetAttribute("LbHoursPlayedValue")
			detail = string.format(
				"LbCashEarnedValue %s, LbReputationValue %s, LbHoursPlayedValue %s, LbCashEarnedRank %s",
				tostring(player:GetAttribute("LbCashEarnedValue")),
				tostring(player:GetAttribute("LbReputationValue")),
				tostring(hoursValue),
				tostring(rank)
			)
			return player:GetAttribute("LbCashEarnedValue") == state.revenue
				and player:GetAttribute("LbReputationValue") == state.reputation
				and type(hoursValue) == "number"
				and hoursValue >= before + 1
				and type(rank) == "number"
				and rank == math.floor(rank)
				and rank >= 0
				and rank <= Config.RankDepth
		end, 10)
		check(published, detail)
		return string.format(
			"cash %s, reputation %s, robux %s, hours %s (before %s); rate-limited; %s",
			tostring(cash),
			tostring(reputation),
			tostring(robux),
			tostring(hours),
			tostring(before),
			detail
		)
	end)

	addStep("63", "LEADERBOARD_BOARDS", { "62" }, function()
		local world = workspace:FindFirstChild("ChristmasMarketWorld")
		local map = world and world:FindFirstChild("Map")
		local square = map and map:FindFirstChild("Square")
		check(square ~= nil, "ChristmasMarketWorld.Map.Square is missing")
		local folder = ReplicatedStorage:FindFirstChild("Leaderboards")
		check(folder ~= nil, "ReplicatedStorage.Leaderboards is missing")
		for _, key in Config.Keys do
			local board = (square :: Instance):FindFirstChild("Board_" .. key)
			check(board ~= nil, "Board_" .. key .. " is missing")
			local count = 0
			for _, child in (board :: Instance):GetChildren() do
				if child.Name == "Screen" then
					count += 1
				end
			end
			check(count == 1, string.format("Board_%s has %d Screen children", key, count))
			check(
				(board :: Instance):GetAttribute("LeaderboardKey") == key,
				"Board_" .. key .. " LeaderboardKey " .. tostring((board :: Instance):GetAttribute("LeaderboardKey"))
			)
			local screen = (board :: Instance):FindFirstChild("Screen")
			check(screen ~= nil and screen:IsA("BasePart"), "Board_" .. key .. ".Screen is not a BasePart")
			check(
				(screen :: Instance):GetAttribute("LeaderboardScreen") == key,
				"Board_"
					.. key
					.. ".Screen LeaderboardScreen "
					.. tostring((screen :: Instance):GetAttribute("LeaderboardScreen"))
			)
			check(
				type((folder :: Instance):GetAttribute(key)) == "string",
				"Leaderboards attribute " .. key .. " is not a string"
			)
		end
		return "4 boards with screens, 4 published attributes"
	end)
end
