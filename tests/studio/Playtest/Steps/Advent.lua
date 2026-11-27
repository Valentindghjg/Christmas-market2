--!strict
-- Playtest step 71 (full mode): the Advent calendar (CM2-A1, docs/plans/CM2-A1.md). Installed
-- by RunPlaytest.execute after Steps/Supplier. Drives the real player R through Advent.Open with
-- the calendar's time set by `adventNow` (the business clock is untouched) and the opened doors
-- set by `adventSet`; every reward comes from GameConfig.Advent on the server.
-- Step details:
-- CM2-A1: `71 ADVENT_CALENDAR` (needs 03): (1) customers paused, the mask cleared, Dec 3 12:00
-- UTC: `AdventPhase` Open, `AdventToday` 3, `AdventOpened` 0, `AdventClaimable` 3. (2) door 4 is
-- `DoorLocked` with cash unchanged; doors 1-3 pay exactly +$1250 and +100 reputation;
-- `AdventOpened` 7, claimable 0; door 1 with a new request ID is `AlreadyClaimed`. (3) Dec 6
-- 12:00: claimable 3; door 6 pays +$3000, +250 reputation and one `AdventStarLantern` in
-- `decorInventory`. (4) after `flush` and `rejoin` cash, reputation and the decor count are equal;
-- Dec 6 again shows `AdventOpened` 39 and door 1 is `AlreadyClaimed`. (5) on a fresh save
-- "Playtest Advent" door 2 is `AlreadyClaimed` with cash unchanged and door 4 gives Cash Rush
-- >= 890 s; back on save A door 4 is `AlreadyClaimed`; the save is deleted. (6) Dec 25: `Ended`,
-- claimable 0, door 5 `CalendarClosed`. The override and the mask are always cleared afterwards.
return function(ctx: any)
	local HttpService = ctx.HttpService
	local R = ctx.R
	local act = ctx.act
	local addStep = ctx.addStep
	local call = ctx.call
	local check = ctx.check
	local deleteLeftover = ctx.deleteLeftover
	local playSave = ctx.playSave
	local realPlayer = ctx.realPlayer
	local rejoin = ctx.rejoin
	local saveActOk = ctx.saveActOk
	local snap = ctx.snap

	local SAVE_ADVENT = "Playtest Advent"
	local DAY_SECONDS = 86400
	-- 2026-12-03 12:00 UTC (AdventCalendar.utcTime(2026, 12, 3, 12)).
	local DEC_3_NOON = 1796299200
	local DEC_6_NOON = DEC_3_NOON + 3 * DAY_SECONDS
	-- 2026-12-25 00:00 UTC.
	local DEC_25 = 1798156800

	local function attribute(name: string): any
		return realPlayer():GetAttribute(name)
	end

	local function codeOf(response: any): string
		return tostring(type(response) == "table" and response.errorCode or response)
	end

	local function openDoor(door: number): any
		return act(R.userId, "Advent.Open", { door = door }, "a1_" .. HttpService:GenerateGUID(false))
	end

	local function openDoorOk(door: number): any
		local response = openDoor(door)
		check(
			type(response) == "table" and response.ok == true,
			string.format("door %d failed: %s", door, codeOf(response))
		)
		return response.data
	end

	local function refused(door: number, expected: string)
		local code = codeOf(openDoor(door))
		check(code == expected, string.format("door %d returned %s, expected %s", door, code, expected))
	end

	local function adventNow(at: number)
		check(call("adventNow", { at = at }) == true, "adventNow did not apply")
	end

	local function expectAttributes(phase: string, today: number?, opened: number?, claimable: number?)
		local text = string.format(
			"Advent attributes %s/%s/%s/%s",
			tostring(attribute("AdventPhase")),
			tostring(attribute("AdventToday")),
			tostring(attribute("AdventOpened")),
			tostring(attribute("AdventClaimable"))
		)
		check(attribute("AdventPhase") == phase, text)
		check(today == nil or attribute("AdventToday") == today, text)
		check(opened == nil or attribute("AdventOpened") == opened, text)
		check(claimable == nil or attribute("AdventClaimable") == claimable, text)
	end

	local function money(): (number, number)
		local snapshot = snap(R.userId)
		return snapshot.cash, snapshot.reputation
	end

	local function lanterns(): number
		local inventory = snap(R.userId).decorInventory
		return if type(inventory) == "table" then inventory.AdventStarLantern or 0 else 0
	end

	local function body(): string
		-- (1) Dec 3 with nothing opened: three doors wait.
		call("pauseCustomers", true)
		check(call("adventSet", { userId = R.userId, clear = true }) == true, "adventSet clear did not write")
		adventNow(DEC_3_NOON)
		expectAttributes("Open", 3, 0, 3)

		-- (2) a future door is refused; doors 1-3 pay once.
		local cash, reputation = money()
		refused(4, "DoorLocked")
		check(money() == cash, "cash moved on a locked door")
		for door = 1, 3 do
			openDoorOk(door)
		end
		local cashAfter, reputationAfter = money()
		check(cashAfter == cash + 1250, string.format("doors 1-3 cash +%d, expected +1250", cashAfter - cash))
		check(
			reputationAfter == reputation + 100,
			string.format("doors 1-3 reputation +%d, expected +100", reputationAfter - reputation)
		)
		expectAttributes("Open", 3, 7, 0)
		refused(1, "AlreadyClaimed")

		-- (3) Dec 6: the first special door.
		adventNow(DEC_6_NOON)
		expectAttributes("Open", 6, nil, 3)
		cash, reputation = money()
		local lanternsBefore = lanterns()
		openDoorOk(6)
		cashAfter, reputationAfter = money()
		check(cashAfter == cash + 3000, string.format("door 6 cash +%d, expected +3000", cashAfter - cash))
		check(
			reputationAfter == reputation + 250,
			string.format("door 6 reputation +%d, expected +250", reputationAfter - reputation)
		)
		check(lanterns() == lanternsBefore + 1, string.format("star lanterns %d after door 6", lanterns()))

		-- (4) the doors, money and decor survive a rejoin.
		local lanternsKept = lanterns()
		call("flush", nil)
		rejoin(R.userId)
		local cashKept, reputationKept = money()
		check(cashKept == cashAfter, string.format("cash %d after rejoin, expected %d", cashKept, cashAfter))
		check(
			reputationKept == reputationAfter,
			string.format("reputation %d after rejoin, expected %d", reputationKept, reputationAfter)
		)
		check(lanterns() == lanternsKept, "decor count changed across the rejoin")
		adventNow(DEC_6_NOON)
		expectAttributes("Open", 6, 39, nil)
		refused(1, "AlreadyClaimed")

		-- (5) once per player across saves.
		deleteLeftover(SAVE_ADVENT)
		local saveId = saveActOk("Save.Create", { name = SAVE_ADVENT }).saveId
		playSave(saveId)
		local freshCash = money()
		refused(2, "AlreadyClaimed")
		check(money() == freshCash, "cash moved on a door opened in another save")
		openDoorOk(4)
		local boost = snap(R.userId).purchases.boosts.CashX2
		check(boost >= 890, string.format("Cash Rush %s s after door 4, expected >= 890", tostring(boost)))
		playSave(ctx.saveA)
		refused(4, "AlreadyClaimed")
		saveActOk("Save.Delete", { saveId = saveId, confirmName = SAVE_ADVENT })

		-- (6) after Dec 24 the calendar is closed.
		adventNow(DEC_25)
		expectAttributes("Ended", 0, nil, 0)
		refused(5, "CalendarClosed")
		return "Dec 3 doors 1-3 +$1250 +100 rep, door 4 locked, door 6 special, kept after rejoin, "
			.. "once across saves, closed on Dec 25"
	end

	addStep("71", "ADVENT_CALENDAR", { "03" }, function()
		local ok, result = pcall(body)
		pcall(call, "adventNow", { clear = true })
		pcall(call, "adventSet", { userId = R.userId, clear = true })
		pcall(call, "pauseCustomers", false)
		if not ok then
			error(result, 0)
		end
		return result
	end)
end
