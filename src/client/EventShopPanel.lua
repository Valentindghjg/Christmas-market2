--!strict
-- Event shop panel (CM2-45, docs/plans/CM2-45.md): the open event's items from the company
-- summary (`summary.event`) and its countdown from the ReplicatedStorage attributes EventId
-- and EventEndsIn. It only sends Event.Buy {eventId, itemKey} through the validated
-- BusinessAction remote; the server owns the window, prices, limits and decor. Robux items
-- show "Coming soon" and never send a request or a prompt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventCalendar = require(Shared:WaitForChild("EventCalendar"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local LotManager = require(script.Parent:WaitForChild("LotManager") :: ModuleScript)

local EventShopPanel = {}

export type Panel = { render: (summary: any?) -> () }

local MODAL_ID = "Event"
local BUTTON_HEIGHT = UiTheme.MinTouch
local CLOSE_WIDTH = 120
local BUY_WIDTH = 120
local ROW_HEIGHT = 64

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat
local textLabel = UiKit.label
local textButton = UiKit.button

local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local PRIMARY = UiKit.Colors.Primary
local RED = UiKit.Colors.Red
local SAND = UiKit.Colors.Sand

local ERROR_KEYS: { [string]: string } = {
	EventClosed = "eventErrorClosed",
	PurchaseLimit = "eventErrorLimit",
	InsufficientFunds = "insufficientFunds",
	RateLimited = "shopErrorBusy",
	DuplicateRequest = "shopErrorBusy",
}

local function eventIdAttribute(): string
	local value = ReplicatedStorage:GetAttribute("EventId")
	return if type(value) == "string" then value else ""
end

local function endsInAttribute(): number
	local value = ReplicatedStorage:GetAttribute("EventEndsIn")
	if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then
		return math.floor(value)
	end
	return 0
end

local function isNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function EventShopPanel.new(context: LotManager.TabContext): Panel
	-- Layout --------------------------------------------------------------------------------

	local gui = UiKit.screenGui("EventUI", 15)
	local railButton = UiKit.addRailButton("EventButton", "eventButton", 35)

	local panel = Instance.new("Frame")
	panel.Name = "EventShopPanel"
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	UiKit.window(panel)
	UiKit.padding(panel, 12)

	local title = textLabel(panel, "Title", "", 22)
	UiKit.headerBand(title)
	title.Size = UDim2.new(1, 0, 0, 30)

	local countdown = textLabel(panel, "Countdown", "", UiTheme.TextSize.Small)
	countdown.Position = UDim2.fromOffset(0, 30)
	countdown.Size = UDim2.new(1, 0, 0, 22)

	local hint = textLabel(panel, "Hint", localized("eventHint"), UiTheme.TextSize.Small)
	hint.Position = UDim2.fromOffset(0, 52)
	hint.Size = UDim2.new(1, 0, 0, 32)
	hint.TextWrapped = true
	hint.TextTruncate = Enum.TextTruncate.None

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.BorderSizePixel = 0
	footer.Parent = panel

	local status = textLabel(footer, "Status", "", UiTheme.TextSize.Small)
	status.Size = UDim2.new(1, -(CLOSE_WIDTH + 8), 1, 0)
	status.TextWrapped = true

	local closeButton = textButton(footer, "CloseButton", localized("eventClose"), RED)
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.fromScale(1, 1)
	closeButton.Size = UDim2.fromOffset(CLOSE_WIDTH, BUTTON_HEIGHT)

	UiKit.bindDialog(
		gui,
		{ frame = panel, list = list, footer = footer, rightHeader = title, leftItems = { countdown, hint } },
		UiTheme.Dialogs.Event
	)

	-- State ---------------------------------------------------------------------------------

	local event: any = nil -- the last summary.event from the server
	local inFlight = false
	local endsIn = endsInAttribute()
	local endsAt = os.clock()
	local openToken = 0

	local function isReady(): boolean
		return player:GetAttribute("CompanyReady") == true
	end

	local function isOpenEvent(): boolean
		return eventIdAttribute() ~= ""
	end

	local function updateCountdown()
		local left = math.max(0, endsIn - math.floor(os.clock() - endsAt))
		local key, first, second = EventCalendar.countdown(left)
		countdown.Text = localizedFormat(key, first, second)
	end

	-- Rows ----------------------------------------------------------------------------------

	local buy: (key: string) -> ()

	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") and string.sub(child.Name, 1, 5) == "Item_" then
				child:Destroy()
			end
		end
	end

	local function buildRow(index: number, item: any)
		local key = item.key :: string
		local isCash = item.kind == "Cash"
		local robux = if isCash then nil else ShopConfig.byKey(key)
		if not isCash and robux == nil then
			return
		end

		local row = Instance.new("Frame")
		row.Name = "Item_" .. key
		row.LayoutOrder = index
		row.BackgroundColor3 = ROW
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		UiKit.card(row)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingTop = UDim.new(0, 6)
		rowPadding.PaddingBottom = UDim.new(0, 6)
		rowPadding.PaddingLeft = UDim.new(0, 8)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = row

		local nameText, infoText
		if isCash then
			nameText, infoText = localized("eventItem" .. key), localized("eventDesc" .. key)
		else
			local nameKey = ShopConfig.textKeys(robux :: ShopConfig.Product)
			local price = if isNumber(item.price) then item.price else (robux :: ShopConfig.Product).price
			nameText, infoText = localized(nameKey), localizedFormat("shopPrice", price)
		end

		local nameLabel = textLabel(row, "Name", nameText, 18)
		nameLabel.Size = UDim2.new(1, -(BUY_WIDTH + 8), 0, 22)

		local info = textLabel(row, "Info", infoText, UiTheme.TextSize.Small)
		info.Position = UDim2.fromOffset(0, 22)
		info.Size = UDim2.new(1, -(BUY_WIDTH + 8), 1, -22)
		info.TextWrapped = true
		info.TextYAlignment = Enum.TextYAlignment.Top
		info.TextTruncate = Enum.TextTruncate.AtEnd

		local text, color, active
		if not isCash then
			text, color, active = localized("shopComingSoon"), SAND, false
		elseif isNumber(item.bought) and isNumber(item.limit) and item.bought >= item.limit then
			text, color, active = localized("eventBoughtButton"), SAND, false
		else
			local price = if isNumber(item.price) then item.price else 0
			text, color, active = localizedFormat("eventPriceCash", UiTheme.formatMoney(price)), PRIMARY, not inFlight
		end
		local button = textButton(row, "BuyButton", text, color)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.fromOffset(BUY_WIDTH, BUTTON_HEIGHT)
		button.Active = active
		if isCash then
			UiKit.onActivated(button, function()
				if button.Active then
					buy(key)
				end
			end)
		end

		row.Parent = list
	end

	local function renderRows()
		clearRows()
		if type(event) ~= "table" then
			title.Text = ""
			return
		end
		title.Text = if type(event.titleKey) == "string" then localized(event.titleKey) else ""
		local items = if type(event.items) == "table" then event.items else {}
		for index, item in ipairs(items) do
			if type(item) == "table" and ShopConfig.isKey(item.key) then
				buildRow(index, item)
			end
		end
	end

	-- Buy -----------------------------------------------------------------------------------

	buy = function(key: string)
		if inFlight or type(event) ~= "table" or type(event.id) ~= "string" then
			return
		end
		inFlight = true
		renderRows()
		local response = context.request("Event.Buy", { eventId = event.id, itemKey = key })
		inFlight = false
		if response.ok then
			status.Text = localizedFormat("eventBought", localized("eventItem" .. key))
		else
			local code = response.errorCode
			local errorKey = if type(code) == "string" then ERROR_KEYS[code] else nil
			status.Text = localized(errorKey or "rewardErrorFailed")
		end
		renderRows()
		context.refresh()
	end

	-- Open and close ------------------------------------------------------------------------

	local close: () -> ()

	local function startCountdown(token: number)
		task.spawn(function()
			while panel.Visible and openToken == token do
				task.wait(1)
				if panel.Visible and openToken == token then
					updateCountdown()
				end
			end
		end)
	end

	local function open()
		UiKit.claimModal(MODAL_ID, close)
		openToken += 1
		panel.Visible = true
		status.Text = ""
		local summary = context.summary()
		event = if type(summary) == "table" then summary.event else nil
		renderRows()
		updateCountdown()
		startCountdown(openToken)
		task.spawn(context.refresh)
	end

	close = function()
		UiKit.releaseModal(MODAL_ID)
		openToken += 1
		panel.Visible = false
	end

	UiKit.onActivated(closeButton, close)
	UiKit.onActivated(railButton, function()
		if panel.Visible then
			close()
		else
			open()
		end
	end)

	local function update()
		railButton.Visible = isReady() and isOpenEvent()
		if panel.Visible and (not isReady() or not isOpenEvent()) then
			close()
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("EventEndsIn"):Connect(function()
		endsIn = endsInAttribute()
		endsAt = os.clock()
		if panel.Visible then
			updateCountdown()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(update)
	player:GetAttributeChangedSignal("CompanyReady"):Connect(update)
	update()

	local function render(summary: any?)
		event = if type(summary) == "table" then summary.event else nil
		if panel.Visible then
			renderRows()
		end
	end

	return { render = render }
end

return EventShopPanel
