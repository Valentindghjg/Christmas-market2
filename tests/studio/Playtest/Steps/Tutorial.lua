--!strict
-- Playtest steps 54-55 (full mode): the guided tutorial (CM2-49, docs/plans/CM2-49.md).
-- Installed by RunPlaytest.execute after Steps/Shop (it uses npcVisit from Steps/Npc). The
-- progress is server-owned: the steps drive it through the real order, stocking and checkout
-- paths and read it from the snapshot and the player's TutorialStep attribute.
return function(ctx: any)
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local R = ctx.R
	local act = ctx.act
	local addStep = ctx.addStep
	local advance = ctx.advance
	local awaitDelivery = ctx.awaitDelivery
	local call = ctx.call
	local rejoin = ctx.rejoin
	local check = ctx.check
	local deleteLeftover = ctx.deleteLeftover
	local npcSnapshot = ctx.npcSnapshot
	local npcVisit = ctx.npcVisit
	local orderTrees = ctx.orderTrees
	local placeOne = ctx.placeOne
	local playSave = ctx.playSave
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local saveActOk = ctx.saveActOk
	local serveCounter = ctx.serveCounter
	local snap = ctx.snap
	local withNpcCleanup = ctx.withNpcCleanup

	local function tutorialOf(userId: number): any
		local tutorial = snap(userId).tutorial
		check(type(tutorial) == "table", "snapshot has no tutorial")
		return tutorial
	end

	local function expectStep(step: string, context: string)
		local actual = tutorialOf(R.userId).step
		check(actual == step, string.format("%s: tutorial step %s, expected %s", context, tostring(actual), step))
	end

	-- The real player's TutorialStep attribute reaches value within 2 s.
	local function expectAttribute(value: string, context: string)
		local reached = poll(function()
			return realPlayer():GetAttribute("TutorialStep") == value
		end, 2)
		check(
			reached,
			string.format(
				"%s: TutorialStep %s, expected %s",
				context,
				tostring(realPlayer():GetAttribute("TutorialStep")),
				value
			)
		)
	end

	local function setStep(step: string)
		call("tutorialSet", { userId = R.userId, step = step })
	end

	local function checkingOutOnPlot(): boolean
		for _, entry in npcSnapshot().visits do
			if entry.plotId == R.plotId and entry.state == "CheckingOut" then
				return true
			end
		end
		return false
	end

	local function tutorialFlow(): string
		-- 1. A fresh save checks out by hand: no Cashier on this save.
		local cashiers = snap(R.userId).staff.Cashier
		check(cashiers == 0, "save has " .. tostring(cashiers) .. " Cashier(s), expected 0")

		-- 2. Start at Order.
		setStep("Order")
		expectStep("Order", "tutorialSet")
		expectAttribute("Order", "tutorialSet")

		-- 3. Ordering completes Order.
		local data = orderTrees(R.userId, 1)
		expectStep("Stock", "after the order")

		-- 4. Stocking from the bay completes Stock.
		advance(DELIVERY_WAIT)
		awaitDelivery(R.userId, data.orderId)
		placeOne(R.userId, data.bay)
		expectStep("Checkout", "after stocking")

		-- 5. The first manual checkout finishes the tutorial.
		npcVisit(8)
		local waiting = poll(checkingOutOnPlot, 120)
		check(waiting, "no customer CheckingOut on the plot within 120 s")
		local served = serveCounter()
		check(served == "served", "counter checkout returned " .. served)
		local finished = tutorialOf(R.userId)
		check(
			finished.step == "Done" and finished.skipped == false,
			string.format("after the sale: %s, skipped %s", tostring(finished.step), tostring(finished.skipped))
		)
		expectAttribute("Done", "after the sale")

		-- 6. Done survives a rejoin.
		rejoin(R.userId)
		expectStep("Done", "after rejoin")

		-- 7. A step in progress survives a rejoin too.
		setStep("Stock")
		rejoin(R.userId)
		expectStep("Stock", "after the second rejoin")
		expectAttribute("Stock", "after the second rejoin")

		-- 8. Skip works once; a forged payload is refused.
		local skipped = act(R.userId, "Tutorial.Skip", {})
		check(
			type(skipped) == "table" and skipped.ok == true,
			"Tutorial.Skip failed: " .. tostring(type(skipped) == "table" and skipped.errorCode or skipped)
		)
		expectAttribute("Skipped", "after Skip")
		local again = act(R.userId, "Tutorial.Skip", {})
		local againCode = type(again) == "table" and again.errorCode or again
		check(againCode == "TutorialDone", "second Skip returned " .. tostring(againCode))
		local forged = act(R.userId, "Tutorial.Skip", { step = "Order" })
		local forgedCode = type(forged) == "table" and forged.errorCode or forged
		check(forgedCode == "UnexpectedField", "Skip with a payload returned " .. tostring(forgedCode))
		return "Order>Stock>Checkout>Done, kept after rejoin, skip once"
	end
	addStep("54", "TUTORIAL_FLOW", { "03" }, withNpcCleanup(tutorialFlow))

	addStep("55", "TUTORIAL_FRESH", { "02a" }, function()
		-- 1. Leftovers of an earlier run.
		deleteLeftover(ctx.SAVE_T)
		deleteLeftover(ctx.SAVE_T2)

		-- 2. The player counts as never offered a tutorial.
		call("tutorialOffer", { userId = R.userId, offered = false })

		-- 3. The first played save starts the tutorial and marks the profile.
		local first = saveActOk("Save.Create", { name = ctx.SAVE_T }).saveId
		playSave(first)
		expectStep("Order", ctx.SAVE_T)
		expectAttribute("Order", ctx.SAVE_T)
		local offered = call("tutorialOffer", { userId = R.userId })
		check(offered == true, "tutorialOffered " .. tostring(offered) .. " after the first play")

		-- 4. The next new save gets none.
		local second = saveActOk("Save.Create", { name = ctx.SAVE_T2 }).saveId
		playSave(second)
		expectStep("Done", ctx.SAVE_T2)

		-- 5. Back to the main save; both test saves go.
		playSave(ctx.saveA)
		deleteLeftover(ctx.SAVE_T)
		deleteLeftover(ctx.SAVE_T2)
		return "first new save Order, flag set; second new save Done"
	end)
end
