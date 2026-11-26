--!strict
-- UI tokens and pure layout math (CM2-40). No Instances: the client UiKit and the screens apply
-- these numbers, and tests/studio/Cases/UiTheme_Test.lua checks them for every device size.
-- All values are PROVISIONAL engineering values (docs/archive/plans/CM2-40.md). Sizes are pixel offsets
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
	railButtons: { Box },
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

export type SupplierLayout = {
	twoColumns: boolean,
	detail: Box,
	order: Box,
	stockingHint: Box,
	supplierLine: Box,
	receivingLine: Box,
	customerLine: Box,
	sellBack: Box,
	canvasHeight: number,
}

export type PricingCardLayout = {
	cardHeight: number,
	pitch: number,
	name: Box,
	sentiment: Box,
	wholesaleTypical: Box,
	margin: Box,
	sizes: Box,
	price: Box,
	controlsY: number,
	controlsHeight: number,
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

export type TutorialBarLayout = {
	frame: Box,
	text: Box,
	skip: Box,
	showText: boolean,
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
		height = 1.0, -- studs above the tree top (CM2-12W)
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
		height = 1.5, -- studs above the tree top (CM2-12W)
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

-- The lot sign's SurfaceGuis (CM2-G15, PROVISIONAL): sizes in px, maxDistance in studs.
UiTheme.LotSign = {
	pixelsPerStud = 40,
	nameMaxTextSize = 34,
	nameMinTextSize = 14,
	lineTextSize = 28,
	padding = 8,
	maxDistance = 120,
}

-- Map signs and leaderboard titles (CM2-10W, PROVISIONAL): SurfaceGui density, distance, text sizes.
UiTheme.MapSign = {
	pixelsPerStud = 40,
	maxDistance = 150,
	maxTextSize = 72,
	minTextSize = 14,
}

-- Leaderboard screens on the square (CM2-G12b, PROVISIONAL): SurfaceGui density and distance,
-- row layout in px on the 440 x 400 canvas (Screen 11 x 10 studs).
UiTheme.Leaderboard = {
	pixelsPerStud = 40,
	maxDistance = 150,
	padding = 12,
	rowHeight = 32,
	youGap = 10,
	rankWidth = 48,
	valueWidth = 140,
	textSize = 22,
}

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
	Shop = {
		listTop = 92,
		footerHeight = 52,
		minList = 120,
		maxWidth = 560,
		maxHeight = 600,
		widthScale = 0.94,
		heightScale = 0.86,
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

-- Shop category bar (CM2-UVF8): fixed bar, seven tabs share the width; text scales between minText and maxText.
UiTheme.ShopCategoryBar = { gap = 6, maxText = 13, minText = 9 }

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

-- Guided tutorial hint bar, arrows and highlight (CM2-49). PROVISIONAL.
UiTheme.TutorialBar = {
	maxWidth = 560,
	height = 56,
	padding = 6,
	skipWidth = 104,
	textSize = 15,
	arrowSize = 44,
	highlightPad = 4,
	worldArrowStuds = 6,
	refreshSeconds = 0.25,
	doneSeconds = 5,
	confirmSeconds = 3,
	displayOrder = 12,
}

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
local RAIL_OVERFLOW_MIN_WIDTH = 72 -- PROVISIONAL
local RAIL_SCROLLBAR = 6
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
	local cell = m.railWidth - RAIL_SCROLLBAR
	local step = BUTTON_HEIGHT + m.railGap
	local railButtonBoxes: { Box } = {}
	for index = 1, count do
		railButtonBoxes[index] = box(0, (index - 1) * step, cell, BUTTON_HEIGHT)
	end
	local rail = box(m.margin, m.railTop, m.railWidth, math.min(content, m.railMaxHeight))
	local railScrolls = content > m.railMaxHeight

	-- CM2-UVF13: on phones the buttons that do not fit above the thumbstick go right of row 1.
	if m.compact and railScrolls then
		local rows = math.max(1, math.floor((m.railMaxHeight + m.railGap) / step))
		local extra = count - rows
		local startX = cell + m.railGap
		if extra > 0 then
			local room = hud.x - GAP - m.margin - startX - extra * m.railGap + m.railGap
			local ow = math.min(cell, math.floor(room / extra))
			if ow >= RAIL_OVERFLOW_MIN_WIDTH then
				for k = 1, extra do
					railButtonBoxes[rows + k] = box(startX + (k - 1) * (ow + m.railGap), 0, ow, BUTTON_HEIGHT)
				end
				rail = box(
					m.margin,
					m.railTop,
					startX + extra * ow + (extra - 1) * m.railGap,
					rows * BUTTON_HEIGHT + (rows - 1) * m.railGap
				)
				railScrolls = false
			end
		end
	end

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
		railButtons = railButtonBoxes,
		railScrolls = railScrolls,
		toast = toast,
		actionBar = actionBar,
		manager = manager,
	}
end

-- CM2-49: the hint bar sits top-centre below the toast row, between the rail columns.
-- CM2-UVF10: with `docked` on a compact screen (stocking mode open) the bar shrinks to the Skip
-- button, top-right below the HUD, clear of the stocking bar and the toast row.
function UiTheme.tutorialBarLayout(m: Metrics, docked: boolean?): TutorialBarLayout
	local config = UiTheme.TutorialBar
	local p = config.padding
	if docked == true and m.compact then
		local dockedWidth = config.skipWidth + 2 * p
		return {
			frame = box(m.width - m.margin - dockedWidth, m.margin + HUD_HEIGHT + GAP, dockedWidth, config.height),
			text = box(p, p, 0, BUTTON_HEIGHT),
			skip = box(p, p, config.skipWidth, BUTTON_HEIGHT),
			showText = false,
		}
	end
	local w = math.min(config.maxWidth, m.width - 2 * (m.margin + m.railWidth + RAIL_SIDE_PADDING))
	return {
		frame = box(math.floor((m.width - w) / 2), m.margin + HUD_HEIGHT + GAP + BUTTON_HEIGHT + GAP, w, config.height),
		text = box(p, p, w - 3 * p - config.skipWidth, BUTTON_HEIGHT),
		skip = box(w - p - config.skipWidth, p, config.skipWidth, BUTTON_HEIGHT),
		showText = true,
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

-- CM2-UVF11: Supplier page boxes relative to the page. Regular screens keep the single column.
-- Compact screens move the quote, the order button and the sell-back button into a right column
-- beside the species grid, so the order button stays inside the Lot Manager body without scrolling.
function UiTheme.supplierLayout(m: Metrics, pageWidth: number): SupplierLayout
	if not m.compact then
		return {
			twoColumns = false,
			detail = box(0, 152, 324, 24),
			order = box(0, 182, 324, 44),
			stockingHint = box(0, 234, 324, 36),
			supplierLine = box(0, 274, 324, 18),
			receivingLine = box(0, 292, 324, 18),
			customerLine = box(0, 310, 324, 18),
			sellBack = box(0, 334, 324, 44),
			canvasHeight = 386,
		}
	end
	local x = 332
	local w = math.max(0, math.floor(pageWidth) - x - 8)
	return {
		twoColumns = true,
		detail = box(x, 0, w, 40),
		order = box(x, 44, w, BUTTON_HEIGHT),
		stockingHint = box(x, 92, w, 40),
		supplierLine = box(0, 150, 324, 18),
		receivingLine = box(0, 168, 324, 18),
		customerLine = box(0, 186, 324, 18),
		sellBack = box(x, 136, w, BUTTON_HEIGHT),
		canvasHeight = 206,
	}
end

-- CM2-UVF12: Pricing card boxes relative to the card. Compact screens use a 168 px card (page clip
-- is about 180 px) so the whole card with its 44 px -5/-1/+1/+5 row fits the page at once.
function UiTheme.pricingCardLayout(m: Metrics): PricingCardLayout
	if not m.compact then
		return {
			cardHeight = 180,
			pitch = 188,
			name = box(10, 6, 304, 20),
			sentiment = box(10, 28, 304, 18),
			wholesaleTypical = box(10, 48, 304, 30),
			margin = box(10, 80, 304, 18),
			sizes = box(10, 98, 304, 28),
			price = box(130, 128, 64, 44),
			controlsY = 128,
			controlsHeight = 44,
		}
	end
	return {
		cardHeight = 168,
		pitch = 176,
		name = box(10, 4, 304, 18),
		sentiment = box(10, 22, 304, 16),
		wholesaleTypical = box(10, 38, 304, 28),
		margin = box(10, 66, 304, 16),
		sizes = box(10, 82, 304, 28),
		price = box(130, 120, 64, BUTTON_HEIGHT),
		controlsY = 120,
		controlsHeight = BUTTON_HEIGHT,
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
-- to the frame; every value is clamped to >= 0. CM2-UVF10: the compact bar gives the reason two
-- lines (rows at y 58 and 106, still inside the 154 px frame).
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
	row(STOCKING_TOP_ROW, if m.compact then 58 else 52, unit)
	row(STOCKING_BOTTOM_ROW, if m.compact then 106 else 102, unit)
	local x = if m.compact then math.floor(0.3 * m.width) else math.floor((m.width - w) / 2)
	return {
		frame = clampedBox(x, m.height - m.margin - 154, w, 154),
		header = if m.compact then clampedBox(8, 4, w - 16, 18) else clampedBox(8, 8, w - 16, 20),
		reason = if m.compact then clampedBox(8, 24, w - 16, 32) else clampedBox(8, 30, w - 16, 16),
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
