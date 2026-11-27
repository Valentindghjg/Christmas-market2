--!strict
-- Playtest steps 67-68 (full mode): daily reward streak, quest board and group bonus (CM2-G11,
-- docs/plans/CM2-G11.md). Installed by RunPlaytest.execute after Steps/LotArt. Step 67 drives
-- the real player's daily streak through Daily.Claim (claim, reset, group bonus) and checks the
-- Daily* attributes and the saved claim after a rejoin; step 68 drives the save's quest board
-- through Quest.Claim (order hook, bonus lock, claims, rotation) and checks it after a rejoin.
-- A run that crosses UTC midnight or a 4-h quest boundary inside a step is re-run once.
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- CM2-G11: `67 DAILY_REWARD` and `68 QUEST_BOARD` in `Steps/Quests.lua` (67: with the group
-- override and the streak cleared, `DailyGroup` `Hidden`, `DailyClaimable` true, `DailyNext` 1;
-- `Daily.Claim` pays day 1 $400 once (`AlreadyClaimed` after); yesterday at streak 2 gives day 3
-- +150 reputation and no cash; a missed day resets to day 1 +$400; `dailyGroup {groupId = 1, member
-- = true}` shows `Active` and day 4 pays exactly +$1400 with `doubled`; a non-member sees `Join`
-- and day 5 pays +$900 (the clock first moves past the 60-s claim window); after `flush` and
-- `rejoin` cash is equal and the day stays claimed. 68: an aged board shows 4 rows with the bonus
-- locked, the clock's period and `0 < endsIn <= 14400`; one shadow order raises its order quest by
-- 1 (capped); the bonus is `BonusLocked` while 1–3 are open; quests 1–3 pay $450 in total once
-- (replay `DuplicateRequest`, new ID `AlreadyClaimed`); the bonus pays $550 and 100 reputation; all
-- claims and the cash survive a rejoin; an aged board shows fresh rows, a current-period claim is
-- `Incomplete` and an old-period claim `QuestsRotated` with cash unchanged. A run crossing UTC
-- midnight or a 4-h boundary inside 67/68 is re-run once).
return function(ctx: any)
	local HttpService = ctx.HttpService
	local R = ctx.R
	local S = ctx.S
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local advance = ctx.advance
	local call = ctx.call
	local check = ctx.check
	local orderTrees = ctx.orderTrees
	local realPlayer = ctx.realPlayer
	local rejoin = ctx.rejoin
	local snap = ctx.snap

	local ROTATION = ctx.GameConfig.Quests.RotationSeconds
	local DAY_SECONDS = ctx.GameConfig.DailyRewards.DaySeconds
	-- Daily.Claim allows 5 claims per 60 s; the step moves the clock past the window once.
	local LIMIT_WINDOW = ctx.GameConfig.DailyRewards.ClaimLimit.window + 1

	local function requestId(prefix: string): string
		return prefix .. "_" .. HttpService:GenerateGUID(false)
	end

	local function attribute(name: string): any
		return realPlayer():GetAttribute(name)
	end

	local function codeOf(response: any): string
		return tostring(type(response) == "table" and response.errorCode or response)
	end

	local function dailySet(arg: any)
		arg.userId = R.userId
		check(call("dailySet", arg) == true, "dailySet did not write the profile")
	end

	local function claimDaily(): any
		return act(R.userId, "Daily.Claim", {}, requestId("g11d"))
	end

	local function claimDailyOk(): any
		local response = claimDaily()
		check(type(response) == "table" and response.ok == true, "Daily.Claim failed: " .. codeOf(response))
		return response.data
	end

	local function money(userId: number): (number, number)
		local snapshot = snap(userId)
		return snapshot.cash, snapshot.reputation
	end

	addStep("67", "DAILY_REWARD", { "03" }, function()
		call("pauseCustomers", true)
		local startDay = math.floor(call("clock", nil) / DAY_SECONDS)

		-- (1) a new player, no group: day 1 waits.
		call("dailyGroup", {})
		dailySet({ clear = true })
		check(attribute("DailyGroup") == "Hidden", "DailyGroup " .. tostring(attribute("DailyGroup")))
		check(attribute("DailyClaimable") == true, "DailyClaimable " .. tostring(attribute("DailyClaimable")))
		check(attribute("DailyNext") == 1, "DailyNext " .. tostring(attribute("DailyNext")))

		-- (2) day 1 pays 400 once.
		local cash, reputation = money(R.userId)
		local first = claimDailyOk()
		check(
			first.day == 1 and first.cash == 400 and first.doubled == false,
			string.format("day 1 data %s/%s/%s", tostring(first.day), tostring(first.cash), tostring(first.doubled))
		)
		local afterFirst = money(R.userId)
		check(afterFirst == cash + 400, string.format("cash %d after day 1, expected %d", afterFirst, cash + 400))
		check(
			attribute("DailyClaimable") == false,
			"DailyClaimable after the claim " .. tostring(attribute("DailyClaimable"))
		)
		check(attribute("DailyNext") == 2, "DailyNext after the claim " .. tostring(attribute("DailyNext")))
		local again = claimDaily()
		check(codeOf(again) == "AlreadyClaimed", "second claim: " .. codeOf(again))
		check(money(R.userId) == afterFirst, "cash moved on the refused second claim")

		-- (3) claimed yesterday at streak 2: day 3 pays 150 reputation.
		dailySet({ daysAgo = 1, streak = 2 })
		cash, reputation = money(R.userId)
		local third = claimDailyOk()
		local cashAfter, reputationAfter = money(R.userId)
		check(third.day == 3, "streak 2 + 1 gave day " .. tostring(third.day))
		check(
			reputationAfter == reputation + 150,
			string.format("reputation +%d, expected +150", reputationAfter - reputation)
		)
		check(cashAfter == cash, string.format("cash moved by %d on a reputation day", cashAfter - cash))

		-- (4) a missed day resets the streak to day 1.
		dailySet({ daysAgo = 2, streak = 5 })
		cash = money(R.userId)
		local reset = claimDailyOk()
		check(reset.day == 1, "missed day gave day " .. tostring(reset.day))
		check(money(R.userId) == cash + 400, "reset day 1 did not pay 400")

		-- (5) a group member gets 2x once: day 4 pays 1400.
		call("dailyGroup", { groupId = 1, member = true })
		dailySet({ daysAgo = 1, streak = 3 })
		check(attribute("DailyGroup") == "Active", "DailyGroup for a member " .. tostring(attribute("DailyGroup")))
		cash = money(R.userId)
		local doubled = claimDailyOk()
		check(doubled.day == 4 and doubled.doubled == true, "member claim day " .. tostring(doubled.day))
		local memberCash = money(R.userId)
		check(memberCash == cash + 1400, string.format("member cash +%d, expected +1400", memberCash - cash))

		-- (6) a non-member with a group ID sees Join and gets 1x: day 5 pays 900.
		advance(LIMIT_WINDOW)
		call("dailyGroup", { groupId = 1, member = false })
		dailySet({ daysAgo = 1, streak = 4 })
		check(attribute("DailyGroup") == "Join", "DailyGroup for a non-member " .. tostring(attribute("DailyGroup")))
		cash = money(R.userId)
		local plain = claimDailyOk()
		check(plain.day == 5 and plain.doubled == false, "non-member claim day " .. tostring(plain.day))
		local plainCash = money(R.userId)
		check(plainCash == cash + 900, string.format("non-member cash +%d, expected +900", plainCash - cash))

		-- (7) the claim and the cash survive a rejoin; the day stays claimed.
		call("flush", nil)
		rejoin(R.userId)
		check(
			money(R.userId) == plainCash,
			string.format("cash %d after rejoin, expected %d", money(R.userId), plainCash)
		)
		local afterRejoin = claimDaily()
		check(codeOf(afterRejoin) == "AlreadyClaimed", "claim after rejoin: " .. codeOf(afterRejoin))
		call("dailyGroup", {})
		local endDay = math.floor(call("clock", nil) / DAY_SECONDS)
		local crossed = if endDay ~= startDay then " (crossed UTC midnight: re-run once)" else ""
		return "day 1 +400 once, day 3 +150 rep, reset to day 1, member day 4 +1400, Join day 5 +900, kept after rejoin"
			.. crossed
	end)

	local function summaryQuests(userId: number): any
		local quests = actOk(userId, "Company.GetSummary", {}).quests
		check(type(quests) == "table" and type(quests.quests) == "table", "summary has no quest board")
		return quests
	end

	local function claimQuest(slot: number, period: number, id: string?): any
		return act(R.userId, "Quest.Claim", { slot = slot, period = period }, id or requestId("g11q"))
	end

	local function questSet(slot: number, progress: number)
		check(
			call("questSet", { userId = R.userId, slot = slot, progress = progress }) == true,
			"questSet slot " .. slot
		)
	end

	addStep("68", "QUEST_BOARD", { "03" }, function()
		call("pauseCustomers", true)
		-- (1) an aged board shows the fresh board of the current period.
		call("questAge", { userId = R.userId })
		local board = summaryQuests(R.userId)
		local period = math.floor(call("clock", nil) / ROTATION)
		check(#board.quests == 4, string.format("%d quest rows", #board.quests))
		for slot = 1, 4 do
			check(board.quests[slot].slot == slot, "row " .. slot .. " has slot " .. tostring(board.quests[slot].slot))
		end
		check(board.quests[4].locked == true, "bonus row is not locked")
		check(board.period == period, string.format("board period %s, clock period %d", tostring(board.period), period))
		check(board.endsIn > 0 and board.endsIn <= ROTATION, "endsIn " .. tostring(board.endsIn))

		-- (2) an order fills the shadow's order quest.
		local before = summaryQuests(S.userId)
		local p0 = before.quests[1].progress
		local target = before.quests[1].target
		orderTrees(S.userId, 1)
		local after = summaryQuests(S.userId)
		local rotated = after.period ~= before.period
		local expected = if rotated then 1 else math.min(target, p0 + 1)
		check(
			after.quests[1].progress == expected,
			string.format("shadow order quest %d -> %d, expected %d", p0, after.quests[1].progress, expected)
		)

		-- (3) the bonus stays locked while quests 1-3 are open.
		questSet(4, board.quests[4].target)
		local locked = claimQuest(4, period)
		check(codeOf(locked) == "BonusLocked", "bonus claim: " .. codeOf(locked))

		-- (4) quests 1-3 pay 450 once; a replay and a second claim are refused.
		local cash = money(R.userId)
		local slotOneId = requestId("g11q")
		for slot = 1, 3 do
			questSet(slot, board.quests[slot].target)
			local response = claimQuest(slot, period, if slot == 1 then slotOneId else nil)
			check(type(response) == "table" and response.ok == true, "claim slot " .. slot .. ": " .. codeOf(response))
		end
		local afterThree = money(R.userId)
		check(afterThree == cash + 450, string.format("quests 1-3 paid %d, expected 450", afterThree - cash))
		local replay = claimQuest(1, period, slotOneId)
		check(codeOf(replay) == "DuplicateRequest", "replayed slot 1: " .. codeOf(replay))
		local second = claimQuest(1, period)
		check(codeOf(second) == "AlreadyClaimed", "second slot 1 claim: " .. codeOf(second))
		check(money(R.userId) == afterThree, "cash moved on a refused claim")

		-- (5) the bonus pays 550 and 100 reputation.
		local bonusCash, bonusReputation = money(R.userId)
		local bonus = claimQuest(4, period)
		check(type(bonus) == "table" and bonus.ok == true, "bonus claim: " .. codeOf(bonus))
		local cashAfter, reputationAfter = money(R.userId)
		check(cashAfter == bonusCash + 550, string.format("bonus paid %d, expected 550", cashAfter - bonusCash))
		check(
			reputationAfter == bonusReputation + 100,
			string.format("bonus reputation +%d, expected +100", reputationAfter - bonusReputation)
		)

		-- (6) the claims survive a rejoin.
		call("flush", nil)
		rejoin(R.userId)
		local saved = snap(R.userId)
		for slot = 1, 4 do
			check(saved.quests.claimed[slot] == true, "slot " .. slot .. " not claimed after rejoin")
		end
		check(saved.cash == cashAfter, string.format("cash %d after rejoin, expected %d", saved.cash, cashAfter))

		-- (7) a rotation drops progress; old-period claims are refused and pay nothing.
		call("questAge", { userId = R.userId })
		local fresh = summaryQuests(R.userId)
		for slot = 1, 4 do
			local row = fresh.quests[slot]
			check(row.progress == 0 and row.claimed == false, "row " .. slot .. " not fresh after aging")
		end
		local incomplete = claimQuest(1, fresh.period)
		check(codeOf(incomplete) == "Incomplete", "fresh slot 1 claim: " .. codeOf(incomplete))
		local stale = claimQuest(1, fresh.period - 1)
		check(codeOf(stale) == "QuestsRotated", "old-period claim: " .. codeOf(stale))
		check(money(R.userId) == cashAfter, "cash moved after the rotation")
		local crossed = if math.floor(call("clock", nil) / ROTATION) ~= period
			then " (crossed a 4-h boundary: re-run once)"
			else ""
		return string.format(
			"period %d, shadow order quest %d -> %d%s, bonus locked, 1-3 +450 once, bonus +550/+100, kept after rejoin, rotation refused%s",
			period,
			p0,
			after.quests[1].progress,
			if rotated then " (period changed)" else "",
			crossed
		)
	end)
end
