--!strict
-- Playtest steps 60-61 (full mode): day/night per save (CM2-G12a, docs/plans/CM2-G12a.md).
-- Installed by RunPlaytest.execute after Steps/Progression. Step 60 drives the real player's
-- day clock through dusk and a day rollover and checks the attributes, the summary and the
-- saved day after a rejoin; step 61 counts the server's night lights (all off on the server):
-- 22 lamps, 2 plot-sign lights and (CM2-GATEW) 2 gate lights per plot = 46.
return function(ctx: any)
	local R = ctx.R
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local call = ctx.call
	local rejoin = ctx.rejoin
	local check = ctx.check
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local snap = ctx.snap

	local CollectionService = game:GetService("CollectionService")
	local TAG = ctx.GameConfig.DayCycle.NightLightTag
	local LAMP_COUNT = 22
	local PLOT_LIGHTS = 6 * 2
	local GATE_LIGHTS = 6 * 2 -- CM2-GATEW

	local function setDay(elapsed: number): any
		return call("setDay", { userId = R.userId, elapsed = elapsed })
	end

	local function dayView(): any
		return call("dayView", R.userId)
	end

	addStep("60", "DAY_CYCLE", { "03" }, function()
		-- (a) dusk: the clock runs into the night; the arrival rate halves.
		setDay(719)
		local view: any = nil
		local night = poll(function()
			view = dayView()
			return view.night == true
		end, 4)
		check(night, "no night within 4 s after elapsed 719: " .. tostring(view and view.elapsed))
		check(view.arrivalRate == 0.5, "night arrival rate " .. tostring(view.arrivalRate))
		local player = realPlayer()
		check(
			player:GetAttribute("DayNumber") == view.day,
			string.format("DayNumber %s, view day %s", tostring(player:GetAttribute("DayNumber")), tostring(view.day))
		)
		local elapsedAttribute = player:GetAttribute("DayElapsed")
		check(
			type(elapsedAttribute) == "number" and elapsedAttribute >= 719,
			"DayElapsed " .. tostring(elapsedAttribute)
		)
		check(type(player:GetAttribute("DaySyncAt")) == "number", "DaySyncAt is not a number")

		-- (b) the summary carries the day and the night.
		local summary = actOk(R.userId, "Company.GetSummary", {})
		check(summary.day == view.day, string.format("summary day %s, view day %s", tostring(summary.day), view.day))
		check(summary.night == true, "summary night " .. tostring(summary.night))

		-- (c) the day rolls over and the attribute follows.
		local before = view.day
		setDay(1079)
		local rolled = poll(function()
			view = dayView()
			return view.day == before + 1 and view.elapsed < 6
		end, 5)
		check(
			rolled,
			string.format("no rollover within 5 s: day %s, elapsed %s", tostring(view.day), tostring(view.elapsed))
		)
		local attributeFollowed = poll(function()
			return realPlayer():GetAttribute("DayNumber") == before + 1
		end, 2)
		check(
			attributeFollowed,
			string.format("DayNumber %s, expected %d", tostring(realPlayer():GetAttribute("DayNumber")), before + 1)
		)

		-- (d) the rolled day is saved and survives a rejoin.
		call("flush", nil)
		rejoin(R.userId)
		local saved = snap(R.userId).dayCycle
		check(
			type(saved) == "table" and saved.day == before + 1,
			"day after rejoin " .. tostring(type(saved) == "table" and saved.day)
		)

		-- (e) back to the morning for the later steps.
		setDay(0)
		return string.format("day %d, night rate 0.5, rolled to %d, persisted", before, before + 1)
	end)

	addStep("61", "NIGHT_LIGHTS", {}, function()
		local tagged = CollectionService:GetTagged(TAG)
		local lights = 0
		for _, instance in tagged do
			check(instance:IsA("Light"), "tagged instance is not a Light: " .. instance:GetFullName())
			check((instance :: Light).Enabled == false, "night light enabled on the server: " .. instance:GetFullName())
			lights += 1
		end
		check(
			lights == LAMP_COUNT + PLOT_LIGHTS + GATE_LIGHTS,
			string.format("%d night lights, expected %d", lights, LAMP_COUNT + PLOT_LIGHTS + GATE_LIGHTS)
		)

		local world = workspace:FindFirstChild("ChristmasMarketWorld")
		local map = world and world:FindFirstChild("Map")
		check(map ~= nil, "ChristmasMarketWorld.Map is missing")
		local lamps = 0
		for _, descendant in (map :: Instance):GetDescendants() do
			local piece = descendant:GetAttribute("MapPiece")
			if descendant:IsA("Model") and type(piece) == "string" and string.match(piece, "^Lamp_%d%d$") then
				lamps += 1
				local group = descendant.Parent
				check(
					group ~= nil and group.Parent == map and (group.Name == "Square" or group.Name == "Street"),
					descendant:GetFullName() .. " is not under Map.Square or Map.Street"
				)
				local own = 0
				for _, inner in descendant:GetDescendants() do
					if inner:IsA("Light") and CollectionService:HasTag(inner, TAG) then
						own += 1
					end
				end
				check(own == 1, string.format("%s holds %d night lights", descendant:GetFullName(), own))
			end
		end
		check(lamps == LAMP_COUNT, string.format("%d lamp models, expected %d", lamps, LAMP_COUNT))
		return string.format("%d night lights off on the server, %d lamps with one each", lights, lamps)
	end)
end
