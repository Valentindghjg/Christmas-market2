--!strict
-- CM2-40: layout math and money format for the HUD, the Lot Manager and the dialogs.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local UiTheme = require(Shared:WaitForChild("UiTheme"))
	local UiStyle = require(Shared:WaitForChild("UiStyle"))
	local expect = t.expect

	-- Safe-area sizes (W x H): the first three are phones.
	local MATRIX = {
		{ name = "phone 667x317", w = 667, h = 317, compact = true },
		{ name = "android 780x302", w = 780, h = 302, compact = true },
		{ name = "notched phone 750x332", w = 750, h = 332, compact = true },
		{ name = "tablet 1024x710", w = 1024, h = 710, compact = false },
		{ name = "tablet 960x542", w = 960, h = 542, compact = false },
		{ name = "pc 1920x1022", w = 1920, h = 1022, compact = false },
	}
	local DIALOGS = { "Picker", "DeleteConfirm", "Team", "Finder", "Quests" }
	-- CM2-UI3: phone safe-area sizes (W x H) and the box sizes {w, h} the layouts returned before
	-- CM2-UI3; no phone box may exceed these (22a3 (a)).
	local PHONES = { { 667, 317 }, { 780, 302 }, { 750, 332 }, { 666, 374 }, { 780, 281 } }
	local BASELINE = {
		["667x317"] = {
			manager = { 651, 301 },
			hud = { 442, 74 },
			toast = { 387, 44 },
			actionBar = { 233, 44 },
			rail6 = { 124, 205 },
			rail8 = { 124, 205 },
			stocking = { 333, 154 },
			tutorial = { 387, 56 },
			tutorialDocked = { 116, 56 },
			Advent = { 651, 301 },
			DeleteConfirm = { 651, 301 },
			Event = { 651, 301 },
			Finder = { 651, 301 },
			Music = { 466, 253 },
			Picker = { 651, 301 },
			Quests = { 651, 301 },
			Shop = { 651, 301 },
			Team = { 651, 301 },
			plotPanel = { 520, 176 },
			plotConfirm = { 360, 120 },
		},
		["780x302"] = {
			manager = { 764, 286 },
			hud = { 442, 74 },
			toast = { 460, 44 },
			actionBar = { 273, 44 },
			rail6 = { 314, 188 },
			rail8 = { 124, 190 },
			stocking = { 390, 154 },
			tutorial = { 500, 56 },
			tutorialDocked = { 116, 56 },
			Advent = { 760, 286 },
			DeleteConfirm = { 760, 286 },
			Event = { 760, 286 },
			Finder = { 760, 286 },
			Music = { 546, 241 },
			Picker = { 760, 286 },
			Quests = { 760, 286 },
			Shop = { 760, 286 },
			Team = { 760, 286 },
			plotPanel = { 520, 176 },
			plotConfirm = { 360, 120 },
		},
		["750x332"] = {
			manager = { 734, 316 },
			hud = { 442, 74 },
			toast = { 460, 44 },
			actionBar = { 262, 44 },
			rail6 = { 284, 188 },
			rail8 = { 124, 220 },
			stocking = { 375, 154 },
			tutorial = { 470, 56 },
			tutorialDocked = { 116, 56 },
			Advent = { 734, 316 },
			DeleteConfirm = { 734, 316 },
			Event = { 734, 316 },
			Finder = { 734, 316 },
			Music = { 525, 265 },
			Picker = { 734, 316 },
			Quests = { 734, 316 },
			Shop = { 734, 316 },
			Team = { 734, 316 },
			plotPanel = { 520, 176 },
			plotConfirm = { 360, 120 },
		},
		["666x374"] = {
			manager = { 650, 358 },
			hud = { 442, 74 },
			toast = { 386, 44 },
			actionBar = { 233, 44 },
			rail6 = { 200, 236 },
			rail8 = { 124, 262 },
			stocking = { 333, 154 },
			tutorial = { 386, 56 },
			tutorialDocked = { 116, 56 },
			Advent = { 650, 358 },
			DeleteConfirm = { 650, 358 },
			Event = { 650, 358 },
			Finder = { 650, 358 },
			Music = { 466, 299 },
			Picker = { 650, 358 },
			Quests = { 650, 358 },
			Shop = { 650, 358 },
			Team = { 650, 358 },
			plotPanel = { 520, 176 },
			plotConfirm = { 360, 120 },
		},
		["780x281"] = {
			manager = { 764, 265 },
			hud = { 442, 74 },
			toast = { 460, 44 },
			actionBar = { 273, 44 },
			rail6 = { 124, 169 },
			rail8 = { 124, 169 },
			stocking = { 390, 154 },
			tutorial = { 500, 56 },
			tutorialDocked = { 116, 56 },
			Advent = { 760, 265 },
			DeleteConfirm = { 760, 265 },
			Event = { 760, 265 },
			Finder = { 760, 265 },
			Music = { 546, 224 },
			Picker = { 760, 265 },
			Quests = { 760, 265 },
			Shop = { 760, 265 },
			Team = { 760, 265 },
			plotPanel = { 520, 176 },
			plotConfirm = { 360, 120 },
		},
	}

	local function absolute(parent, relative)
		return { x = parent.x + relative.x, y = parent.y + relative.y, w = relative.w, h = relative.h }
	end

	local function noNegativeSize(b)
		expect.truthy(b.w >= 0)
		expect.truthy(b.h >= 0)
	end

	t.test("formats money with thousands separators", function()
		expect.equal(UiTheme.formatMoney(0), "0")
		expect.equal(UiTheme.formatMoney(56), "56")
		expect.equal(UiTheme.formatMoney(1615), "1,615")
		expect.equal(UiTheme.formatMoney(1250000), "1,250,000")
		expect.equal(UiTheme.formatMoney(-1200), "-1,200")
		expect.equal(UiTheme.formatMoney(12.7), "12")
	end)

	t.test("world label layouts are complete", function()
		for _, id in ipairs({ "Bay", "DisplayTree", "CarNumber", "PickupOrder", "Speech" }) do
			local layout = UiTheme.WorldLabels[id]
			expect.truthy(layout ~= nil)
			expect.truthy(layout.w > 0)
			expect.truthy(layout.h > 0)
			expect.truthy(layout.textSize > 0)
			expect.truthy(layout.height > 0)
			expect.truthy(layout.maxDistance > 0)
			expect.truthy(layout.stagger >= 0)
		end
		expect.equal(UiTheme.WorldLabels.PickupOrder.wrap, false)
		expect.equal(UiTheme.WorldLabels.CarNumber.wrap, false)
	end)

	t.test("picks compact for phones and regular for tablets and PC", function()
		for _, size in ipairs(MATRIX) do
			expect.equal(UiTheme.metrics(size.w, size.h).compact, size.compact)
		end
		local tiny = UiTheme.metrics(1, 1)
		expect.truthy(tiny.compact)
		expect.truthy(tiny.railMaxHeight >= 0)
		local layout = UiTheme.hudLayout(tiny, 4)
		noNegativeSize(layout.hud)
		noNegativeSize(layout.status)
		noNegativeSize(layout.rail)
		noNegativeSize(layout.toast)
		noNegativeSize(layout.actionBar)
		noNegativeSize(layout.manager)
		for _, chip in ipairs(layout.chips) do
			noNegativeSize(chip.box)
		end
		local managerLayout = UiTheme.managerLayout(tiny, layout.manager)
		noNegativeSize(managerLayout.header)
		noNegativeSize(managerLayout.title)
		noNegativeSize(managerLayout.close)
		noNegativeSize(managerLayout.tabBar)
		noNegativeSize(managerLayout.body)
		for _, tab in ipairs(managerLayout.tabs) do
			noNegativeSize(tab)
		end
		for _, name in ipairs(DIALOGS) do
			local dialog = UiTheme.dialogLayout(tiny, UiTheme.Dialogs[name])
			noNegativeSize(dialog.frame)
			expect.truthy(dialog.innerWidth >= 0)
			expect.truthy(dialog.innerHeight >= 0)
			if dialog.list then
				noNegativeSize(dialog.list)
			end
			if dialog.footer then
				noNegativeSize(dialog.footer)
			end
			if dialog.rightHeader then
				noNegativeSize(dialog.rightHeader)
			end
		end
	end)

	t.test("keeps the HUD inside the safe area without overlaps", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			local layout = UiTheme.hudLayout(m, 4)
			local status = absolute(layout.hud, layout.status)
			local boxes = {
				hud = layout.hud,
				status = status,
				rail = layout.rail,
				toast = layout.toast,
				actionBar = layout.actionBar,
			}
			for _, b in pairs(boxes) do
				expect.truthy(UiTheme.inside(b, size.w, size.h))
			end
			-- The status line sits inside the HUD strip; the other areas never share pixels.
			local separate = { "hud", "rail", "toast", "actionBar" }
			for first = 1, #separate do
				for second = first + 1, #separate do
					expect.falsy(UiTheme.overlaps(boxes[separate[first]], boxes[separate[second]]))
				end
			end
			expect.truthy(UiTheme.inside(status, layout.hud.x + layout.hud.w, layout.hud.y + layout.hud.h))
			local ids = {}
			for index, chip in ipairs(layout.chips) do
				ids[chip.id] = true
				local placed = absolute(layout.hud, chip.box)
				expect.truthy(UiTheme.inside(placed, size.w, size.h))
				expect.falsy(UiTheme.overlaps(placed, status))
				for other = index + 1, #layout.chips do
					expect.falsy(UiTheme.overlaps(placed, absolute(layout.hud, layout.chips[other].box)))
				end
			end
			expect.truthy(ids.Cash)
			expect.truthy(ids.Reputation)
			expect.truthy(ids.Lot)
			expect.truthy(ids.Day)
			if m.compact then
				expect.truthy(layout.rail.y + layout.rail.h <= size.h - 96)
			end
		end
	end)

	t.test("scrolls the rail instead of overflowing", function()
		local phone = UiTheme.metrics(667, 317)
		local crowded = UiTheme.hudLayout(phone, 7)
		expect.truthy(crowded.railScrolls)
		expect.equal(crowded.rail.h, phone.railMaxHeight)
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			if m.compact then
				expect.falsy(UiTheme.hudLayout(m, 4).railScrolls)
			end
		end
	end)

	-- CM2-UVF13: every rail button (FinderButton is the fifth, rail order 70) stays a 44 px touch
	-- target, ends above the thumbstick ring (top 93 px above the GUI bottom) and clear of the HUD.
	t.test("keeps every phone rail button above the thumbstick", function()
		local sizes = { { w = 666, h = 316 }, { w = 667, h = 317 } }
		for _, size in ipairs(MATRIX) do
			if size.compact then
				table.insert(sizes, size)
			end
		end
		expect.equal(UiTheme.metrics(666, 316).railMaxHeight, 204)
		for _, size in ipairs(sizes) do
			local m = UiTheme.metrics(size.w, size.h)
			expect.truthy(m.compact)
			for count = 1, 5 do
				local layout = UiTheme.hudLayout(m, count)
				expect.equal(#layout.railButtons, count)
				expect.falsy(layout.railScrolls)
				local placed = {}
				for index, relative in ipairs(layout.railButtons) do
					local b = absolute(layout.rail, relative)
					expect.truthy(b.h >= 44)
					expect.truthy(b.w >= 72)
					expect.truthy(b.x >= layout.rail.x)
					expect.truthy(b.y >= layout.rail.y)
					expect.truthy(b.x + b.w <= layout.rail.x + layout.rail.w)
					expect.truthy(b.y + b.h <= layout.rail.y + layout.rail.h)
					expect.truthy(b.y + b.h <= size.h - 93 - 8)
					expect.truthy(b.x + b.w <= layout.hud.x - 8)
					expect.falsy(UiTheme.overlaps(b, layout.hud))
					expect.falsy(UiTheme.overlaps(b, layout.toast))
					for _, other in ipairs(placed) do
						expect.falsy(UiTheme.overlaps(b, other))
					end
					table.insert(placed, b)
					expect.truthy(index <= count)
				end
			end
		end
		local layout = UiTheme.hudLayout(UiTheme.metrics(666, 316), 5)
		expect.equal(layout.railButtons[5].x, 122)
		expect.equal(layout.railButtons[5].y, 0)
		expect.equal(layout.railButtons[5].w, 78)
		expect.equal(layout.railButtons[5].h, 44)
		expect.equal(layout.rail.x, 8)
		expect.equal(layout.rail.y, 8)
		expect.equal(layout.rail.w, 200)
		expect.equal(layout.rail.h, 188)
	end)

	-- CM2-UIFIX: the desktop rail keeps RailInset (6 px) round its buttons.
	t.test("keeps the regular rail as one column", function()
		for _, size in ipairs({ { w = 1920, h = 1022 }, { w = 1024, h = 710 } }) do
			local m = UiTheme.metrics(size.w, size.h)
			for count = 1, 5 do
				local layout = UiTheme.hudLayout(m, count)
				expect.equal(layout.rail.w, m.railWidth)
				expect.equal(layout.rail.h, count * 44 + (count - 1) * m.railGap + 12)
				for index = 1, count do
					local b = layout.railButtons[index]
					expect.equal(b.x, 6)
					expect.equal(b.y, 6 + (index - 1) * (44 + m.railGap))
					expect.equal(b.w, m.railWidth - 12)
					expect.equal(b.h, 44)
				end
			end
		end
	end)

	-- CM2-UIFIX: no desktop rail button, its Border stroke or its hover scale reaches the rail edge.
	t.test("keeps desktop rail buttons and strokes inside the rail", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			if not m.compact then
				for count = 1, 9 do
					local layout = UiTheme.hudLayout(m, count)
					for _, relative in ipairs(layout.railButtons) do
						local b = absolute(layout.rail, relative)
						expect.truthy(b.x >= m.margin + UiTheme.RailInset)
						local grow = UiTheme.Style.StrokeControl + math.ceil(0.025 * b.w)
						local grown = { x = b.x - grow, y = b.y - grow, w = b.w + 2 * grow, h = b.h + 2 * grow }
						if layout.railScrolls then
							-- x stays clear of the scroll bar; the canvas holds the grown button vertically.
							expect.truthy(grown.x >= layout.rail.x)
							expect.truthy(grown.x + grown.w <= layout.rail.x + layout.rail.w - UiTheme.RailScrollBar)
							local canvasY = grown.y - layout.rail.y
							expect.truthy(canvasY >= 0 and canvasY + grown.h <= layout.railCanvas)
						else
							expect.truthy(UiTheme.contains(layout.rail, grown, 0))
						end
					end
				end
			end
		end
	end)

	-- CM2-V2-HIDE: nine desktop buttons scroll at 1564x554 with 130 px buttons and an explicit canvas.
	t.test("lays out nine rail buttons on desktop", function()
		local layout = UiTheme.hudLayout(UiTheme.metrics(1564, 554), 9)
		expect.equal(layout.rail.x, 12)
		expect.equal(layout.rail.y, 166)
		expect.equal(layout.rail.w, 148)
		expect.equal(layout.rail.h, 376)
		expect.truthy(layout.railScrolls)
		for _, b in ipairs(layout.railButtons) do
			expect.equal(b.x, 6)
			expect.equal(b.w, 130)
		end
		expect.equal(layout.railCanvas, 456)
		local last = layout.railButtons[9]
		expect.equal(last.y + 44 + 6, 456)
		for _, size in ipairs({ { w = 1920, h = 1022 }, { w = 1024, h = 710 } }) do
			local roomy = UiTheme.hudLayout(UiTheme.metrics(size.w, size.h), 9)
			expect.falsy(roomy.railScrolls)
			expect.equal(roomy.railButtons[1].w, 136)
			expect.equal(roomy.railCanvas, roomy.rail.h)
			expect.equal(roomy.railCanvas, 456)
		end
		local one = UiTheme.hudLayout(UiTheme.metrics(1564, 554), 1)
		expect.falsy(one.railScrolls)
		expect.equal(one.railCanvas, one.rail.h)
		expect.equal(one.railCanvas, 56)
	end)

	-- CM2-V2-HIDE: nine phone buttons stay reachable whether the rail scrolls or not.
	t.test("keeps nine phone rail buttons reachable", function()
		for _, size in ipairs(PHONES) do
			local m = UiTheme.metrics(size[1], size[2])
			local layout = UiTheme.hudLayout(m, 9)
			for _, b in ipairs(layout.railButtons) do
				expect.equal(b.h, 44)
				expect.truthy(b.x >= 0)
				if layout.railScrolls then
					expect.truthy(b.x + b.w <= layout.rail.w - UiTheme.RailScrollBar)
					expect.truthy(b.y + b.h <= layout.railCanvas)
				else
					expect.truthy(UiTheme.contains({ x = 0, y = 0, w = layout.rail.w, h = layout.rail.h }, b, 0))
				end
			end
			if layout.railScrolls then
				expect.equal(layout.railCanvas, 9 * 44 + 8 * m.railGap)
			end
		end
	end)

	-- CM2-V2-HIDE A1: the scroll bar is subtracted once from the frame's box.
	t.test("fits scrolled rail strokes clear of the bar", function()
		local outer = { x = 12, y = 166, w = 148, h = 376 }
		local function fits(x, y, w, bar)
			return UiTheme.fitsScroll(outer, { x = x, y = y, w = w, h = 54 }, bar, 30, 406)
		end
		expect.truthy(fits(13, 137, 140, 4))
		expect.truthy(fits(13, 487, 140, 4))
		expect.falsy(fits(13, 137, 144, 4))
		expect.falsy(fits(13, 135, 140, 4))
		expect.falsy(fits(13, 490, 140, 4))
		expect.truthy(fits(13, 137, 147, 0))
	end)

	-- CM2-UIFIX: the save status is a plate under the chips, 8 px below them.
	t.test("puts the save status below the chips", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			local layout = UiTheme.hudLayout(m, 4)
			local status = absolute(layout.hud, layout.status)
			expect.truthy(layout.status.y >= 36 + 8)
			expect.truthy(UiTheme.inside(status, layout.hud.x + layout.hud.w, layout.hud.y + layout.hud.h))
			expect.truthy(UiTheme.inside(status, size.w, size.h))
			for _, chip in ipairs(layout.chips) do
				expect.falsy(UiTheme.overlaps(status, absolute(layout.hud, chip.box)))
			end
		end
	end)

	t.test("one heading style without outline", function()
		expect.equal(UiTheme.Heading.stroke, 0)
		expect.equal(UiTheme.Heading.textSize, UiTheme.TextSize.Title)
		expect.truthy(UiTheme.Fonts.Weights[UiTheme.Heading.role] ~= nil)
	end)

	-- CM2-V2-HIDE: the windows the Hide HUD button disables.
	t.test("HudHideGuis lists unique names and never the kept screens", function()
		local seen: { [string]: boolean } = {}
		for _, name in ipairs(UiTheme.HudHideGuis) do
			expect.falsy(seen[name])
			seen[name] = true
		end
		expect.equal(#UiTheme.HudHideGuis, 9)
		for _, kept in { "HudRailUI", "TutorialUI", "SavePickerUI", "PlotPickerUI", "StockingUI", "BreakAreaUI" } do
			expect.falsy(seen[kept])
		end
	end)

	t.test("plotNumber", function()
		expect.equal(UiTheme.plotNumber("Plot_01"), "1")
		expect.equal(UiTheme.plotNumber("Plot_12"), "12")
		expect.equal(UiTheme.plotNumber(nil), "?")
		expect.equal(UiTheme.plotNumber("X"), "X")
	end)

	t.test("contains", function()
		local outer = { x = 10, y = 10, w = 100, h = 50 }
		expect.truthy(UiTheme.contains(outer, { x = 20, y = 20, w = 10, h = 10 }, 0))
		expect.truthy(UiTheme.contains(outer, { x = 10, y = 10, w = 100, h = 50 }, 0))
		expect.truthy(UiTheme.contains(outer, { x = 9, y = 10, w = 100, h = 50 }, 1))
		expect.truthy(UiTheme.contains(outer, { x = 10, y = 10, w = 101, h = 51 }, 1))
		expect.falsy(UiTheme.contains(outer, { x = 8, y = 10, w = 100, h = 50 }, 1))
		expect.falsy(UiTheme.contains(outer, { x = 10, y = 10, w = 100, h = 53 }, 1))
	end)

	t.test("fits the Lot Manager on every screen", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			local layout = UiTheme.hudLayout(m, 4)
			expect.truthy(UiTheme.inside(layout.manager, size.w, size.h))
			if not m.compact then
				expect.falsy(UiTheme.overlaps(layout.manager, layout.rail))
				expect.falsy(UiTheme.overlaps(layout.manager, layout.hud))
				expect.falsy(UiTheme.overlaps(layout.manager, absolute(layout.hud, layout.status)))
			end
			local inner = UiTheme.managerLayout(m, layout.manager)
			expect.equal(inner.tabScrolls, m.compact)
			expect.equal(#inner.tabs, 6)
			for _, tab in ipairs(inner.tabs) do
				expect.truthy(tab.w >= 88)
				expect.truthy(tab.h >= 44)
			end
			expect.truthy(inner.body.w >= 340)
			expect.truthy(inner.body.h >= 160)
			expect.falsy(UiTheme.overlaps(inner.title, inner.close))
			if m.compact then
				expect.truthy(inner.cash ~= nil)
				if inner.cash then
					expect.falsy(UiTheme.overlaps(inner.title, inner.cash))
					expect.falsy(UiTheme.overlaps(inner.cash, inner.close))
				end
			else
				expect.equal(inner.cash, nil)
			end
		end
	end)

	-- CM2-G14: the stocking bar stays in the safe area, clear of the HUD and the toast.
	t.test("keeps the stocking bar inside the safe area", function()
		local ids = { "Size", "Rotate", "Row", "GapDown", "Gap", "GapUp", "Store", "Place", "Done" }
		local function checkBar(w: number, h: number)
			local m = UiTheme.metrics(w, h)
			local bar = UiTheme.stockingBarLayout(m)
			local hud = UiTheme.hudLayout(m, 4)
			expect.truthy(UiTheme.inside(bar.frame, w, h))
			expect.falsy(UiTheme.overlaps(bar.frame, hud.hud))
			expect.falsy(UiTheme.overlaps(bar.frame, hud.toast))
			expect.truthy(UiTheme.inside(bar.header, bar.frame.w, bar.frame.h))
			expect.truthy(UiTheme.inside(bar.reason, bar.frame.w, bar.frame.h))
			for index, id in ipairs(ids) do
				local control = bar.controls[id]
				expect.truthy(control ~= nil)
				expect.truthy(control.w >= UiTheme.MinTouch)
				expect.truthy(control.h >= UiTheme.MinTouch)
				expect.truthy(UiTheme.inside(control, bar.frame.w, bar.frame.h))
				expect.falsy(UiTheme.overlaps(control, bar.header))
				expect.falsy(UiTheme.overlaps(control, bar.reason))
				for other = index + 1, #ids do
					expect.falsy(UiTheme.overlaps(control, bar.controls[ids[other]]))
				end
			end
			if m.compact then
				expect.truthy(bar.twoRows)
				expect.truthy(bar.frame.x >= math.floor(0.3 * w))
				expect.truthy(bar.frame.x + bar.frame.w <= math.floor(0.8 * w) + 1)
			end
			return bar
		end
		for _, size in ipairs(MATRIX) do
			checkBar(size.w, size.h)
		end
		expect.truthy(checkBar(720, 520).twoRows)
		expect.falsy(checkBar(1920, 1022).twoRows)
		local tiny = UiTheme.stockingBarLayout(UiTheme.metrics(1, 1))
		for _, b in ipairs({ tiny.frame, tiny.header, tiny.reason }) do
			expect.truthy(b.x >= 0 and b.y >= 0)
			noNegativeSize(b)
		end
		for _, control in pairs(tiny.controls) do
			expect.truthy(control.x >= 0 and control.y >= 0)
			noNegativeSize(control)
		end
	end)

	t.test("fits the picker, delete confirm, Team panel and finder on every screen", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			for _, name in ipairs(DIALOGS) do
				local spec = UiTheme.Dialogs[name]
				local dialog = UiTheme.dialogLayout(m, spec)
				expect.truthy(UiTheme.inside(dialog.frame, size.w, size.h))
				expect.truthy(dialog.frame.y >= 0)
				local list = dialog.list
				local footer = dialog.footer
				if list and footer then
					expect.truthy(list.h >= spec.minList)
					expect.truthy(UiTheme.inside(list, dialog.innerWidth, dialog.innerHeight))
					expect.truthy(UiTheme.inside(footer, dialog.innerWidth, dialog.innerHeight))
					expect.falsy(UiTheme.overlaps(list, footer))
					if m.compact then
						expect.truthy(footer.w >= 200)
						local header = dialog.rightHeader
						expect.truthy(header ~= nil)
						if header and name == "Picker" then
							expect.equal(header.x, footer.x)
							expect.equal(header.y, footer.y + footer.h - 44)
							expect.truthy(
								header.x + header.w + 8 <= footer.x + footer.w - (math.floor(0.4 * footer.w) - 4)
							)
						end
					end
				end
				if name == "DeleteConfirm" then
					expect.equal(list, nil)
					expect.equal(footer, nil)
					expect.truthy(
						dialog.innerHeight
							>= (if m.compact then spec.compactContentHeight or 0 else spec.contentHeight or 0)
					)
				end
			end
		end
	end)

	t.test("save row stacks name, kind, state and buttons", function()
		local r = UiTheme.SaveRow
		expect.truthy(r.nameHeight >= 2 * r.nameTextSize)
		expect.truthy(r.kindHeight >= 2 * r.textSize)
		expect.truthy(r.stateHeight >= r.textSize + 2)
		expect.equal(r.nameHeight + r.kindHeight + r.stateHeight + UiTheme.MinTouch, r.height - 2 * r.padding)
		expect.equal(r.textSize, UiTheme.TextSize.Small)
	end)

	t.test("picker list shows two whole save rows and part of a third", function()
		local sizes = { { 1564, 672 }, { 1024, 710 }, { 1920, 1022 } }
		for _, size in sizes do
			local m = UiTheme.metrics(size[1], size[2])
			local d = UiTheme.dialogLayout(m, UiTheme.Dialogs.Picker)
			local r = UiTheme.SaveRow
			expect.equal(m.compact, false)
			expect.truthy(d.list ~= nil)
			expect.truthy(d.footer ~= nil)
			expect.truthy(d.list.y + d.list.h <= d.footer.y)
			expect.truthy(d.list.h >= 2 * r.height + 2 * r.listGap + 16)
			expect.truthy(d.list.h < 3 * r.height + 2 * r.listGap)
		end
	end)

	-- CM2-49: the tutorial hint bar sits below the toast row, between the rail columns.
	t.test("places the tutorial bar clear of the HUD, toast, rail and stocking bar", function()
		for _, size in ipairs({ { 667, 375 }, { 1024, 768 }, { 1564, 730 }, { 1920, 1080 } }) do
			local w, h = size[1], size[2]
			local m = UiTheme.metrics(w, h)
			local bar = UiTheme.tutorialBarLayout(m)
			local hud = UiTheme.hudLayout(m, 7)
			expect.truthy(UiTheme.inside(bar.frame, w, h))
			expect.falsy(UiTheme.overlaps(bar.frame, hud.hud))
			expect.falsy(UiTheme.overlaps(bar.frame, hud.toast))
			expect.falsy(UiTheme.overlaps(bar.frame, hud.rail))
			expect.falsy(UiTheme.overlaps(bar.frame, UiTheme.stockingBarLayout(m).frame))
			expect.truthy(bar.skip.w >= UiTheme.MinTouch)
			expect.truthy(bar.skip.h >= UiTheme.MinTouch)
			expect.truthy(bar.text.w > 0)
		end
	end)

	-- CM2-UVF10: with stocking mode open on a phone the tutorial bar docks to the Skip button.
	t.test("docks the tutorial bar beside the stocking bar on phones (CM2-UVF10)", function()
		local sizes = {
			{ 666, 374 },
			{ 667, 375 },
			{ 666, 316 },
			{ 667, 317 },
			{ 780, 302 },
			{ 750, 332 },
			{ 1024, 768 },
			{ 1022, 709 },
		}
		for _, size in ipairs(sizes) do
			local w, h = size[1], size[2]
			local m = UiTheme.metrics(w, h)
			local d = UiTheme.tutorialBarLayout(m, true)
			local plain = UiTheme.tutorialBarLayout(m)
			local s = UiTheme.stockingBarLayout(m)
			local hud = UiTheme.hudLayout(m, 7)
			expect.truthy(UiTheme.inside(d.frame, w, h))
			expect.falsy(UiTheme.overlaps(d.frame, s.frame))
			expect.falsy(UiTheme.overlaps(d.frame, hud.hud))
			expect.falsy(UiTheme.overlaps(d.frame, hud.toast))
			expect.falsy(UiTheme.overlaps(d.frame, hud.rail))
			expect.truthy(d.skip.w >= UiTheme.MinTouch)
			expect.truthy(d.skip.h >= UiTheme.MinTouch)
			expect.truthy(UiTheme.inside(d.skip, d.frame.w, d.frame.h))
			expect.truthy(plain.showText)
			if m.compact then
				expect.falsy(d.showText)
				expect.equal(d.frame.w, UiTheme.TutorialBar.skipWidth + 2 * UiTheme.TutorialBar.padding)
				expect.equal(d.frame.x + d.frame.w, w - m.margin)
			else
				expect.truthy(d.showText)
				for _, key in ipairs({ "x", "y", "w", "h" }) do
					expect.equal(d.frame[key], plain.frame[key])
					expect.equal(d.skip[key], plain.skip[key])
					expect.equal(d.text[key], plain.text[key])
				end
			end
		end
	end)

	t.test("compact stocking bar gives the reason two lines (CM2-UVF10)", function()
		for _, size in ipairs({ { 666, 316 }, { 667, 317 }, { 780, 302 }, { 750, 332 }, { 666, 374 } }) do
			local m = UiTheme.metrics(size[1], size[2])
			local bar = UiTheme.stockingBarLayout(m)
			expect.equal(bar.frame.h, 154)
			expect.truthy(bar.reason.h >= 2 * UiTheme.TextSize.Small + 4)
			expect.truthy(bar.header.h >= UiTheme.TextSize.Body + 2)
			expect.falsy(UiTheme.overlaps(bar.header, bar.reason))
			expect.truthy(bar.reason.y + bar.reason.h <= bar.controls.Size.y)
			local ids = {}
			for id in pairs(bar.controls) do
				table.insert(ids, id)
			end
			for index, id in ipairs(ids) do
				local control = bar.controls[id]
				expect.truthy(UiTheme.inside(control, bar.frame.w, bar.frame.h))
				expect.falsy(UiTheme.overlaps(control, bar.header))
				expect.falsy(UiTheme.overlaps(control, bar.reason))
				for other = index + 1, #ids do
					expect.falsy(UiTheme.overlaps(control, bar.controls[ids[other]]))
				end
			end
		end
		local pc = UiTheme.stockingBarLayout(UiTheme.metrics(1920, 1022))
		expect.falsy(pc.twoRows)
		expect.equal(pc.header.h, 22)
		expect.equal(pc.reason.h, 18)
		local regular = UiTheme.stockingBarLayout(UiTheme.metrics(720, 520))
		expect.truthy(regular.twoRows)
		expect.equal(regular.controls.Size.y, 52)
		expect.equal(regular.reason.h, 16)
	end)

	-- CM2-SUP: phone sizes plus a PC; every box keeps 8 px clear of the page scroll bar.
	local SUPPLIER_SIZES = { { 666, 374 }, { 667, 375 }, { 666, 324 }, { 780, 302 }, { 1920, 1022 } }
	local function supplierBody(size)
		local m = UiTheme.metrics(size[1], size[2])
		local manager = UiTheme.hudLayout(m, 0).manager
		return m, UiTheme.managerLayout(m, manager).body
	end

	t.test("supplier panel fits the Lot Manager body (replaces the CM2-UVF11 test)", function()
		for _, size in ipairs(SUPPLIER_SIZES) do
			local m, body = supplierBody(size)
			local layout = UiTheme.supplierPanelLayout(m, body.w)
			expect.equal(layout.width, math.floor(body.w) - 8)
			local ids = {
				"modeBuy",
				"modeSell",
				"refresh",
				"placeOrder",
				"clear",
				"recommend",
				"status",
				"cartInfo",
				"cartLines",
			}
			for _, id in ipairs({ "modeBuy", "modeSell", "refresh", "placeOrder", "clear", "recommend", "sellHint" }) do
				local b = layout[id]
				noNegativeSize(b)
				expect.truthy(UiTheme.inside(b, body.w - 8, math.huge))
			end
			for _, id in ipairs(ids) do
				expect.truthy(UiTheme.inside(layout[id], body.w - 8, math.huge))
			end
			expect.truthy(layout.placeOrder.y + layout.placeOrder.h <= body.h)
			for _, id in ipairs({ "modeBuy", "modeSell", "placeOrder", "clear", "recommend" }) do
				expect.truthy(layout[id].w >= UiTheme.MinTouch)
				expect.truthy(layout[id].h >= UiTheme.MinTouch)
			end
			for index, id in ipairs(ids) do
				for other = index + 1, #ids do
					expect.falsy(UiTheme.overlaps(layout[id], layout[ids[other]]))
				end
			end
			expect.truthy(layout.rowsTopBuy >= layout.cartLines.y + layout.cartLines.h)
			expect.truthy(layout.rowsTopSell >= layout.status.y + layout.status.h)
			expect.truthy(layout.rowsTopSell >= layout.sellHint.y + layout.sellHint.h)
			expect.truthy(layout.rowHeight >= UiTheme.MinTouch)
			expect.truthy(layout.rowPitch >= layout.rowHeight)
		end
		local pc = UiTheme.supplierPanelLayout(UiTheme.metrics(1920, 1022), 600)
		expect.equal(pc.cartInfo.h, 36)
		expect.equal(pc.rowsTopBuy, 196)
		expect.equal(pc.textSize, 13)
	end)

	-- CM2-V2-ORD: the "Recent orders" block sits between the cart lines and the rows.
	t.test("supplier layout makes room for recent orders", function()
		for _, size in ipairs(SUPPLIER_SIZES) do
			local m, body = supplierBody(size)
			local layout = UiTheme.supplierPanelLayout(m, body.w, 4)
			expect.truthy(UiTheme.inside(layout.orders, body.w - 8, math.huge))
			expect.truthy(layout.orders.y >= layout.cartLines.y + layout.cartLines.h)
			expect.truthy(layout.rowsTopBuy >= layout.orders.y + layout.orders.h)
			expect.truthy(layout.orderTitleHeight + 4 * layout.orderPitch <= layout.orders.h + 4)
			expect.equal(
				UiTheme.supplierPanelLayout(m, body.w).rowsTopBuy,
				UiTheme.supplierPanelLayout(m, body.w, 0).rowsTopBuy
			)
		end
		local pc = UiTheme.metrics(1920, 1022)
		expect.equal(UiTheme.supplierPanelLayout(pc, 600, 0).rowsTopBuy, 196)
		expect.equal(UiTheme.supplierPanelLayout(pc, 600, 4).rowsTopBuy, 298)
	end)

	t.test("supplier rows fit both views", function()
		for _, size in ipairs(SUPPLIER_SIZES) do
			local m, body = supplierBody(size)
			local panel = UiTheme.supplierPanelLayout(m, body.w)
			for _, sellView in ipairs({ false, true }) do
				local row = UiTheme.supplierRowLayout(body.w, sellView, m.compact)
				expect.truthy(row.text.w > 0)
				if m.compact then
					expect.equal(row.text.w, panel.width)
					for _, b in ipairs({ row.minus, row.qty, row.plus, row.max }) do
						expect.equal(b.y, 44)
					end
				end
				local boxes = { row.text, row.minus, row.qty, row.plus, row.max }
				if sellView then
					expect.truthy(row.sell ~= nil)
					table.insert(boxes, row.sell :: UiTheme.Box)
				else
					expect.equal(row.sell, nil)
				end
				for index, b in ipairs(boxes) do
					expect.truthy(UiTheme.inside(b, body.w - 8, panel.rowHeight))
					if index > 1 then
						expect.truthy(b.w >= UiTheme.MinTouch)
						expect.truthy(b.h >= UiTheme.MinTouch)
					end
					for other = index + 1, #boxes do
						expect.falsy(UiTheme.overlaps(b, boxes[other]))
					end
				end
			end
		end
	end)

	t.test("Pricing card fits the page and keeps 44 px controls (CM2-UVF12)", function()
		for _, size in ipairs({ { 666, 374 }, { 667, 375 }, { 666, 324 }, { 780, 302 } }) do
			local m = UiTheme.metrics(size[1], size[2])
			local manager = UiTheme.hudLayout(m, 0).manager
			local body = UiTheme.managerLayout(m, manager).body
			local card = UiTheme.pricingCardLayout(m)
			if size[2] >= 374 then
				-- The page clip is about 180 px high at 666x374 (CM2-UVF11 playtest): card <= page - 8.
				expect.truthy(card.cardHeight <= 172)
				expect.truthy(card.cardHeight <= body.h - 58 - 8)
			end
			expect.truthy(card.controlsHeight >= UiTheme.MinTouch)
			expect.truthy(card.controlsY + card.controlsHeight <= card.cardHeight)
			expect.truthy(card.pitch >= card.cardHeight)
			expect.falsy(UiTheme.overlaps(card.sizes, card.price))
		end
		local pc = UiTheme.pricingCardLayout(UiTheme.metrics(1920, 1022))
		expect.equal(pc.cardHeight, 180)
		expect.equal(pc.pitch, 188)
		expect.equal(pc.controlsY, 128)
		expect.truthy(pc.controlsY + pc.controlsHeight <= pc.cardHeight)
		local compactCard = UiTheme.pricingCardLayout(UiTheme.metrics(666, 374))
		expect.equal(compactCard.controlsY, 112)
		expect.truthy(compactCard.controlsY + compactCard.controlsHeight <= compactCard.cardHeight)
	end)

	-- CM2-PP: the plot picker panel and its confirm frame.
	t.test("fits the plot picker on every screen", function()
		local panelChildren =
			{ "title", "prevButton", "nextButton", "plotNumber", "status", "message", "back", "choose" }
		local confirmChildren = { "confirmText", "yes", "no" }
		local touch = { "prevButton", "nextButton", "back", "choose", "yes", "no" }
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			local layout: any = UiTheme.plotPickerLayout(m)
			expect.truthy(UiTheme.inside(layout.panel, m.width, m.height))
			expect.truthy(UiTheme.inside(layout.confirm, m.width, m.height))
			for _, id in ipairs(panelChildren) do
				expect.truthy(UiTheme.inside(layout[id], layout.panel.w, layout.panel.h))
			end
			for _, id in ipairs(confirmChildren) do
				expect.truthy(UiTheme.inside(layout[id], layout.confirm.w, layout.confirm.h))
			end
			for _, id in ipairs(touch) do
				expect.truthy(layout[id].w >= UiTheme.MinTouch)
				expect.truthy(layout[id].h >= UiTheme.MinTouch)
			end
			for first = 1, #panelChildren do
				for second = first + 1, #panelChildren do
					expect.falsy(UiTheme.overlaps(layout[panelChildren[first]], layout[panelChildren[second]]))
				end
			end
			for first = 1, #confirmChildren do
				for second = first + 1, #confirmChildren do
					expect.falsy(UiTheme.overlaps(layout[confirmChildren[first]], layout[confirmChildren[second]]))
				end
			end
		end
	end)

	-- CM2-UI3: no phone box grows beyond the sizes recorded before CM2-UI3.
	t.test("phone boxes stay within the CM2-UI3 baseline", function()
		for _, size in ipairs(PHONES) do
			local key = size[1] .. "x" .. size[2]
			local m = UiTheme.metrics(size[1], size[2])
			local current: { [string]: any } = {
				manager = UiTheme.hudLayout(m, 0).manager,
				hud = UiTheme.hudLayout(m, 0).hud,
				toast = UiTheme.hudLayout(m, 0).toast,
				actionBar = UiTheme.hudLayout(m, 0).actionBar,
				rail6 = UiTheme.hudLayout(m, 6).rail,
				rail8 = UiTheme.hudLayout(m, 8).rail,
				stocking = UiTheme.stockingBarLayout(m).frame,
				tutorial = UiTheme.tutorialBarLayout(m, false).frame,
				tutorialDocked = UiTheme.tutorialBarLayout(m, true).frame,
				plotPanel = UiTheme.plotPickerLayout(m).panel,
				plotConfirm = UiTheme.plotPickerLayout(m).confirm,
			}
			for name, spec in pairs(UiTheme.Dialogs) do
				current[name] = UiTheme.dialogLayout(m, spec).frame
			end
			local base: { [string]: { number } } = BASELINE[key]
			for name, b in pairs(current) do
				expect.truthy(base[name] ~= nil)
				expect.truthy(b.w <= base[name][1])
				expect.truthy(b.h <= base[name][2])
			end
		end
	end)

	-- CM2-UI3: the confirm frame clears the panel on every screen (22a (g)).
	t.test("plot picker confirm clears the panel (22a (g))", function()
		local sizes = {}
		for _, size in ipairs(PHONES) do
			table.insert(sizes, { size[1], size[2] })
		end
		for _, size in ipairs(MATRIX) do
			table.insert(sizes, { size.w, size.h })
		end
		for _, size in ipairs(sizes) do
			local m = UiTheme.metrics(size[1], size[2])
			local layout: any = UiTheme.plotPickerLayout(m)
			local c = layout.confirm
			expect.falsy(UiTheme.overlaps(c, layout.panel))
			expect.falsy(UiTheme.overlaps(c, absolute(layout.panel, layout.title)))
			expect.falsy(UiTheme.overlaps(c, absolute(layout.panel, layout.status)))
			expect.truthy(UiTheme.inside(c, m.width, m.height))
			local ids = { "confirmText", "yes", "no" }
			for _, id in ipairs(ids) do
				expect.truthy(UiTheme.inside(layout[id], c.w, c.h))
			end
			expect.truthy(layout.yes.w >= 44 and layout.yes.h >= 44)
			expect.truthy(layout.no.w >= 44 and layout.no.h >= 44)
			for first = 1, #ids do
				for second = first + 1, #ids do
					expect.falsy(UiTheme.overlaps(layout[ids[first]], layout[ids[second]]))
				end
			end
			if size[1] == 780 and size[2] == 281 then
				expect.equal(c.h, 64)
			elseif size[1] == 666 and size[2] == 374 then
				expect.equal(c.h, 120)
			end
		end
	end)

	-- CM2-UI3: phone windows, buttons and text meet the compact limits (PRODUCT_SPEC, OWNER DECIDED).
	t.test("phone windows, buttons and text meet the compact limits", function()
		local function within(b, low, high)
			expect.truthy(b.h >= low and b.h <= high)
		end
		for _, size in ipairs(PHONES) do
			local m = UiTheme.metrics(size[1], size[2])
			local picker: any = UiTheme.plotPickerLayout(m)
			local maxW, maxH = math.floor(0.7 * size[1]), math.floor(0.8 * size[2])
			for _, frame in ipairs({ picker.panel, picker.confirm }) do
				expect.truthy(frame.w <= maxW)
				expect.truthy(frame.h <= maxH)
			end
			for _, b in ipairs(UiTheme.hudLayout(m, 8).railButtons) do
				within(b, 44, 52)
			end
			for _, b in pairs(UiTheme.stockingBarLayout(m).controls) do
				within(b, 44, 52)
			end
			for _, id in ipairs({ "prevButton", "nextButton", "back", "choose", "yes", "no" }) do
				within(picker[id], 44, 52)
			end
			within(UiTheme.tutorialBarLayout(m, false).skip, 44, 52)
			local manager = UiTheme.managerLayout(m, UiTheme.hudLayout(m, 0).manager)
			within(manager.close, 44, 52)
			for _, b in ipairs(manager.tabs) do
				within(b, 44, 52)
			end
			local supplierText = UiTheme.supplierPanelLayout(m, manager.body.w).textSize
			expect.truthy(supplierText >= 14 and supplierText <= 16)
		end
		local sizes = UiTheme.TextSize
		for _, value in ipairs({ sizes.Body, sizes.Input, sizes.Chip, UiTheme.TutorialBar.textSize }) do
			expect.truthy(value >= 14 and value <= 16)
		end
		for _, value in ipairs({ sizes.Title, UiTheme.SaveRow.nameTextSize, UiTheme.PlotPicker.numberTextSize }) do
			expect.truthy(value <= 24)
		end
	end)

	local function expectBox(b, x, y, w, h)
		expect.equal(b.x, x)
		expect.equal(b.y, y)
		expect.equal(b.w, w)
		expect.equal(b.h, h)
	end

	-- 22a3c: the phone Lot Manager is at most 70 % x 80 % with a scrolling tab column.
	t.test("phone Lot Manager fits 70 % x 80 % (22a3c)", function()
		for _, size in ipairs(PHONES) do
			local m = UiTheme.metrics(size[1], size[2])
			local manager = UiTheme.hudLayout(m, 0).manager
			expect.truthy(manager.w <= math.floor(0.7 * size[1]))
			expect.truthy(manager.h <= math.floor(0.8 * size[2]))
			expect.truthy(UiTheme.inside(manager, size[1], size[2]))
			local base = BASELINE[size[1] .. "x" .. size[2]]
			if base then
				expect.truthy(manager.w <= base.manager[1])
				expect.truthy(manager.h <= base.manager[2])
			end
			local inner = UiTheme.managerLayout(m, manager)
			local cw, ch = manager.w - 2 * inner.padding, manager.h - 2 * inner.padding
			local cash = inner.cash :: UiTheme.Box
			local parts = { inner.title, cash, inner.close, inner.tabBar, inner.body }
			for index, b in ipairs(parts) do
				noNegativeSize(b)
				expect.truthy(UiTheme.inside(b, cw, ch))
				for other = index + 1, #parts do
					expect.falsy(UiTheme.overlaps(b, parts[other]))
				end
			end
			for index, tab in ipairs(inner.tabs) do
				expect.equal(tab.x, 0)
				expect.equal(tab.y, (index - 1) * 48)
				if inner.tabScrolls then
					expect.equal(tab.w, inner.tabBar.w - 6)
				end
				expect.truthy(tab.h >= 44 and tab.h <= 52)
				expect.truthy(tab.w >= 88)
				expect.truthy(UiTheme.inside(tab, inner.tabBar.w, math.huge))
			end

			local body = inner.body
			local panel = UiTheme.supplierPanelLayout(m, body.w)
			expect.equal(panel.textSize, 14)
			for _, id in ipairs({ "modeBuy", "modeSell", "refresh", "placeOrder", "clear", "recommend" }) do
				expect.truthy(UiTheme.inside(panel[id], panel.width, math.huge))
			end
			for _, id in ipairs({ "modeBuy", "modeSell", "placeOrder", "clear", "recommend" }) do
				expect.truthy(panel[id].h >= 44 and panel[id].h <= 52)
			end
			for _, sellView in ipairs({ false, true }) do
				local row = UiTheme.supplierRowLayout(body.w, sellView, true)
				expect.truthy(row.text.w >= 240)
				local controls = { row.minus, row.qty, row.plus, row.max }
				if row.sell then
					table.insert(controls, row.sell)
				end
				for _, b in ipairs(controls) do
					expect.truthy(b.h >= 44 and b.h <= 52)
					expect.truthy(UiTheme.inside(b, panel.width, panel.rowHeight))
				end
			end

			local card = UiTheme.pricingCardLayout(m)
			expect.truthy(324 <= body.w - 8)
			expect.truthy(card.cardHeight <= body.h)
			expect.truthy(UiTheme.inside(card.price, 324, card.cardHeight))
			expect.truthy(card.controlsY + card.controlsHeight <= card.cardHeight)
		end
		local small = UiTheme.metrics(780, 281)
		local smallManager = UiTheme.hudLayout(small, 0).manager
		expectBox(smallManager, 117, 28, 546, 224)
		expectBox(UiTheme.managerLayout(small, smallManager).body, 106, 50, 428, 162)
	end)

	t.test("desktop Lot Manager boxes unchanged (22a3c)", function()
		local pcMetrics = UiTheme.metrics(1920, 1022)
		local manager = UiTheme.hudLayout(pcMetrics, 0).manager
		expectBox(manager, 578, 94, 920, 640)
		local inner = UiTheme.managerLayout(pcMetrics, manager)
		expectBox(inner.tabBar, 0, 52, 168, 564)
		expectBox(inner.body, 180, 52, 716, 564)
		expectBox(inner.close, 800, 0, 96, 44)
		for index, tab in ipairs(inner.tabs) do
			expectBox(tab, 0, (index - 1) * 54, 168, 48)
		end
		expect.falsy(inner.tabScrolls)
		expect.equal(inner.cash, nil)
		expectBox(UiTheme.hudLayout(UiTheme.metrics(960, 542), 0).manager, 168, 94, 780, 436)

		local panel = UiTheme.supplierPanelLayout(pcMetrics, 716)
		expect.equal(panel.rowPitch, 48)
		expect.equal(panel.rowHeight, 44)
		expect.equal(panel.footerHint, 36)
		expect.equal(panel.footerLine, 18)
		expect.equal(panel.status.h, 18)
		expect.equal(panel.refresh.x, 292)
		expect.equal(panel.textSize, 13)
		local plain = UiTheme.supplierRowLayout(716, true)
		local explicit = UiTheme.supplierRowLayout(716, true, false)
		for _, id in ipairs({ "text", "minus", "qty", "plus", "max", "sell" }) do
			local a, b = plain[id] :: UiTheme.Box, explicit[id] :: UiTheme.Box
			expectBox(a, b.x, b.y, b.w, b.h)
		end
		expect.equal(plain.text.w, 400)
	end)

	-- CM2-UICLIP: the ClipInset constants and helpers.
	t.test("clip inset covers every stroke and hover growth", function()
		local style = UiTheme.Style
		local widest = math.max(style.StrokeControl, style.StrokeSelected, style.StrokeCard)
		expect.truthy(UiTheme.ClipInset >= widest + UiTheme.Motion.hoverGrowMax + 2)
		expect.equal(UiTheme.ClipInset, 8)
	end)

	t.test("clipPadding and clipBox", function()
		local sides = UiTheme.clipPadding(6)
		expect.equal(sides.left, 8)
		expect.equal(sides.right, 14)
		expect.equal(sides.top, 8)
		expect.equal(sides.bottom, 8)
		local box = UiTheme.clipBox({ x = 0, y = 52, w = 168, h = 564 })
		expect.equal(box.x, -8)
		expect.equal(box.y, 44)
		expect.equal(box.w, 184)
		expect.equal(box.h, 580)
	end)

	t.test("Lot Manager layouts fit the clip-padded page", function()
		local sizes = {}
		for _, size in ipairs(MATRIX) do
			table.insert(sizes, { size.w, size.h })
		end
		for _, size in ipairs(PHONES) do
			table.insert(sizes, size)
		end
		for _, size in ipairs(sizes) do
			local m = UiTheme.metrics(size[1], size[2])
			local manager = UiTheme.hudLayout(m, 0).manager
			local body = UiTheme.managerLayout(m, manager).body
			local w = body.w - 2 * UiTheme.ClipInset - 6
			local panel = UiTheme.supplierPanelLayout(m, w)
			expect.equal(panel.width, math.floor(w) - 8)
			local ids = { "modeBuy", "modeSell", "placeOrder", "clear", "recommend" }
			for _, id in ipairs(ids) do
				expect.truthy(panel[id].w >= UiTheme.MinTouch)
				expect.truthy(panel[id].h >= UiTheme.MinTouch)
			end
			for _, id in ipairs({ "modeBuy", "modeSell", "refresh", "placeOrder", "clear", "recommend" }) do
				expect.truthy(UiTheme.inside(panel[id], panel.width, math.huge))
			end
			for index, id in ipairs(ids) do
				for other = index + 1, #ids do
					expect.falsy(UiTheme.overlaps(panel[id], panel[ids[other]]))
				end
			end
			for _, sellView in ipairs({ false, true }) do
				local row = UiTheme.supplierRowLayout(w, sellView, m.compact)
				expect.truthy(row.text.w > 0)
				local boxes = { row.text, row.minus, row.qty, row.plus, row.max }
				if row.sell then
					table.insert(boxes, row.sell)
				end
				for index, b in ipairs(boxes) do
					expect.truthy(UiTheme.inside(b, panel.width, panel.rowHeight))
					if index > 1 then
						expect.truthy(b.w >= UiTheme.MinTouch)
						expect.truthy(b.h >= UiTheme.MinTouch)
					end
					for other = index + 1, #boxes do
						expect.falsy(UiTheme.overlaps(b, boxes[other]))
					end
				end
				if m.compact then
					expect.truthy(row.text.w >= 240)
				end
			end
			if m.compact then
				expect.truthy(324 <= w)
			end
		end
	end)

	t.test("tab bar clip box stays in the manager", function()
		for _, size in ipairs(MATRIX) do
			local m = UiTheme.metrics(size.w, size.h)
			local manager = UiTheme.hudLayout(m, 4).manager
			local inner = UiTheme.managerLayout(m, manager)
			local clip = UiTheme.clipBox(inner.tabBar)
			if m.compact then
				for _, tab in ipairs(inner.tabs) do
					expect.truthy(tab.w <= inner.tabBar.w - 4)
				end
			else
				local cw = manager.w - 2 * inner.padding
				local ch = manager.h - 2 * inner.padding
				local room =
					{ x = -inner.padding, y = -inner.padding, w = cw + 2 * inner.padding, h = ch + 2 * inner.padding }
				expect.truthy(UiTheme.contains(room, clip, 0))
				expect.truthy(clip.x + clip.w <= inner.body.x)
			end
		end
	end)

	-- 22a3b: every dialog fits 70 % x 80 % of the safe area on phones.
	t.test("phone dialogs fit 70 % x 80 % of the safe area (22a3b)", function()
		for _, size in ipairs(PHONES) do
			local m = UiTheme.metrics(size[1], size[2])
			for name, spec in pairs(UiTheme.Dialogs) do
				local d = UiTheme.dialogLayout(m, spec)
				expect.truthy(d.frame.w <= math.floor(0.7 * size[1]))
				expect.truthy(d.frame.h <= math.floor(0.8 * size[2]))
				expect.truthy(UiTheme.inside(d.frame, size[1], size[2]))
				local list, footer = d.list, d.footer
				if list and footer then
					expect.truthy(list.h >= spec.minList)
					expect.truthy(UiTheme.inside(list, d.innerWidth, d.innerHeight))
					expect.truthy(UiTheme.inside(footer, d.innerWidth, d.innerHeight))
					expect.falsy(UiTheme.overlaps(list, footer))
					expect.truthy(footer.w >= 200)
					expect.equal(footer.h, spec.compactFooterHeight or spec.footerHeight)
					if spec.compactTop then
						expect.truthy(footer.y >= spec.compactTop + 8)
					end
					local header = d.rightHeader
					if header and not spec.compactHeaderInFooter then
						expect.truthy(header.y + 44 + 8 <= footer.y)
					end
					if name == "Picker" then
						expect.equal(footer.h, 200)
						expect.truthy(math.floor(0.25 * footer.w) - 6 >= 44)
					elseif name == "Team" then
						expect.truthy(0.5 * footer.w - 4 >= 44)
					end
				end
				if name == "DeleteConfirm" then
					expect.truthy(d.innerHeight >= 194)
				end
			end
			if size[1] == 780 and size[2] == 281 then
				local frame = UiTheme.dialogLayout(m, UiTheme.Dialogs.Picker).frame
				expect.equal(frame.w, 546)
				expect.equal(frame.h, 224)
			end
		end
	end)

	-- 22a3b: the compact Finder footer and the compact delete confirm row fit their areas.
	t.test("compact Finder footer and delete row fit (22a3b)", function()
		local function check(
			boxes: { [string]: any },
			w: number,
			h: number,
			minY: number,
			exclusive: { [string]: string }
		)
			local keys = {}
			for key in pairs(boxes) do
				table.insert(keys, key)
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local b = boxes[key]
				expect.truthy(UiTheme.inside(b, w, h))
				expect.truthy(b.h >= 44 and b.h <= 52)
				expect.truthy(b.w >= 44)
				expect.truthy(b.y >= minY)
			end
			for first = 1, #keys do
				for second = first + 1, #keys do
					local a, b = keys[first], keys[second]
					if exclusive[a .. "/" .. b] == nil then
						expect.falsy(UiTheme.overlaps(boxes[a], boxes[b]))
					end
				end
			end
		end
		for _, size in ipairs(PHONES) do
			local m = UiTheme.metrics(size[1], size[2])
			local finder = UiTheme.dialogLayout(m, UiTheme.Dialogs.Finder)
			expect.truthy(finder.footer ~= nil)
			local footer = finder.footer :: UiTheme.Box
			local exclusive = { ["OwnListing/StartHint"] = "x", ["StartListing/StopListing"] = "x" }
			check(UiTheme.finderFooterCompact(footer.w), footer.w, 148, 0, exclusive)
			local confirm = UiTheme.dialogLayout(m, UiTheme.Dialogs.DeleteConfirm)
			check(UiTheme.deleteConfirmRow(confirm.innerWidth), confirm.innerWidth, 194, 146, {})
		end
	end)

	-- CM2-43: text and background colour pairs the UI uses meet WCAG contrast (AA body 4.5, large
	-- or placeholder text 3.0), and the text sizes stay readable on a phone.
	t.test("text colour pairs meet WCAG contrast", function()
		local function linear(channel: number): number
			local value = channel / 255
			return if value <= 0.03928 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
		end
		local function luminance(rgb: { number }): number
			return 0.2126 * linear(rgb[1]) + 0.7152 * linear(rgb[2]) + 0.0722 * linear(rgb[3])
		end
		-- scale multiplies both colours: the kit gradient tints fill and text alike (worst case at the bottom).
		local function ratio(foreground: string, background: string, scale: number?): number
			local k = scale or 1
			local a = luminance(UiTheme.Colors[foreground]) * k
			local b = luminance(UiTheme.Colors[background]) * k
			return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
		end
		local pairs4_5 = {
			{ "DarkText", "Panel" },
			{ "DarkText", "Row" },
			{ "DarkText", "ListWell" },
			{ "DarkText", "Sand" },
			{ "DarkText", "Gold" },
			{ "DarkText", "Cream" },
			{ "DarkText", "Toast" },
			{ "Muted", "Panel" },
			{ "Muted", "Row" },
			{ "Muted", "ListWell" },
			{ "GoldText", "Panel" },
			{ "GoldText", "Row" },
			{ "GoldText", "ListWell" },
			{ "Cream", "Header" },
			{ "Cream", "Primary" },
			{ "Cream", "Red" },
			{ "Cream", "Disabled" },
		}
		for _, pair in ipairs(pairs4_5) do
			expect.truthy(ratio(pair[1], pair[2]) >= 4.5)
		end
		-- Shaded fills carry the text colour UiStyle.textOn names.
		for _, fill in ipairs({ "Panel", "Sand", "Gold", "Red", "Disabled", "Header", "Primary" }) do
			expect.truthy(ratio(UiStyle.textOn(fill), fill, UiTheme.Style.GradientBottom) >= 4.5)
		end
		expect.truthy(ratio("Placeholder", "Cream") >= 3.0)
		expect.truthy(UiTheme.TextSize.Small >= 13)
		expect.truthy(UiTheme.TextSize.Body >= UiTheme.TextSize.Small)
	end)
end
