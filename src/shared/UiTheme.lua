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
	-- Phone-only overrides (22a3b, PROVISIONAL): footer height, content height, the right header in
	-- the footer's bottom row (left 60 %), and the height of the full-width rows above both columns.
	compactFooterHeight: number?,
	compactContentHeight: number?,
	compactHeaderInFooter: boolean?,
	compactTop: number?,
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
	tabScrolls: boolean,
}

export type SupplierPanelLayout = {
	modeBuy: Box,
	modeSell: Box,
	refresh: Box,
	placeOrder: Box,
	clear: Box,
	recommend: Box,
	sellHint: Box,
	status: Box,
	cartInfo: Box,
	cartLines: Box,
	rowsTopBuy: number,
	rowsTopSell: number,
	rowPitch: number,
	rowHeight: number,
	footerHint: number,
	footerLine: number,
	footer: number,
	textSize: number,
	width: number,
}

export type SupplierRowLayout = {
	text: Box,
	minus: Box,
	qty: Box,
	plus: Box,
	max: Box,
	sell: Box?,
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

-- Plot picker (CM2-PP): panel and confirm are screen boxes; the panel children are relative to the
-- panel, confirmText/yes/no to the confirm frame.
export type PlotPickerLayout = {
	panel: Box,
	title: Box,
	prevButton: Box,
	nextButton: Box,
	plotNumber: Box,
	status: Box,
	message: Box,
	back: Box,
	choose: Box,
	confirm: Box,
	confirmText: Box,
	yes: Box,
	no: Box,
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
	Panel = { 255, 244, 217 },
	Row = { 246, 231, 196 },
	ListWell = { 236, 218, 178 },
	Gold = { 201, 153, 53 },
	Sand = { 237, 212, 142 },
	Cream = { 255, 244, 217 },
	DarkText = { 30, 48, 35 },
	Red = { 168, 62, 54 },
	Disabled = { 104, 104, 104 },
	Placeholder = { 120, 110, 90 },
	Outline = { 22, 48, 34 },
	Shadow = { 0, 0, 0 },
	Toast = { 255, 244, 217 },
	Valid = { 114, 172, 113 },
	-- CM2-UI2: title bands, primary actions, muted and highlight text on cream surfaces.
	Header = { 20, 68, 48 },
	Primary = { 38, 89, 63 },
	Muted = { 92, 80, 56 },
	GoldText = { 128, 88, 16 },
} :: { [string]: { number } }

-- CM2-UI1: one family, weights by role (PROVISIONAL look values except those named in 22a).
UiTheme.Fonts = {
	Family = "rbxasset://fonts/families/Nunito.json",
	Weights = { Title = "Heavy", Body = "Bold", Light = "SemiBold" },
}
UiTheme.TextSize = { Title = 22, Body = 15, Small = 13, Chip = 16, Input = 16, Arrow = 36, WorldArrow = 40 }
UiTheme.MinTouch = 44
UiTheme.CornerRadius = { Button = 8, Row = 10, Panel = 12 }

-- CM2-UI1 kit tokens (PROVISIONAL): strokes in px, transparencies 0..1.
UiTheme.Style = {
	StrokeControl = 2,
	StrokeSelected = 3,
	StrokeCard = 1,
	StrokeTitle = 1.5,
	StrokeTransparency = 0.15,
	GradientBottom = 0.92,
	ShadowOffset = 4,
	ShadowTransparency = 0.7,
	DimTransparency = 0.45,
	HeaderInset = 10,
}

-- Times in seconds, scales as UIScale values.
UiTheme.Motion = {
	hoverScale = 1.05,
	hoverTime = 0.15,
	pressScale = 0.95,
	pressTime = 0.08,
	releaseTime = 0.15,
	openScale = 0.95,
	openTime = 0.18,
	closeTime = 0.12,
	toastTime = 0.2,
	toastSlide = 12,
	tabTime = 0.2,
	indicatorHeight = 4,
}

-- Engine content on every client: no asset ID, upload or licence (CM2-UI1 deviation from 22a (b)).
UiTheme.ClickSound = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5 }

function UiTheme.fontFace(role: string): Font
	return Font.new(UiTheme.Fonts.Family, Enum.FontWeight[UiTheme.Fonts.Weights[role]])
end
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

-- The entrance gate's name board (CM2-GATEW, PROVISIONAL): SurfaceGui density, distance, text sizes.
UiTheme.LotGate = {
	pixelsPerStud = 40,
	nameMaxTextSize = 60,
	nameMinTextSize = 18,
	padding = 10,
	maxDistance = 150,
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
		compactHeaderInFooter = true,
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
		compactContentHeight = 194,
	},
	Team = {
		listTop = 120,
		footerHeight = 96,
		minList = 56,
		maxWidth = 420,
		maxHeight = 560,
		widthScale = 0.92,
		heightScale = 0.8,
		compactTop = 30,
	},
	-- Shop and Event minList 100 (22a3b, PROVISIONAL): one 96 px product row fits on the 780x281 phone.
	Shop = {
		listTop = 92,
		footerHeight = 52,
		minList = 100,
		maxWidth = 560,
		maxHeight = 600,
		widthScale = 0.94,
		heightScale = 0.86,
		compactTop = 82,
	},
	Finder = {
		listTop = 72,
		footerHeight = 198,
		minList = 64,
		maxWidth = 420,
		maxHeight = 560,
		widthScale = 0.92,
		heightScale = 0.8,
		compactFooterHeight = 148,
		compactTop = 30,
	},
	-- Daily rewards and quests panel (CM2-G11).
	Quests = {
		listTop = 40,
		footerHeight = 52,
		minList = 120,
		maxWidth = 520,
		maxHeight = 600,
		widthScale = 0.92,
		heightScale = 0.86,
	},
	-- Advent calendar panel (CM2-A1): the Quests dialog with room for title and hint.
	Advent = {
		listTop = 64,
		footerHeight = 52,
		minList = 120,
		maxWidth = 560,
		maxHeight = 560,
		widthScale = 0.92,
		heightScale = 0.86,
	},
	-- Event shop panel (CM2-45): title, countdown and hint above the item list.
	Event = {
		listTop = 92,
		footerHeight = 52,
		minList = 100,
		maxWidth = 560,
		maxHeight = 600,
		widthScale = 0.94,
		heightScale = 0.86,
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

-- Plot picker at session start (CM2-PP). PROVISIONAL.
UiTheme.PlotPicker = {
	cameraHeight = 55,
	cameraBack = 60,
	tweenSeconds = 0.6,
	displayOrder = 21,
	numberTextSize = 18,
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
local PHONE_MANAGER_PADDING = 6 -- PROVISIONAL (22a3c)
local PHONE_TAB_WIDTH = 100 -- PROVISIONAL (22a3c)
local TAB_SCROLLBAR = 6 -- PROVISIONAL (22a3c)
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
		-- Phones cap the Lot Manager at 70 % x 80 % of the safe area (22a3c).
		local w = math.max(0, math.min(math.floor(0.7 * m.width), m.width - 2 * m.margin))
		local h = math.max(0, math.min(math.floor(0.8 * m.height), m.height - 2 * m.margin))
		manager = box(math.floor((m.width - w) / 2), math.floor((m.height - h) / 2), w, h)
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
	local padding = if m.compact then PHONE_MANAGER_PADDING else 12
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
		-- Phones: a scrolling vertical tab column on the left (22a3c).
		local phoneTabBar = box(0, 50, PHONE_TAB_WIDTH, ch - 50)
		local phoneScrolls = count * 48 - 4 > phoneTabBar.h
		local tw = PHONE_TAB_WIDTH - (if phoneScrolls then TAB_SCROLLBAR else 0)
		for index = 1, count do
			table.insert(tabs, box(0, (index - 1) * 48, tw, BUTTON_HEIGHT))
		end
		return {
			padding = padding,
			header = header,
			title = title,
			close = close,
			cash = cash,
			tabBar = phoneTabBar,
			tabs = tabs,
			body = box(PHONE_TAB_WIDTH + 6, 50, cw - PHONE_TAB_WIDTH - 6, ch - 50),
			tabScrolls = phoneScrolls,
		}
	end
	for index = 1, count do
		table.insert(tabs, box(0, (index - 1) * (48 + 6), 168, 48))
	end
	local tabBar = box(0, 52, 168, ch - 52)
	return {
		padding = padding,
		header = header,
		title = title,
		close = close,
		cash = nil,
		tabBar = tabBar,
		tabs = tabs,
		body = box(180, 52, cw - 180, ch - 52),
		tabScrolls = count * 54 - 6 > tabBar.h,
	}
end

-- CM2-SUP: Supplier panel boxes relative to the page, one column on every screen. The width
-- keeps 8 px clear of the page scroll bar; every button is at least 44 x 44.
function UiTheme.supplierPanelLayout(m: Metrics, pageWidth: number): SupplierPanelLayout
	local W = math.max(0, math.floor(pageWidth) - 8)
	local pw = math.floor((W - 88) / 2)
	if m.compact then
		-- Phones stack the row text over the controls so 14 px text keeps the full width (22a3c).
		local mw = math.floor((W - 4) / 2)
		local ch1 = 40
		return {
			modeBuy = box(0, 0, mw, 44),
			modeSell = box(mw + 4, 0, W - mw - 4, 44),
			refresh = box(0, 48, W, 20),
			placeOrder = box(0, 94, pw, 44),
			clear = box(pw + 4, 94, 80, 44),
			recommend = box(pw + 88, 94, W - pw - 88, 44),
			sellHint = box(0, 94, W, 100),
			status = box(0, 70, W, 20),
			cartInfo = box(0, 142, W, ch1),
			cartLines = box(0, 144 + ch1, W, ch1),
			rowsTopBuy = 148 + 2 * ch1,
			rowsTopSell = 198,
			rowPitch = 92,
			rowHeight = 88,
			footerHint = 40,
			footerLine = 20,
			footer = 64,
			textSize = 14,
			width = W,
		}
	end
	local h1 = 36
	return {
		modeBuy = box(0, 0, 140, 44),
		modeSell = box(144, 0, 140, 44),
		refresh = box(292, 0, W - 292, 44),
		placeOrder = box(0, 48, pw, 44),
		clear = box(pw + 4, 48, 80, 44),
		recommend = box(pw + 88, 48, W - pw - 88, 44),
		sellHint = box(0, 48, W, 44),
		status = box(0, 96, W, 18),
		cartInfo = box(0, 116, W, h1),
		cartLines = box(0, 118 + h1, W, h1),
		rowsTopBuy = 124 + 2 * h1,
		rowsTopSell = 118,
		rowPitch = 48,
		rowHeight = 44,
		footerHint = 36,
		footerLine = 18,
		footer = 58,
		textSize = 13,
		width = W,
	}
end

-- CM2-SUP: one supplier row (species x size); the sell view adds a SELL button on the right.
function UiTheme.supplierRowLayout(pageWidth: number, sellView: boolean, compact: boolean?): SupplierRowLayout
	local W = math.max(0, math.floor(pageWidth) - 8)
	local o = if sellView then 100 else 0
	-- Compact (22a3c): the text takes its own 44 px line and the controls sit below it.
	local stacked = compact == true
	local y = if stacked then 44 else 0
	return {
		text = if stacked then box(0, 0, W, 44) else box(0, 0, math.max(0, W - 208 - o), 44),
		minus = box(W - 200 - o, y, 44, 44),
		qty = box(W - 152 - o, y, 44, 44),
		plus = box(W - 104 - o, y, 44, 44),
		max = box(W - 56 - o, y, 56, 44),
		sell = if sellView then box(W - 96, y, 96, 44) else nil,
	}
end

-- CM2-UVF12: Pricing card boxes relative to the card. Compact screens use a 160 px card so one
-- whole card with its 44 px -5/-1/+1/+5 row fits the phone page (>= 162 px high, 22a3c).
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
		cardHeight = 160,
		pitch = 168,
		name = box(10, 2, 304, 18),
		sentiment = box(10, 20, 304, 16),
		wholesaleTypical = box(10, 36, 304, 28),
		margin = box(10, 64, 304, 16),
		sizes = box(10, 80, 304, 28),
		price = box(130, 112, 64, BUTTON_HEIGHT),
		controlsY = 112,
		controlsHeight = BUTTON_HEIGHT,
	}
end

local COMPACT_FOOTER_MIN = 200

function UiTheme.dialogLayout(m: Metrics, spec: DialogSpec): DialogLayout
	local hasFooter = not (spec.footerHeight == 0 and spec.listTop == 0)
	local frame: Box
	if m.compact then
		-- Phones cap dialogs at 70 % x 80 % of the safe area (PRODUCT_SPEC "Compact on phone", 22a3b).
		local w = math.min(m.width - 2 * m.margin, 760, math.floor(0.7 * m.width))
		local h = math.min(m.height - 2 * m.margin, math.floor(0.8 * m.height))
		frame = box(math.floor((m.width - math.max(0, w)) / 2), math.floor((m.height - math.max(0, h)) / 2), w, h)
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
		leftWidth = math.max(0, math.min(math.floor((iw - 12) * 0.55), iw - 12 - COMPACT_FOOTER_MIN))
		if hasFooter then
			local footerHeight = spec.compactFooterHeight or spec.footerHeight
			list = box(0, spec.listTop, leftWidth, ih - spec.listTop)
			footer = box(leftWidth + 12, ih - footerHeight, iw - 12 - leftWidth, footerHeight)
			if spec.compactHeaderInFooter then
				rightHeader =
					box(footer.x, footer.y + footer.h - BUTTON_HEIGHT, math.floor(0.6 * footer.w) - 4, BUTTON_HEIGHT)
			else
				rightHeader = box(leftWidth + 12, 0, iw - 12 - leftWidth, BUTTON_HEIGHT)
			end
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

-- Finder footer on phones (22a3b), relative to the footer (height 148): three size buttons, the
-- hint or own listing, then Start or Stop beside Close.
function UiTheme.finderFooterCompact(w: number): { [string]: Box }
	local unit = math.floor((w - 8) / 3)
	local half = math.floor((w - 6) / 2)
	local boxes: { [string]: Box } = {}
	for i, key in ipairs({ "Size_Duo", "Size_Trio", "Size_Quad" }) do
		boxes[key] = box((i - 1) * (unit + 4), 0, unit, 44)
	end
	boxes.StartHint = box(0, 50, w, 48)
	boxes.OwnListing = box(0, 50, w, 48)
	boxes.StartListing = box(0, 104, half, 44)
	boxes.StopListing = box(0, 104, half, 44)
	boxes.Close = box(half + 6, 104, w - half - 6, 44)
	return boxes
end

-- Delete confirm on phones (22a3b), relative to the dialog's inner area: compact delete confirm puts
-- name and buttons in one row (content 194 px).
function UiTheme.deleteConfirmRow(iw: number): { [string]: Box }
	local nameW = math.floor(iw * 0.5) - 4
	local bw = math.floor((iw - nameW - 16) / 2)
	return {
		ConfirmName = box(0, 150, nameW, 44),
		ConfirmDelete = box(nameW + 8, 150, bw, 44),
		Cancel = box(nameW + 16 + bw, 150, iw - nameW - 16 - bw, 44),
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

-- Plot picker (CM2-PP): a bottom panel (title, prev/next, plot number, status, message, Back,
-- Choose) and a centred confirm frame above it.
function UiTheme.plotPickerLayout(m: Metrics): PlotPickerLayout
	-- Phones cap both frames at 70 % of the width (PRODUCT_SPEC "Compact on phone").
	local cap = if m.compact then math.floor(0.7 * m.width) else math.huge
	local w = math.min(520, m.width - 2 * m.margin, cap)
	local panel = box(math.floor((m.width - w) / 2), m.height - m.margin - 176, w, 176)
	local half = math.floor((w - 36) / 2)
	local cw = math.min(360, m.width - 2 * m.margin, cap)
	local cx = math.floor((m.width - cw) / 2)
	-- Short screens get the one-row confirm (22a (g)): the 120 px frame would reach into the panel.
	local tall = panel.y >= 120 + 2 * m.margin
	local confirm: Box
	local confirmText: Box
	local yes: Box
	local no: Box
	if tall then
		confirm = box(cx, math.max(m.margin, math.floor((panel.y - 120) / 2)), cw, 120)
		local ch = math.floor((cw - 36) / 2)
		confirmText = box(12, 10, cw - 24, 44)
		yes = box(12, 64, ch, 44)
		no = box(24 + ch, 64, cw - 36 - ch, 44)
	else
		confirm = box(cx, math.max(m.margin, math.floor((panel.y - 64) / 2)), cw, 64)
		confirmText = box(12, 10, cw - 224, 44)
		yes = box(cw - 200, 10, 88, 44)
		no = box(cw - 100, 10, 88, 44)
	end
	return {
		panel = panel,
		title = box(12, 6, w - 24, 28),
		prevButton = box(12, 40, 52, 52),
		nextButton = box(w - 64, 40, 52, 52),
		plotNumber = box(72, 40, w - 144, 24),
		status = box(72, 64, w - 144, 32),
		message = box(12, 98, w - 24, 18),
		back = box(12, 120, half, 44),
		choose = box(24 + half, 120, w - 36 - half, 44),
		confirm = confirm,
		confirmText = confirmText,
		yes = yes,
		no = no,
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
