--!strict
-- Lot Manager (CM2-40): the frame with its header, the six reference tabs and one lazily built
-- page per tab. It is presentation only; tabs send validated requests through their context.
--
-- Tab contract (for G7 Pricing, CM2-25/26 Employees and Land, G9, CM2-32/33 and CM2-35 Analytics):
--   A tab is a ModuleScript in src/client/LotManagerTabs named as UiTheme.LotManagerTabs[i].module.
--   It returns { create: (page: ScrollingFrame, context: TabContext) -> TabHandle }.
--   TabContext = { request: (action, payload) -> any, refresh: () -> (), summary: () -> any? }.
--     request goes through the BusinessAction remote and never throws; refresh asks for a new
--     summary now; summary returns the last summary or nil.
--   TabHandle = { render: (summary: any?) -> (), shown: ((visible: boolean) -> ())? }.
--     render(nil) means no data (loading, or a switched save). A tab reads only its own summary
--     sub-table (pricing, staff, plot, analytics, ...) and must not error when it is missing.
--     The tab sets its page's CanvasSize.
--   Every render and shown call runs in pcall; an error warns once per tab and never stops
--   the HUD poll. A missing module shows the "opens in a later update" placeholder; a module
--   that fails to load or create shows the error text.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme") :: ModuleScript)

local LotManager = {}

export type TabHandle = {
	render: (summary: any?) -> (),
	shown: ((visible: boolean) -> ())?,
}

export type TabContext = {
	request: (action: string, payload: { [string]: any }) -> any,
	refresh: () -> (),
	summary: () -> any?,
}

export type TabModule = {
	create: (page: ScrollingFrame, context: TabContext) -> TabHandle,
}

export type Manager = {
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
	select: (tabId: string) -> (),
	render: (summary: any?) -> (),
	applyLayout: (m: UiTheme.Metrics, box: UiTheme.Box) -> (),
}

local MODAL_ID = "LotManager"

function LotManager.new(gui: ScreenGui, context: TabContext, onOpenChanged: (open: boolean) -> ()): Manager
	local colors = UiKit.Colors
	local frame = Instance.new("Frame")
	frame.Name = "LotManager"
	frame.BackgroundColor3 = colors.Panel
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Visible = false
	frame.Parent = gui
	UiKit.window(frame)
	local inset = UiKit.padding(frame, 12)

	local title = UiKit.label(frame, "Title", UiKit.localized("lotManagerTitle"), UiTheme.TextSize.Title)
	UiKit.headerBand(title)
	local closeButton =
		UiKit.button(frame, "CloseLotManager", UiKit.localized("lotManagerClose"), colors.Red, UiTheme.TextSize.Body)
	local cashLabel = UiKit.label(frame, "ManagerCash", "", UiTheme.TextSize.Chip, true)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.TextColor3 = colors.GoldText
	cashLabel.Visible = false

	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "TabBar"
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.ScrollBarThickness = 0
	tabBar.CanvasSize = UDim2.new()
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.None
	tabBar.Parent = frame

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = frame

	local tabButtons: { [string]: TextButton } = {}
	local tabIndex: { [string]: number } = {}
	for index, tab in ipairs(UiTheme.LotManagerTabs) do
		local tabButton = UiKit.button(tabBar, "Tab_" .. tab.id, UiKit.localized(tab.labelKey), colors.Sand)
		tabButtons[tab.id] = tabButton
		tabIndex[tab.id] = index
	end

	-- The outline and the indicator bar mark the selection, so it is not shown by colour alone.
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.BackgroundColor3 = colors.Header
	indicator.BorderSizePixel = 0
	indicator.Active = false
	indicator.ZIndex = 2
	indicator.Size = UDim2.fromOffset(0, UiTheme.Motion.indicatorHeight)
	indicator.Parent = tabBar
	local indicatorTween: Tween? = nil

	local selectedId: string = UiTheme.LotManagerTabs[1].id
	local pages: { [string]: ScrollingFrame } = {}
	local handles: { [string]: TabHandle } = {}
	local warned: { [string]: boolean } = {}

	local function warnOnce(tabId: string, what: string, detail: unknown)
		if warned[tabId] then
			return
		end
		warned[tabId] = true
		warn(string.format("[LotManager] tab %s %s failed: %s", tabId, what, tostring(detail)))
	end

	local function callRender(tabId: string, summary: any?)
		local handle = handles[tabId]
		if not handle then
			return
		end
		local ok, err = pcall(handle.render, summary)
		if not ok then
			warnOnce(tabId, "render", err)
		end
	end

	local function callShown(tabId: string, visible: boolean)
		local handle = handles[tabId]
		if not handle or not handle.shown then
			return
		end
		local ok, err = pcall(handle.shown, visible)
		if not ok then
			warnOnce(tabId, "shown", err)
		end
	end

	-- Puts the indicator under the selected tab: instantly on layout, with a tween on selection.
	local function placeIndicator(animate: boolean)
		local tabButton = tabButtons[selectedId]
		local position =
			UDim2.fromOffset(tabButton.Position.X.Offset + 6, tabButton.Position.Y.Offset + tabButton.Size.Y.Offset - 6)
		local size = UDim2.fromOffset(math.max(0, tabButton.Size.X.Offset - 12), UiTheme.Motion.indicatorHeight)
		if indicatorTween then
			indicatorTween:Cancel()
			indicatorTween = nil
		end
		if animate then
			local tween = TweenService:Create(
				indicator,
				TweenInfo.new(UiTheme.Motion.tabTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = position, Size = size }
			)
			indicatorTween = tween
			tween:Play()
		else
			indicator.Position = position
			indicator.Size = size
		end
	end

	-- Keeps the selected tab inside the scrolling phone tab column (22a3c).
	local function revealSelected()
		local tabButton = tabButtons[selectedId]
		local top = tabButton.Position.Y.Offset
		local bottom = top + tabButton.Size.Y.Offset
		local view = tabBar.AbsoluteWindowSize.Y
		local y = tabBar.CanvasPosition.Y
		local reserve = UiTheme.ClipInset
		if top < y then
			tabBar.CanvasPosition = Vector2.new(0, top)
		elseif view > 0 and bottom + 2 * reserve > y + view then
			tabBar.CanvasPosition = Vector2.new(0, bottom + 2 * reserve - view)
		end
	end

	local function updateTabs(animate: boolean?)
		for tabId, tabButton in pairs(tabButtons) do
			local selected = tabId == selectedId
			tabButton.BackgroundColor3 = if selected then colors.Gold else colors.Sand
			UiKit.setSelected(tabButton, selected)
		end
		placeIndicator(animate == true)
		revealSelected()
	end

	local function message(page: ScrollingFrame, name: string, key: string)
		local text = UiKit.label(page, name, UiKit.localized(key), UiTheme.TextSize.Body)
		text.Size = UDim2.new(1, -16, 0, 80)
		text.TextWrapped = true
		text.TextYAlignment = Enum.TextYAlignment.Top
	end

	local function buildPage(tab: UiTheme.TabDef): ScrollingFrame
		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. tab.id
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 6
		UiKit.clipInset(page)
		page.ScrollingDirection = Enum.ScrollingDirection.Y
		page.CanvasSize = UDim2.new()
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = false
		page.Parent = body
		pages[tab.id] = page

		local folder = script.Parent:FindFirstChild("LotManagerTabs")
		local moduleScript = if folder then folder:FindFirstChild(tab.module) else nil
		if not (moduleScript and moduleScript:IsA("ModuleScript")) then
			message(page, "Placeholder", "lotManagerTabSoon")
			return page
		end
		local loaded, tabModule = pcall(require, moduleScript)
		if not loaded or type(tabModule) ~= "table" or type((tabModule :: any).create) ~= "function" then
			warnOnce(tab.id, "load", tabModule)
			message(page, "TabError", "lotManagerTabError")
			return page
		end
		local created, handle = pcall((tabModule :: TabModule).create, page, context)
		if not created or type(handle) ~= "table" or type((handle :: any).render) ~= "function" then
			warnOnce(tab.id, "create", handle)
			for _, child in ipairs(page:GetChildren()) do
				child:Destroy()
			end
			message(page, "TabError", "lotManagerTabError")
			return page
		end
		handles[tab.id] = handle :: TabHandle
		callRender(tab.id, context.summary())
		return page
	end

	local function selectTab(tabId: string)
		local index = tabIndex[tabId]
		if not index then
			return
		end
		local tab = UiTheme.LotManagerTabs[index]
		if tabId ~= selectedId and frame.Visible then
			callShown(selectedId, false)
		end
		selectedId = tabId
		updateTabs(true)
		if not pages[tabId] then
			buildPage(tab)
		end
		for pageId, page in pairs(pages) do
			page.Visible = pageId == selectedId
		end
		if frame.Visible then
			callShown(selectedId, true)
		end
	end

	local function close()
		if not frame.Visible then
			return
		end
		frame.Visible = false
		UiKit.releaseModal(MODAL_ID)
		callShown(selectedId, false)
		onOpenChanged(false)
	end

	local function open()
		if frame.Visible then
			return
		end
		frame.Visible = true
		UiKit.claimModal(MODAL_ID, close)
		selectTab(selectedId)
		onOpenChanged(true)
	end

	for tabId, tabButton in pairs(tabButtons) do
		UiKit.onActivated(tabButton, function()
			selectTab(tabId)
		end)
	end
	UiKit.onActivated(closeButton, close)

	local manager: Manager = {
		open = open,
		close = close,
		toggle = function()
			if frame.Visible then
				close()
			else
				open()
			end
		end,
		isOpen = function()
			return frame.Visible
		end,
		select = selectTab,
		render = function(summary: any?)
			local cash = if type(summary) == "table" and type(summary.cash) == "number" then summary.cash else nil
			cashLabel.Text = if cash
				then UiKit.localizedFormat("hudCash", UiTheme.formatMoney(cash))
				else UiKit.localized("loading")
			for tabId in pairs(handles) do
				callRender(tabId, summary)
			end
		end,
		applyLayout = function(m: UiTheme.Metrics, box: UiTheme.Box)
			local layout = UiTheme.managerLayout(m, box)
			frame.AnchorPoint = Vector2.new(0, 0)
			frame.Position = UDim2.fromOffset(box.x, box.y)
			frame.Size = UDim2.fromOffset(box.w, box.h)
			inset.PaddingTop = UDim.new(0, layout.padding)
			inset.PaddingBottom = UDim.new(0, layout.padding)
			inset.PaddingLeft = UDim.new(0, layout.padding)
			inset.PaddingRight = UDim.new(0, layout.padding)
			title.Position = UDim2.fromOffset(layout.title.x, layout.title.y)
			title.Size = UDim2.fromOffset(layout.title.w, layout.title.h)
			closeButton.Position = UDim2.fromOffset(layout.close.x, layout.close.y)
			closeButton.Size = UDim2.fromOffset(layout.close.w, layout.close.h)
			local cashBox = layout.cash
			cashLabel.Visible = cashBox ~= nil
			if cashBox then
				cashLabel.Position = UDim2.fromOffset(cashBox.x, cashBox.y)
				cashLabel.Size = UDim2.fromOffset(cashBox.w, cashBox.h)
			end
			tabBar.Position = UDim2.fromOffset(layout.tabBar.x, layout.tabBar.y)
			tabBar.Size = UDim2.fromOffset(layout.tabBar.w, layout.tabBar.h)
			tabBar.ScrollingDirection = Enum.ScrollingDirection.Y
			tabBar.ScrollBarThickness = if layout.tabScrolls then 4 else 0
			UiKit.clipOutward(tabBar)
			local canvasHeight = 0
			for index, tab in ipairs(UiTheme.LotManagerTabs) do
				local tabBox = layout.tabs[index]
				local tabButton = tabButtons[tab.id]
				if tabBox then
					tabButton.Position = UDim2.fromOffset(tabBox.x, tabBox.y)
					tabButton.Size = UDim2.fromOffset(tabBox.w, tabBox.h)
					canvasHeight = math.max(canvasHeight, tabBox.y + tabBox.h)
				end
			end
			UiKit.setCanvasHeight(tabBar, canvasHeight)
			placeIndicator(false)
			revealSelected()
			body.Position = UDim2.fromOffset(layout.body.x, layout.body.y)
			body.Size = UDim2.fromOffset(layout.body.w, layout.body.h)
		end,
	}
	updateTabs()
	return manager
end

return LotManager
