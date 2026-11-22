--!strict
-- Playtest steps 24-35 (full mode): save slots, co-op saves and cross-server saves.
-- Installed by RunPlaytest.execute (CM2-RF).
return function(ctx: any)
	local GameConfig = ctx.GameConfig
	local HttpService = ctx.HttpService
	local R = ctx.R
	local S = ctx.S
	local S2 = ctx.S2
	local SAVE_A = ctx.SAVE_A
	local SAVE_B = ctx.SAVE_B
	local SAVE_B2 = ctx.SAVE_B2
	local SAVE_C = ctx.SAVE_C
	local SAVE_DUO = ctx.SAVE_DUO
	local SAVE_FAR = ctx.SAVE_FAR
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local UNIT_PRICE = ctx.UNIT_PRICE
	local act = ctx.act
	local addStep = ctx.addStep
	local advance = ctx.advance
	local call = ctx.call
	local check = ctx.check
	local deleteFar = ctx.deleteFar
	local deleteFinderSave = ctx.deleteFinderSave
	local deleteLeftover = ctx.deleteLeftover
	local findSave = ctx.findSave
	local finderListings = ctx.finderListings
	local invoke = ctx.invoke
	local locatorEntry = ctx.locatorEntry
	local memberOf = ctx.memberOf
	local orderTrees = ctx.orderTrees
	local playSave = ctx.playSave
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local rowOf = ctx.rowOf
	local sameTable = ctx.sameTable
	local saveActAsOk = ctx.saveActAsOk
	local saveActOk = ctx.saveActOk
	local saveList = ctx.saveList
	local saveRefused = ctx.saveRefused
	local saveRefusedAs = ctx.saveRefusedAs
	local shadowOtherSave = ctx.shadowOtherSave
	local snap = ctx.snap

	local saveB, saveC = "", ""
	local saveDuo, duoCode = "", ""

	addStep("24", "SAVE_CREATE", { "02a" }, function()
		local removed = 0
		for _, name in { SAVE_B, SAVE_B2, SAVE_C } do
			if deleteLeftover(name) then
				removed += 1
			end
		end
		local listedBefore = #saveList()
		local requestId = "playtest_create_" .. HttpService:GenerateGUID(false)
		local first = saveActOk("Save.Create", { name = SAVE_B }, requestId)
		local replay = saveActOk("Save.Create", { name = SAVE_B }, requestId)
		check(replay.saveId == first.saveId, "replayed create returned another save")
		local listedAfter = #saveList()
		check(
			listedAfter == listedBefore + 1,
			string.format("save list %d -> %d, expected +1", listedBefore, listedAfter)
		)
		saveB = first.saveId
		return string.format("%s created, replay deduplicated, %d leftover(s) removed", SAVE_B, removed)
	end)

	addStep("25", "SAVE_SWITCH", { "24" }, function()
		local snapA = snap(R.userId)
		local plotA = R.plotId
		playSave(saveB)
		check(R.plotId == plotA, string.format("PlotId %s -> %s", tostring(plotA), tostring(R.plotId)))
		local snapB = snap(R.userId)
		check(
			snapB.cash == GameConfig.StartingCash,
			string.format("B cash %d, expected %d", snapB.cash, GameConfig.StartingCash)
		)
		check(snapB.placementCount == 0, "B has " .. snapB.placementCount .. " placements")
		orderTrees(R.userId, 1)
		check(snap(R.userId).cash == GameConfig.StartingCash - UNIT_PRICE, "B order did not cost " .. UNIT_PRICE)
		playSave(ctx.saveA)
		local backA = snap(R.userId)
		for _, field in { "cash", "revision", "placementCount" } do
			check(
				snapA[field] == backA[field],
				string.format("A %s %s -> %s", field, tostring(snapA[field]), tostring(backA[field]))
			)
		end
		sameTable("A stock", snapA.stock, backA.stock)
		playSave(saveB)
		local backB = snap(R.userId).cash
		check(
			backB == GameConfig.StartingCash - UNIT_PRICE,
			string.format("B cash %d, expected %d", backB, GameConfig.StartingCash - UNIT_PRICE)
		)
		playSave(ctx.saveA)
		return string.format("same plot %s, A cash %d kept, B cash %d", tostring(R.plotId), backA.cash, backB)
	end)

	addStep("26", "SAVE_RENAME", { "24" }, function()
		saveRefused("Save.Rename", { saveId = saveB, name = "" }, "NameInvalid")
		saveActOk("Save.Rename", { saveId = saveB, name = SAVE_B2 })
		local renamed = findSave(SAVE_B2)
		check(renamed ~= nil and renamed.saveId == saveB, SAVE_B2 .. " not listed")
		saveRefused("Save.Rename", { saveId = saveB, name = "playtest a" }, "NameInUse")
		return SAVE_B .. " renamed to " .. SAVE_B2
	end)

	addStep("27", "SAVE_DELETE", { "26" }, function()
		saveRefused("Save.Delete", { saveId = saveB, confirmName = SAVE_B }, "ConfirmationMismatch")
		check(findSave(SAVE_B2) ~= nil, SAVE_B2 .. " vanished after a mismatched confirmation")
		saveRefused("Save.Delete", { saveId = ctx.saveA, confirmName = SAVE_A }, "SaveActive")
		saveActOk("Save.Delete", { saveId = saveB, confirmName = " playtest b2 " })
		check(findSave(SAVE_B2) == nil, SAVE_B2 .. " still listed after deleting")
		saveRefused("Save.Play", { saveId = saveB }, "SaveNotFound")
		return "mismatch and active refused, " .. SAVE_B2 .. " deleted"
	end)

	addStep("28", "FAIL_CLOSED", { "02a" }, function()
		saveC = saveActOk("Save.Create", { name = SAVE_C }).saveId
		playSave(saveC)
		call("lockSave", { userId = R.userId, saveId = saveC })
		call("flush", nil)
		local current = realPlayer()
		local stopped = poll(function()
			return current:GetAttribute("CompanyReady") == false
				and current:GetAttribute("CompanyError") == "SessionLocked"
		end, 5)
		check(
			stopped,
			string.format(
				"CompanyReady %s, CompanyError %s",
				tostring(current:GetAttribute("CompanyReady")),
				tostring(current:GetAttribute("CompanyError"))
			)
		)
		local refused = act(R.userId, "Supplier.PlaceOrder", { speciesId = SPECIES, sizeId = SIZE, quantity = 1 })
		check(
			type(refused) == "table" and refused.errorCode == "CompanyUnavailable",
			"order on a failed save returned " .. tostring(type(refused) == "table" and refused.errorCode or refused)
		)
		call("unlockSave", { userId = R.userId, saveId = saveC })
		playSave(ctx.saveA)
		saveActOk("Save.Delete", { saveId = saveC, confirmName = SAVE_C })
		return "SessionLocked shown, order refused, back on " .. SAVE_A
	end)

	-- Co-op saves (CM2-S2): the shadow is the second member, shadow 2 the third.
	addStep("29", "COOP_JOIN", { "02", "02a" }, function()
		local removed = deleteLeftover(SAVE_DUO)
		saveDuo = saveActOk("Save.Create", { name = SAVE_DUO, size = "Duo" }).saveId
		playSave(saveDuo)
		local current = realPlayer()
		check(
			current:GetAttribute("ActiveSaveRole") == "Owner",
			"ActiveSaveRole " .. tostring(current:GetAttribute("ActiveSaveRole"))
		)
		check(
			current:GetAttribute("ActiveSaveSize") == "Duo",
			"ActiveSaveSize " .. tostring(current:GetAttribute("ActiveSaveSize"))
		)
		local team = saveActOk("Save.Team", {})
		check(
			type(team.inviteCode) == "string" and string.match(team.inviteCode, "^[1-9]%d%d%d%d$") ~= nil,
			"invite code " .. tostring(team.inviteCode)
		)
		check(team.seats == 2, "seats " .. tostring(team.seats))
		duoCode = team.inviteCode
		local joined = saveActAsOk(S.userId, "Save.Join", { code = duoCode })
		check(joined.saveId == saveDuo, "joined " .. tostring(joined.saveId))
		local played = saveActAsOk(S.userId, "Save.Play", { saveId = saveDuo })
		check(
			played.plotId == R.plotId,
			string.format("shadow plot %s, owner plot %s", tostring(played.plotId), tostring(R.plotId))
		)
		team = saveActOk("Save.Team", {})
		check(#team.members == 2, #team.members .. " team members")
		local shadowMember = memberOf(team, S.userId)
		check(
			shadowMember ~= nil and shadowMember.role == "Member" and shadowMember.online == true,
			"shadow is not an online Member"
		)
		local row = rowOf(S.userId, saveDuo)
		check(row ~= nil and row.role == "Member" and row.name == nil, "shadow row is not a nameless Member row")
		return string.format(
			"code %s, shadow on plot %s%s",
			duoCode,
			tostring(R.plotId),
			if removed then ", leftover removed" else ""
		)
	end)

	addStep("30", "COOP_SHARED_CASH", { "29" }, function()
		local rStart, sStart = snap(R.userId), snap(S.userId)
		check(
			rStart.cash == sStart.cash and rStart.revision == sStart.revision,
			string.format("snapshots differ: cash %d vs %d", rStart.cash, sStart.cash)
		)
		local start = rStart.cash
		check(start >= 3 * UNIT_PRICE, string.format("Duo cash %d below three orders", start))
		orderTrees(S.userId, 1)
		local afterShadow = snap(R.userId).cash
		check(afterShadow == start - UNIT_PRICE, string.format("owner cash %d after the shadow's order", afterShadow))
		local payload = { speciesId = SPECIES, sizeId = SIZE, quantity = 1 }
		local requestId = "playtest_shared_" .. HttpService:GenerateGUID(false)
		local first = act(R.userId, "Supplier.PlaceOrder", payload, requestId)
		if type(first) == "table" and first.errorCode == "SupplierOutOfStock" then
			advance(240)
			requestId = "playtest_shared_" .. HttpService:GenerateGUID(false)
			first = act(R.userId, "Supplier.PlaceOrder", payload, requestId)
		end
		check(
			type(first) == "table" and first.ok == true,
			"owner order failed: " .. tostring(type(first) == "table" and first.errorCode or first)
		)
		local rAfter, sAfter = snap(R.userId), snap(S.userId)
		check(
			rAfter.cash == start - 2 * UNIT_PRICE and sAfter.cash == rAfter.cash,
			string.format("cash owner %d, shadow %d, expected %d", rAfter.cash, sAfter.cash, start - 2 * UNIT_PRICE)
		)
		local second = act(S.userId, "Supplier.PlaceOrder", payload, requestId)
		check(
			type(second) == "table" and second.errorCode == "DuplicateRequest",
			"same request ID returned " .. tostring(type(second) == "table" and second.errorCode or second)
		)
		local cash = snap(R.userId).cash
		check(
			cash == start - 2 * UNIT_PRICE,
			string.format("cash %d, expected one debit to %d", cash, start - 2 * UNIT_PRICE)
		)
		check(snap(S.userId).cash == cash, "shadow sees another cash balance")
		return string.format("shared cash %d -> %d, duplicate refused", start, cash)
	end)

	addStep("31", "COOP_RULES", { "29" }, function()
		for _, refused in
			{
				{ "Save.RegenerateCode", {} },
				{ "Save.RemoveMember", { userId = R.userId } },
				{ "Save.SetSize", { size = "Quad" } },
				{ "Save.Rename", { saveId = saveDuo, name = "Shadow Lot" } },
				{ "Save.Delete", { saveId = saveDuo, confirmName = "Shared lot" } },
			}
		do
			saveRefusedAs(S.userId, refused[1], refused[2], "OwnerOnly")
		end
		saveRefusedAs(S2.userId, "Save.Join", { code = duoCode }, "SaveFull")
		saveRefused("Save.SetSize", { size = "Solo" }, "SizeTooSmall")
		local old = duoCode
		local renewed = saveActOk("Save.RegenerateCode", {})
		check(type(renewed.inviteCode) == "string" and renewed.inviteCode ~= old, "the new code equals the old one")
		duoCode = renewed.inviteCode
		saveRefusedAs(S2.userId, "Save.Join", { code = old }, "InviteCodeInvalid")
		saveActOk("Save.SetSize", { size = "Trio" })
		saveActAsOk(S2.userId, "Save.Join", { code = duoCode })
		saveRefused("Save.SetSize", { size = "Duo" }, "SizeTooSmall")
		saveActOk("Save.RemoveMember", { userId = S2.userId })
		saveActOk("Save.SetSize", { size = "Duo" })
		return "member actions OwnerOnly, seat limit, old code refused, resize and remove ok"
	end)

	addStep("32", "COOP_REMOVE", { "29" }, function()
		saveActOk("Save.RemoveMember", { userId = S.userId })
		local gone = invoke("snapshot", S.userId)
		check(
			type(gone) == "table" and gone.errorCode == "NoActiveSave",
			"removed shadow snapshot " .. tostring(type(gone) == "table" and gone.errorCode or gone)
		)
		check(rowOf(S.userId, saveDuo) == nil, "removed shadow still lists the Duo")
		saveRefusedAs(S.userId, "Save.Play", { saveId = saveDuo }, "SaveNotFound")
		saveActAsOk(S.userId, "Save.Join", { code = duoCode })
		saveActAsOk(S.userId, "Save.Play", { saveId = saveDuo })
		-- The owner goes elsewhere; the member keeps playing.
		playSave(ctx.saveA)
		local memberCashBefore = snap(S.userId).cash
		check(memberCashBefore >= UNIT_PRICE, string.format("Duo cash %d below one order", memberCashBefore))
		orderTrees(S.userId, 1)
		check(
			snap(S.userId).cash == memberCashBefore - UNIT_PRICE,
			"member order with the owner away did not debit once"
		)
		local team = saveActAsOk(S.userId, "Save.Team", {})
		local owner = memberOf(team, R.userId)
		check(owner ~= nil and owner.online == false, "owner not listed as offline")
		saveRefused("Save.Delete", { saveId = saveDuo, confirmName = SAVE_DUO }, "SaveInUse")
		local own = nil
		for _, entry in call("saves", S.userId) do
			if entry.role == "Owner" then
				own = entry
				break
			end
		end
		check(own ~= nil, "shadow has no own save")
		local played = saveActAsOk(S.userId, "Save.Play", { saveId = own.saveId })
		S.plotId = played.plotId
		saveActOk("Save.Delete", { saveId = saveDuo, confirmName = SAVE_DUO })
		check(rowOf(S.userId, saveDuo) == nil, "shadow still lists the deleted Duo")
		return string.format("removed and re-joined, Duo deleted, shadow back on %s", tostring(S.plotId))
	end)

	-- One server per save (CM2-S3): this Studio server holds the played save in the map.
	addStep("33", "LOCATOR_CLAIM", { "02a" }, function()
		local entry = locatorEntry(ctx.saveA)
		check(type(entry) == "table", "no map entry for " .. SAVE_A)
		check(entry.jobId == "studio", "map jobId " .. tostring(entry.jobId))
		check(entry.hostUserId == R.userId, "map hostUserId " .. tostring(entry.hostUserId))
		check(entry.releasedAt == nil, "map entry for the played save is released")
		local renewal = call("renewLocations", nil)
		check(renewal.ok == true, string.format("renewal failed for %s saves", tostring(renewal.failures)))
		check(type(renewal.renewed) == "number" and renewal.renewed >= 1, "renewed " .. tostring(renewal.renewed))
		return string.format("held by studio for %d, %d renewed", R.userId, renewal.renewed)
	end)

	-- A co-op save that another server holds: the row offers Join, Play refuses, and Studio
	-- cannot teleport.
	addStep("34", "ELSEWHERE", { "02a" }, function()
		local removed = deleteFar()
		local far = saveActOk("Save.Create", { name = SAVE_FAR, size = "Duo" }).saveId
		playSave(far)
		playSave(ctx.saveA)
		local released = locatorEntry(far)
		check(
			type(released) == "table" and released.releasedAt ~= nil,
			"map entry for " .. SAVE_FAR .. " is not released"
		)
		call("placeElsewhere", { userId = R.userId, saveId = far })
		call("lockSave", { userId = R.userId, saveId = far })
		local listed = saveActOk("Save.List", {})
		local row = nil
		for _, entry in listed.saves do
			if entry.saveId == far then
				row = entry
			end
		end
		check(row ~= nil and row.elsewhere == true, SAVE_FAR .. " row is not marked elsewhere")
		saveRefused("Save.Play", { saveId = far }, "SaveInUseElsewhere")
		saveRefused("Save.Teleport", { saveId = far }, "TeleportUnavailable")
		local cleared = call("clearElsewhere", { userId = R.userId, saveId = far })
		check(cleared.cleared == true, "clearElsewhere did not clear the entry")
		call("unlockSave", { userId = R.userId, saveId = far })
		playSave(far)
		playSave(ctx.saveA)
		saveActOk("Save.Delete", { saveId = far, confirmName = SAVE_FAR })
		return string.format(
			"elsewhere row, Play refused, Teleport unavailable in Studio%s",
			if removed then ", leftover removed" else ""
		)
	end)

	-- Teammate finder (CM2-S3): the shadow searches, the player takes the free seat.
	addStep("35", "FINDER", { "02", "02a" }, function()
		local started = saveActAsOk(S.userId, "Save.FinderStart", { size = "Duo" })
		check(started.created == true, "the shadow's search did not create a save")
		S.finderSaveId = started.saveId
		local listed = finderListings(R.userId)
		local listing = nil
		for _, candidate in listed.listings do
			if candidate.saveId == S.finderSaveId then
				listing = candidate
			end
		end
		check(listing ~= nil, "the shadow's listing is missing")
		check(listing.ownerUserId == S.userId, "listing owner " .. tostring(listing.ownerUserId))
		check(
			listing.seats == 2 and listing.taken == 1,
			string.format("seats %s, taken %s", listing.seats, listing.taken)
		)

		-- Amendment A1.8: the player's plot is the one FinderJoin returned.
		local join = saveActOk("Save.FinderJoin", { saveId = S.finderSaveId })
		local joined = poll(function()
			local current = realPlayer()
			return current:GetAttribute("PlotId") == join.plotId and current:GetAttribute("ActiveSaveRole") == "Member"
		end, 10)
		check(
			joined,
			string.format(
				"PlotId %s (expected %s), role %s",
				tostring(realPlayer():GetAttribute("PlotId")),
				tostring(join.plotId),
				tostring(realPlayer():GetAttribute("ActiveSaveRole"))
			)
		)
		R.plotId = join.plotId
		check(#finderListings(R.userId).listings == 0, "a full listing is still shown")
		saveRefusedAs(S2.userId, "Save.FinderJoin", { saveId = S.finderSaveId }, "ListingGone")
		saveActOk("Save.LeaveTeam", { saveId = S.finderSaveId })
		playSave(ctx.saveA)

		local again = saveActAsOk(S.userId, "Save.FinderStart", {})
		check(again.created == false and again.saveId == S.finderSaveId, "the search did not list the same save")
		check(#finderListings(R.userId).listings == 1, "the relisted save is not shown")
		saveActAsOk(S.userId, "Save.FinderStop", {})
		check(#finderListings(R.userId).listings == 0, "a stopped listing is still shown")
		local third = saveActAsOk(S.userId, "Save.FinderStart", {})
		check(third.saveId == S.finderSaveId, "the third search listed another save")
		check(#finderListings(R.userId).listings == 1, "the listing is not shown again")
		local other = shadowOtherSave()
		check(other ~= nil, "shadow has no other own save")
		S.plotId = saveActAsOk(S.userId, "Save.Play", { saveId = other.saveId }).plotId
		check(#finderListings(R.userId).listings == 0, "the listing outlived the switch")
		check(deleteFinderSave(), "the finder save was not deleted")
		return string.format("listed, joined on %s, left, relisted, stopped, switched, deleted", tostring(join.plotId))
	end)
end
