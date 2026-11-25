--!strict
-- Playtest helpers for save slots (CM2-S1), co-op saves (CM2-S2), CM2-S3 and activeSave.
-- Installed by RunPlaytest.execute (CM2-RF).
return function(ctx: any)
	local ACTION_PAUSE = ctx.ACTION_PAUSE
	local R = ctx.R
	local S = ctx.S
	local StudioTestService = ctx.StudioTestService
	local call = ctx.call
	local check = ctx.check
	local invoke = ctx.invoke
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer

	-- Save slots (CM2-S1) --------------------------------------------------------------------
	local SAVE_A, SAVE_B, SAVE_B2, SAVE_C = "Playtest A", "Playtest B", "Playtest B2", "Playtest C"
	ctx.saveA = ""

	-- One Save.* request for a user (the player or a synthetic one). A rate-limited request is
	-- retried once after the window. A SaveActionBusy answer is retried up to 5 times, 1 s apart:
	-- the real client's picker lists while the player has no active save, and the server refuses
	-- a busy request before any change.
	local function saveActAs(userId: number, action: string, payload: any, requestId: string?): any
		local arg = { userId = userId, action = action, payload = payload, requestId = requestId }
		local response = invoke("saveAction", arg)
		local busyRetries, rateRetried = 0, false
		while type(response) == "table" do
			if response.errorCode == "RateLimited" and not rateRetried then
				rateRetried = true
				task.wait(61)
			elseif response.errorCode == "SaveActionBusy" and busyRetries < 5 then
				busyRetries += 1
				task.wait(1)
			else
				break
			end
			response = invoke("saveAction", arg)
		end
		task.wait(ACTION_PAUSE)
		return response
	end

	local function saveAct(action: string, payload: any, requestId: string?): any
		return saveActAs(R.userId, action, payload, requestId)
	end

	local function saveActOk(action: string, payload: any, requestId: string?): any
		local response = saveAct(action, payload, requestId)
		check(
			type(response) == "table" and response.ok == true,
			string.format(
				"%s failed: %s",
				action,
				tostring(type(response) == "table" and response.errorCode or response)
			)
		)
		return response.data
	end

	local function saveRefused(action: string, payload: any, expected: string)
		local response = saveAct(action, payload)
		local code = type(response) == "table" and response.errorCode or response
		check(code == expected, string.format("%s returned %s, expected %s", action, tostring(code), expected))
	end

	local function saveList(): { any }
		return call("saves", R.userId)
	end

	local function findSave(name: string): any
		for _, entry in saveList() do
			if entry.name == name then
				return entry
			end
		end
		return nil
	end

	-- Plays a save and waits until the player is ready on it.
	local function playSave(saveId: string)
		saveActOk("Save.Play", { saveId = saveId })
		local ready = poll(function()
			local current = realPlayer()
			return current:GetAttribute("CompanyReady") == true and current:GetAttribute("ActiveSaveId") == saveId
		end, 10)
		check(ready, "save " .. saveId .. " not ready within 10 s")
		R.plotId = realPlayer():GetAttribute("PlotId")
	end

	-- Deletes a leftover save from an earlier run; a stolen test lock is cleared first.
	local function deleteLeftover(name: string): boolean
		local entry = findSave(name)
		if not entry then
			return false
		end
		call("unlockSave", { userId = R.userId, saveId = entry.saveId })
		saveActOk("Save.Delete", { saveId = entry.saveId, confirmName = name })
		return true
	end

	-- Co-op saves (CM2-S2): the shadow and a second synthetic user act through saveAction/act,
	-- so they hit the same server paths a real client would.
	local SAVE_DUO = "Playtest Duo"
	local S2 = { userId = StudioTestService.SHADOW_2_USER_ID }

	local function saveActAsOk(userId: number, action: string, payload: any): any
		local response = saveActAs(userId, action, payload)
		check(
			type(response) == "table" and response.ok == true,
			string.format(
				"%s for %s failed: %s",
				action,
				tostring(userId),
				tostring(type(response) == "table" and response.errorCode or response)
			)
		)
		return response.data
	end

	local function saveRefusedAs(userId: number, action: string, payload: any, expected: string)
		local response = saveActAs(userId, action, payload)
		local code = type(response) == "table" and response.errorCode or response
		check(
			code == expected,
			string.format("%s for %s returned %s, expected %s", action, tostring(userId), tostring(code), expected)
		)
	end

	local function rowOf(userId: number, saveId: string): any
		for _, entry in call("saves", userId) do
			if entry.saveId == saveId then
				return entry
			end
		end
		return nil
	end

	local function memberOf(team: any, userId: number): any
		for _, member in team.members do
			if member.userId == userId then
				return member
			end
		end
		return nil
	end

	-- One server per save and the teammate finder (CM2-S3).
	local SAVE_FAR = "Playtest Far"

	-- The raw save-to-server map value for one of the player's saves.
	local function locatorEntry(saveId: string): any
		return call("locatorEntry", { userId = R.userId, saveId = saveId }).entry
	end

	-- Deletes a leftover "Playtest Far" after clearing its fake foreign map entry.
	local function deleteFar(): boolean
		local entry = findSave(SAVE_FAR)
		if not entry then
			return false
		end
		call("clearElsewhere", { userId = R.userId, saveId = entry.saveId })
		return deleteLeftover(SAVE_FAR)
	end

	local function finderListings(userId: number): any
		return saveActAsOk(userId, "Save.FinderList", {})
	end

	-- The shadow's most recently played owned save other than the finder save.
	local function shadowOtherSave(): any
		for _, entry in call("saves", S.userId) do
			if entry.role == "Owner" and entry.saveId ~= S.finderSaveId then
				return entry
			end
		end
		return nil
	end

	-- Removes the finder save if a failed run left it: the player leaves its team, the shadow
	-- switches away and deletes it.
	local function deleteFinderSave(): boolean
		local finderSaveId = S.finderSaveId
		if finderSaveId == nil then
			return false
		end
		if rowOf(R.userId, finderSaveId) ~= nil then
			saveActOk("Save.LeaveTeam", { saveId = finderSaveId })
		end
		local row = rowOf(S.userId, finderSaveId)
		if row == nil then
			S.finderSaveId = nil
			return false
		end
		if row.active then
			local other = shadowOtherSave()
			check(other ~= nil, "shadow has no other own save")
			S.plotId = saveActAsOk(S.userId, "Save.Play", { saveId = other.saveId }).plotId
		end
		saveActAsOk(S.userId, "Save.Delete", { saveId = finderSaveId, confirmName = row.name })
		S.finderSaveId = nil
		return true
	end

	-- Puts the shadow on a clean slate for step 35: stops its listing, plays its first owned Solo
	-- save (creating one if absent) and deletes every other shadow-owned save; returns the delete
	-- count. The shadow never owns a co-op save outside step 35 (steps 29-32 use R's "Playtest
	-- Duo"), so every shadow-owned co-op save is a finder leftover.
	local function shadowCleanSlate(): number
		saveActAsOk(S.userId, "Save.FinderStop", {})
		local function ownedRows(): { any }
			local rows = {}
			for _, row in call("saves", S.userId) do
				if row.role == "Owner" then
					table.insert(rows, row)
				end
			end
			return rows
		end
		local function firstSolo(rows: { any }): any
			for _, row in rows do
				if row.size == "Solo" then
					return row
				end
			end
			return nil
		end
		local rows = ownedRows()
		local solo = firstSolo(rows)
		if solo == nil then
			saveActAsOk(S.userId, "Save.Create", {})
			rows = ownedRows()
			solo = firstSolo(rows)
			check(solo ~= nil, "the shadow has no Solo save after Save.Create")
		end
		if solo.active ~= true then
			S.plotId = saveActAsOk(S.userId, "Save.Play", { saveId = solo.saveId }).plotId
		end
		local deleted = 0
		for _, row in rows do
			if row.size ~= "Solo" then
				if rowOf(R.userId, row.saveId) ~= nil then
					saveActOk("Save.LeaveTeam", { saveId = row.saveId })
				end
				saveActAsOk(S.userId, "Save.Delete", { saveId = row.saveId, confirmName = row.name })
				deleted += 1
			end
		end
		return deleted
	end

	local function activeSave(): string
		local entry = findSave(SAVE_A)
		local created = entry == nil
		if entry then
			ctx.saveA = entry.saveId
		else
			ctx.saveA = saveActOk("Save.Create", { name = SAVE_A }).saveId
		end
		playSave(ctx.saveA)
		check(type(R.plotId) == "string", "no PlotId after playing " .. SAVE_A)
		return string.format("%s %s, plot %s", SAVE_A, if created then "created" else "found", tostring(R.plotId))
	end

	ctx.SAVE_A = SAVE_A
	ctx.SAVE_B = SAVE_B
	ctx.SAVE_B2 = SAVE_B2
	ctx.SAVE_C = SAVE_C
	ctx.saveActAs = saveActAs
	ctx.saveAct = saveAct
	ctx.saveActOk = saveActOk
	ctx.saveRefused = saveRefused
	ctx.saveList = saveList
	ctx.findSave = findSave
	ctx.playSave = playSave
	ctx.deleteLeftover = deleteLeftover
	ctx.SAVE_DUO = SAVE_DUO
	ctx.S2 = S2
	ctx.saveActAsOk = saveActAsOk
	ctx.saveRefusedAs = saveRefusedAs
	ctx.rowOf = rowOf
	ctx.memberOf = memberOf
	ctx.SAVE_FAR = SAVE_FAR
	-- Guided tutorial (CM2-49, steps 54 and 55).
	ctx.SAVE_T = "Playtest T"
	ctx.SAVE_T2 = "Playtest T2"
	ctx.locatorEntry = locatorEntry
	ctx.deleteFar = deleteFar
	ctx.finderListings = finderListings
	ctx.shadowOtherSave = shadowOtherSave
	ctx.deleteFinderSave = deleteFinderSave
	ctx.activeSave = activeSave
	ctx.shadowCleanSlate = shadowCleanSlate
end
