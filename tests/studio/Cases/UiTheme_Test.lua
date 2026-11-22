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
	local DIALOGS = { "Picker", "DeleteConfirm", "Team", "Finder" }

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
end
