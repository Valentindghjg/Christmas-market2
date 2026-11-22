--!strict
-- UI tokens and pure layout math (CM2-40). No Instances: the client UiKit and the screens apply
-- these numbers, and tests/studio/Cases/UiTheme_Test.lua checks them for every device size.
-- All values are PROVISIONAL engineering values (docs/plans/CM2-40.md). Sizes are pixel offsets
-- computed from the ScreenGui's AbsoluteSize (the safe area); there is no UIScale.
local UiTheme = {}

export type Box = { x: number, y: number, w: number, h: number }

export type WorldLabelLayout = {
	w: number,
	h: number,
	textSize: number,
	wrap: boolean,
	height: number,
	stagger: number,
	maxDistance: number,
}

export type Metrics = {
	width: number,
	height: number,
	compact: boolean,
	margin: number,
	railWidth: number,
	railGap: number,
	railTop: number,
	railMaxHeight: number,
	showDay: boolean,
}

export type DialogSpec = {
	listTop: number,
	footerHeight: number,
	minList: number,
	maxWidth: number,
	maxHeight: number,
	widthScale: number,
	heightScale: number,
	contentHeight: number?,
}

export type TabDef = { id: string, labelKey: string, module: string }

export type HudLayout = {
	hud: Box,
	chips: { { id: string, box: Box } },
	status: Box,
	rail: Box,
	railScrolls: boolean,
	toast: Box,
	actionBar: Box,
	manager: Box,
}

export type ManagerLayout = {
	padding: number,
	header: Box,
	title: Box,
	close: Box,
	cash: Box?,
	tabBar: Box,
	tabs: { Box },
	body: Box,
	horizontal: boolean,
}

export type DialogLayout = {
	compact: boolean,
	frame: Box,
	innerWidth: number,
	innerHeight: number,
	list: Box?,
	footer: Box?,
	leftWidth: number,
	rightHeader: Box?,
}

export type StockingBarLayout = {
	frame: Box,
	header: Box,
	reason: Box,
	controls: { [string]: Box },
	twoRows: boolean,
}

-- UI colours as RGB tuples; they stay separate from ArtPalette (3D materials).
UiTheme.Colors = {
	Panel = { 20, 68, 48 },
	Row = { 38, 89, 63 },
	ListWell = { 13, 50, 35 },
	Gold = { 201, 153, 53 },
	Sand = { 237, 212, 142 },
	Cream = { 255, 244, 217 },
	DarkText = { 30, 48, 35 },
	Red = { 196, 58, 52 },
	Disabled = { 120, 120, 120 },
	Placeholder = { 120, 110, 90 },
} :: { [string]: { number } }

UiTheme.Fonts = { Bold = "GothamBold", Regular = "Gotham" }
UiTheme.TextSize = { Title = 22, Body = 15, Small = 13, Chip = 16 }
UiTheme.MinTouch = 44
UiTheme.CornerRadius = { Button = 8, Row = 10, Panel = 14 }
UiTheme.CompactHeight = 520
UiTheme.CompactWidth = 720

-- World billboard layouts (CM2-UVF2, PROVISIONAL): w/h in px, height in studs above the adornee.
UiTheme.WorldLabels = {
	Bay = {
		w = 200,
		h = 28,
		textSize = UiTheme.TextSize.Small,
		wrap = false,
		height = 5,
		stagger = 0,
		maxDistance = 60,
	},
	DisplayTree = {
		w = 220,
		h = 44,
		textSize = UiTheme.TextSize.Small,
		wrap = true,
		height = 10,
		stagger = 0,
		maxDistance = 40,
	},
	CarNumber = {
		w = 130,
		h = 30,
		textSize = UiTheme.TextSize.Chip,
		wrap = false,
		height = 6,
		stagger = 0,
		maxDistance = 60,
	},
	PickupOrder = {
		w = 240,
		h = 30,
		textSize = UiTheme.TextSize.Body,
		wrap = false,
		height = 9,
		stagger = 2,
		maxDistance = 60,
	},
	Speech = {
		w = 170,
		h = 30,
		textSize = UiTheme.TextSize.Body,
		wrap = false,
		height = 3,
		stagger = 0,
		maxDistance = 60,
	},
} :: { [string]: WorldLabelLayout }

-- The six Lot Manager tabs in the OBSERVED order (REFERENCE_GAME_LIVE_TEST section 4).
UiTheme.LotManagerTabs = {
	{ id = "Supplier", labelKey = "tabSupplier", module = "SupplierTab" },
	{ id = "Catalog", labelKey = "catalog", module = "CatalogTab" },
	{ id = "Pricing", labelKey = "pricing", module = "PricingTab" },
	{ id = "Employees", labelKey = "employees", module = "EmployeesTab" },
	{ id = "Land", labelKey = "land", module = "LandTab" },
	{ id = "Analytics", labelKey = "analytics", module = "AnalyticsTab" },
} :: { TabDef }

-- Picker heightScale 0.92 (CM2-UVF5): at 672 px safe height and above the list shows two whole save rows and part of a third.
UiTheme.Dialogs = {
	Picker = {
		listTop = 60,
		footerHeight = 200,
		minList = 120,
		maxWidth = 480,
		maxHeight = 600,
		widthScale = 0.92,
		heightScale = 0.92,
	},
	DeleteConfirm = {
		listTop = 0,
		footerHeight = 0,
		minList = 0,
		maxWidth = 480,
		maxHeight = 600,
		widthScale = 0.92,
		heightScale = 0.86,
		contentHeight = 246,
	},
	Team = {
		listTop = 120,
		footerHeight = 96,
		minList = 56,
		maxWidth = 420,
		maxHeight = 560,
		widthScale = 0.92,
		heightScale = 0.8,
	},
	Finder = {
		listTop = 72,
		footerHeight = 198,
		minList = 64,
		maxWidth = 420,
		maxHeight = 560,
		widthScale = 0.92,
		heightScale = 0.8,
	},
} :: { [string]: DialogSpec }

-- Save picker row (CM2-UVF4): name, kind and state on their own lines above the buttons. listGap is the space between list entries.
export type SaveRowLayout = {
	height: number,
	padding: number,
	nameTextSize: number,
	nameHeight: number,
	textSize: number,
	kindHeight: number,
	stateHeight: number,
	listGap: number,
}
UiTheme.SaveRow = {
	height = 136,
	padding = 6,
	nameTextSize = 18,
	nameHeight = 36,
	textSize = UiTheme.TextSize.Small,
	kindHeight = 28,
	stateHeight = 16,
	listGap = 8,
} :: SaveRowLayout

-- Layout constants.
local GAP = 8
local BUTTON_HEIGHT = 44
local HUD_HEIGHT = 74
local CHIP_HEIGHT = 36
local CHIP_GAP = 6
local STATUS_TOP = 40
local STATUS_HEIGHT = 34
local RAIL_SIDE_PADDING = 8
local THUMB_RESERVE = 96
local TOAST_MAX_WIDTH = 460
local MANAGER_MAX_WIDTH = 920
local MANAGER_MAX_HEIGHT = 640
local CHIP_DEFS = {
	{ id = "Cash", width = 128 },
	{ id = "Reputation", width = 104 },
	{ id = "Day", width = 88 },
	{ id = "Lot", width = 104 },
}
local FULL_STRIP_WIDTH = 442

local function box(x: number, y: number, w: number, h: number): Box
	return { x = x, y = y, w = math.max(0, w), h = math.max(0, h) }
end

function UiTheme.metrics(width: number, height: number): Metrics
	local w = math.max(0, math.floor(width))
	local h = math.max(0, math.floor(height))
	local compact = h < UiTheme.CompactHeight or w < UiTheme.CompactWidth
	local margin = if compact then 8 else 12
	local railWidth = if compact then 124 else 148
	local railGap = if compact then 4 else 6
	local railTop = if compact then margin else math.max(margin, math.floor(h * 0.3))
	local reserve = if compact then THUMB_RESERVE else 0
	return {
		width = w,
		height = h,
		compact = compact,
		margin = margin,
		railWidth = railWidth,
		railGap = railGap,
		railTop = railTop,
		railMaxHeight = math.max(0, h - railTop - margin - reserve),
		showDay = w >= railWidth + 2 * margin + RAIL_SIDE_PADDING + FULL_STRIP_WIDTH,
	}
end

function UiTheme.hudLayout(m: Metrics, railButtons: number): HudLayout
	local chips: { { id: string, box: Box } } = {}
	local x = 0
	for _, def in ipairs(CHIP_DEFS) do
		if def.id ~= "Day" or m.showDay then
			table.insert(chips, { id = def.id, box = box(x, 0, def.width, CHIP_HEIGHT) })
			x += def.width + CHIP_GAP
		end
	end
	local stripWidth = x - CHIP_GAP
	local hud = box(m.width - m.margin - stripWidth, m.margin, stripWidth, HUD_HEIGHT)

	local count = math.max(0, math.floor(railButtons))
	local content = if count > 0 then count * BUTTON_HEIGHT + (count - 1) * m.railGap else 0
	local rail = box(m.margin, m.railTop, m.railWidth, math.min(content, m.railMaxHeight))

	local toastWidth =
		math.max(0, math.min(TOAST_MAX_WIDTH, m.width - 2 * (m.margin + m.railWidth + RAIL_SIDE_PADDING)))
	local toast = box(math.floor((m.width - toastWidth) / 2), m.margin + HUD_HEIGHT + GAP, toastWidth, BUTTON_HEIGHT)
	local actionBar =
		box(math.floor(m.width * 0.40), m.height - m.margin - BUTTON_HEIGHT, math.floor(m.width * 0.35), BUTTON_HEIGHT)

	local manager: Box
	if m.compact then
		manager = box(m.margin, m.margin, m.width - 2 * m.margin, m.height - 2 * m.margin)
	else
		local left = m.margin + m.railWidth + GAP
		local top = m.margin + HUD_HEIGHT + GAP
		local availableWidth = math.max(0, m.width - left - m.margin)
		local managerWidth = math.min(availableWidth, MANAGER_MAX_WIDTH)
		local managerHeight = math.min(m.height - top - m.margin, MANAGER_MAX_HEIGHT)
		manager = box(left + math.floor((availableWidth - managerWidth) / 2), top, managerWidth, managerHeight)
	end

	return {
		hud = hud,
		chips = chips,
		status = box(0, STATUS_TOP, stripWidth, STATUS_HEIGHT),
		rail = rail,
		railScrolls = content > m.railMaxHeight,
		toast = toast,
		actionBar = actionBar,
		manager = manager,
	}
end

function UiTheme.managerLayout(m: Metrics, manager: Box): ManagerLayout
	local padding = if m.compact then 8 else 12
	local cw = math.max(0, manager.w - 2 * padding)
	local ch = math.max(0, manager.h - 2 * padding)
	local closeWidth = 96
	local cashWidth = 128
	local header = box(0, 0, cw, BUTTON_HEIGHT)
	local close = box(cw - closeWidth, 0, closeWidth, BUTTON_HEIGHT)
	local cash: Box? = nil
	local titleWidth = cw - closeWidth - GAP
	if m.compact then
		cash = box(cw - closeWidth - GAP - cashWidth, 0, cashWidth, BUTTON_HEIGHT)
		titleWidth -= cashWidth + GAP
	end
	local title = box(0, 0, titleWidth, BUTTON_HEIGHT)

	local tabs: { Box } = {}
	local count = #UiTheme.LotManagerTabs
	if m.compact then
		local tabWidth = math.clamp(math.floor((cw - 30) / 6), 88, 140)
		for index = 1, count do
			table.insert(tabs, box((index - 1) * (tabWidth + 6), 0, tabWidth, BUTTON_HEIGHT))
		end
		return {
			padding = padding,
			header = header,
			title = title,
			close = close,
			cash = cash,
			tabBar = box(0, 52, cw, BUTTON_HEIGHT),
			tabs = tabs,
			body = box(0, 104, cw, ch - 104),
			horizontal = true,
		}
	end
	for index = 1, count do
		table.insert(tabs, box(0, (index - 1) * (48 + 6), 168, 48))
	end
	return {
		padding = padding,
		header = header,
		title = title,
		close = close,
		cash = nil,
		tabBar = box(0, 52, 168, ch - 52),
		tabs = tabs,
		body = box(180, 52, cw - 180, ch - 52),
		horizontal = false,
	}
end

function UiTheme.dialogLayout(m: Metrics, spec: DialogSpec): DialogLayout
	local hasFooter = not (spec.footerHeight == 0 and spec.listTop == 0)
	local frame: Box
	if m.compact then
		local w = math.min(m.width - 2 * m.margin, 760)
		frame = box(math.floor((m.width - math.max(0, w)) / 2), m.margin, w, m.height - 2 * m.margin)
	else
		local w = math.min(spec.maxWidth, math.floor(m.width * spec.widthScale))
		local h = math.min(spec.maxHeight, math.floor(m.height * spec.heightScale))
		frame = box(math.floor((m.width - w) / 2), math.floor((m.height - h) / 2), w, h)
	end
	local iw = math.max(0, frame.w - 24)
	local ih = math.max(0, frame.h - 24)

	local list: Box? = nil
	local footer: Box? = nil
	local rightHeader: Box? = nil
	local leftWidth = iw
	if m.compact then
		leftWidth = math.max(0, math.floor((iw - 12) * 0.55))
		if hasFooter then
			list = box(0, spec.listTop, leftWidth, ih - spec.listTop)
			footer = box(leftWidth + 12, ih - spec.footerHeight, iw - 12 - leftWidth, spec.footerHeight)
			rightHeader = box(leftWidth + 12, 0, iw - 12 - leftWidth, BUTTON_HEIGHT)
		end
	elseif hasFooter then
		list = box(0, spec.listTop, iw, ih - spec.listTop - spec.footerHeight - GAP)
		footer = box(0, ih - spec.footerHeight, iw, spec.footerHeight)
	end

	return {
		compact = m.compact,
		frame = frame,
		innerWidth = iw,
		innerHeight = ih,
		list = list,
		footer = footer,
		leftWidth = leftWidth,
		rightHeader = rightHeader,
	}
end

-- Stocking bar (CM2-G14): one row of controls on regular screens, two rows on compact screens
-- or when one row would make the controls narrower than MinTouch. Control boxes are relative
-- to the frame; every value is clamped to >= 0.
local STOCKING_GAP = 6
local STOCKING_PADDING = 8
local STOCKING_MAX_WIDTH = 760
local STOCKING_SINGLE_ROW = { "Size", "Rotate", "Row", "GapDown", "Gap", "GapUp", "Store", "Place", "Done" }
local STOCKING_TOP_ROW = { "Size", "Rotate", "Row", "Store", "Done" }
local STOCKING_BOTTOM_ROW = { "GapDown", "Gap", "GapUp", "Place" }

local function clampedBox(x: number, y: number, w: number, h: number): Box
	return { x = math.max(0, x), y = math.max(0, y), w = math.max(0, w), h = math.max(0, h) }
end

function UiTheme.stockingBarLayout(m: Metrics): StockingBarLayout
	local controls: { [string]: Box } = {}
	-- Place spans two cells (2 units + one gap).
	local function row(ids: { string }, y: number, unit: number)
		local x = STOCKING_PADDING
		for _, id in ipairs(ids) do
			local width = if id == "Place" then 2 * unit + STOCKING_GAP else unit
			controls[id] = clampedBox(x, y, width, BUTTON_HEIGHT)
			x += width + STOCKING_GAP
		end
	end
	local regularWidth = math.min(STOCKING_MAX_WIDTH, m.width - 2 * (m.margin + m.railWidth + RAIL_SIDE_PADDING))
	local singleUnit = math.floor((regularWidth - 2 * STOCKING_PADDING - 8 * STOCKING_GAP) / 10)
	if not m.compact and singleUnit >= UiTheme.MinTouch then
		local w = regularWidth
		row(STOCKING_SINGLE_ROW, 58, singleUnit)
		return {
			frame = clampedBox(math.floor((m.width - w) / 2), m.height - m.margin - 110, w, 110),
			header = clampedBox(8, 8, w - 16, 22),
			reason = clampedBox(8, 32, w - 16, 18),
			controls = controls,
			twoRows = false,
		}
	end
	local w = if m.compact then math.floor(0.5 * m.width) else regularWidth
	local unit = math.floor((w - 2 * STOCKING_PADDING - 4 * STOCKING_GAP) / 5)
	row(STOCKING_TOP_ROW, 52, unit)
	row(STOCKING_BOTTOM_ROW, 102, unit)
	local x = if m.compact then math.floor(0.3 * m.width) else math.floor((m.width - w) / 2)
	return {
		frame = clampedBox(x, m.height - m.margin - 154, w, 154),
		header = clampedBox(8, 8, w - 16, 20),
		reason = clampedBox(8, 30, w - 16, 16),
		controls = controls,
		twoRows = true,
	}
end

-- 1615 -> "1,615", -1200 -> "-1,200"; the fraction is dropped.
function UiTheme.formatMoney(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then
		return "0"
	end
	local whole = math.floor(value)
	local sign = if whole < 0 then "-" else ""
	local digits = string.format("%d", math.abs(whole))
	local count = 1
	while count > 0 do
		digits, count = string.gsub(digits, "^(%d+)(%d%d%d)", "%1,%2")
	end
	return sign .. digits
end

-- True when the two boxes share a positive area.
function UiTheme.overlaps(a: Box, b: Box): boolean
	if a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0 then
		return false
	end
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

function UiTheme.inside(b: Box, width: number, height: number): boolean
	return b.x >= 0 and b.y >= 0 and b.x + b.w <= width and b.y + b.h <= height
end

return UiTheme
