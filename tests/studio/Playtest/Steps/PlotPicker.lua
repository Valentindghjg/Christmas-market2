--!strict
-- Playtest step 65 (full mode): plot picker (CM2-PP).
-- Installed by RunPlaytest.execute after Steps/Trees. Lists the plots for a fresh save
-- (Save.Plots), refuses the shadow's plot with PlotTaken while the running save stays, plays the
-- fresh save on a chosen free plot, then plays "Playtest A" back onto its original plot and
-- refuses an unknown plot id.
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- CM2-PP: `65 PLOT_PICK` in `Steps/PlotPicker.lua` (a fresh save "Playtest P": `Save.Plots` lists 6
-- plots `Plot_01`..`Plot_06` with `number` 1-6, `side` South for 1-3 and North for 4-6, the
-- shadow's plot taken (`name` nil or non-empty), R's own plot free and a free `preselectId`;
-- `Save.Play {saveId, plotId = S's plot}` is `PlotTaken` while R stays on "Playtest A"; the save
-- plays on the first other free plot within 10 s, after which `Save.Plots` offers no pick;
-- "Playtest A" plays back on its original plot; `plotId = "Plot_9"` is `InvalidPlotId`; "Playtest
-- P" is deleted). The teleport-arrival picker (`PlotPickSaveId`) stays BLOCKED in Studio
-- (TeleportService) and is covered headless.
-- The teleport-arrival picker (`PlotPickSaveId`) stays BLOCKED in Studio (TeleportService) and is
-- covered headless.
return function(ctx: any)
	local R = ctx.R
	local S = ctx.S
	local addStep = ctx.addStep
	local check = ctx.check
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local saveActOk = ctx.saveActOk
	local saveRefused = ctx.saveRefused
	local deleteLeftover = ctx.deleteLeftover

	local SAVE_P = "Playtest P"

	addStep("65", "PLOT_PICK", { "02", "02a" }, function()
		-- 1. A fresh save while the player plays "Playtest A" and the shadow holds its plot.
		deleteLeftover(SAVE_P)
		check(type(S.plotId) == "string", "the shadow holds no plot")
		local origin = realPlayer():GetAttribute("PlotId")
		check(type(origin) == "string", "the player holds no plot")
		local saveP = saveActOk("Save.Create", { name = SAVE_P }).saveId

		-- 2. The plot list.
		local list = saveActOk("Save.Plots", { saveId = saveP })
		check(list.pick == true, "Save.Plots offers no pick for a fresh save")
		check(list.total == 6, "Save.Plots total " .. tostring(list.total) .. ", expected 6")
		check(type(list.plots) == "table" and #list.plots == 6, "Save.Plots does not list 6 plots")
		local freeIds: { [string]: boolean } = {}
		for index, row in list.plots do
			local expectedId = string.format("Plot_%02d", index)
			check(
				row.plotId == expectedId,
				string.format("row %d is %s, expected %s", index, tostring(row.plotId), expectedId)
			)
			check(row.number == index, string.format("row %d has number %s", index, tostring(row.number)))
			local side = if index <= 3 then "South" else "North"
			check(row.side == side, string.format("row %d side %s, expected %s", index, tostring(row.side), side))
			if row.plotId == S.plotId then
				check(row.free == false, "the shadow's plot is listed as free")
				check(
					row.name == nil or (type(row.name) == "string" and row.name ~= ""),
					"the shadow's plot has a bad name " .. tostring(row.name)
				)
			end
			if row.plotId == origin then
				check(row.free == true, "the player's own plot is not free for a switch")
			end
			if row.free == true then
				freeIds[row.plotId] = true
			end
		end
		check(
			type(list.preselectId) == "string" and freeIds[list.preselectId] == true,
			"preselectId is not a free plot"
		)

		-- 3. A taken plot is refused before the running save is left.
		saveRefused("Save.Play", { saveId = saveP, plotId = S.plotId }, "PlotTaken")
		check(realPlayer():GetAttribute("ActiveSaveId") == ctx.saveA, "PlotTaken dropped the running save")

		-- 4. The fresh save on a chosen free plot.
		local target: string? = nil
		for _, row in list.plots do
			if row.free == true and row.plotId ~= origin then
				target = row.plotId
				break
			end
		end
		check(target ~= nil, "no free plot besides the player's own")
		local played = saveActOk("Save.Play", { saveId = saveP, plotId = target })
		check(played.plotId == target, "Save.Play returned plot " .. tostring(played.plotId))
		local moved = poll(function()
			local current = realPlayer()
			return current:GetAttribute("PlotId") == target and current:GetAttribute("ActiveSaveId") == saveP
		end, 10)
		check(moved, "the player is not on " .. tostring(target) .. " within 10 s")

		-- 5. The active save needs no pick.
		check(saveActOk("Save.Plots", { saveId = saveP }).pick == false, "the active save offers a pick")

		-- 6. "Playtest A" back on its original plot.
		local back = saveActOk("Save.Play", { saveId = ctx.saveA, plotId = origin })
		check(back.plotId == origin, "Playtest A returned to " .. tostring(back.plotId))
		local ready = poll(function()
			local current = realPlayer()
			return current:GetAttribute("CompanyReady") == true and current:GetAttribute("ActiveSaveId") == ctx.saveA
		end, 10)
		check(ready, "Playtest A not ready within 10 s")
		R.plotId = origin

		-- 7. An unknown plot id, then cleanup.
		saveRefused("Save.Play", { saveId = ctx.saveA, plotId = "Plot_9" }, "InvalidPlotId")
		saveActOk("Save.Delete", { saveId = saveP, confirmName = SAVE_P })
		return string.format("6 plots, %s taken, chose %s, back on %s", S.plotId, tostring(target), origin)
	end)
end
