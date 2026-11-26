--!strict
-- CM2-40: layout math and money format for the HUD, the Lot Manager and the dialogs.
return function(t)
	local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
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

	t.test("keeps the regular rail as one column", function()
		for _, size in ipairs({ { w = 1920, h = 1022 }, { w = 1024, h = 710 } }) do
			local m = UiTheme.metrics(size.w, size.h)
			for count = 1, 5 do
				local layout = UiTheme.hudLayout(m, count)
				expect.equal(layout.rail.w, m.railWidth)
				for index = 1, count do
					local b = layout.railButtons[index]
					expect.equal(b.x, 0)
					expect.equal(b.y, (index - 1) * (44 + m.railGap))
					expect.equal(b.w, m.railWidth - 6)
					expect.equal(b.h, 44)
				end
			end
		end
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
			expect.equal(inner.horizontal, m.compact)
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
							expect.truthy(header.y + header.h + 8 <= footer.y)
						end
					end
				end
				if name == "DeleteConfirm" then
					expect.equal(list, nil)
					expect.equal(footer, nil)
					expect.truthy(dialog.innerHeight >= (spec.contentHeight or 0))
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

	t.test("Supplier order button stays inside the Lot Manager body (CM2-UVF11)", function()
		for _, size in ipairs({ { 666, 374 }, { 667, 375 }, { 666, 324 }, { 780, 302 } }) do
			local m = UiTheme.metrics(size[1], size[2])
			local manager = UiTheme.hudLayout(m, 0).manager
			local body = UiTheme.managerLayout(m, manager).body
			local layout = UiTheme.supplierLayout(m, body.w)
			for _, id in ipairs({ "order", "detail" }) do
				local b = layout[id]
				expect.truthy(b.x >= 0 and b.y >= 0)
				expect.truthy(b.x + b.w <= body.w)
				expect.truthy(b.y + b.h <= body.h)
			end
			expect.truthy(layout.order.h >= UiTheme.MinTouch)
			expect.truthy(layout.order.w >= UiTheme.MinTouch)
			expect.falsy(UiTheme.overlaps(layout.order, layout.detail))
			expect.falsy(UiTheme.overlaps(layout.order, layout.sellBack))
		end
		local pc = UiTheme.supplierLayout(UiTheme.metrics(1920, 1022), 600)
		expect.falsy(pc.twoColumns)
		expect.equal(pc.order.y, 182)
		expect.equal(pc.canvasHeight, 386)
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
		expect.equal(compactCard.controlsY, 120)
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
end
