--!strict
-- Employees tab of the Lot Manager (CM2-25/26 part b, docs/archive/plans/CM2-25-26b.md): one card per
-- role with the one-time cost, a two-tap Hire button and, once hired, the employee's energy and
-- status; "X / N hired", the no-wages line and the button that moves the staff break area.
-- Every figure comes from the server summary's `staff` table; hiring is decided by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit") :: ModuleScript)
local BreakAreaMode = require(script.Parent.Parent:WaitForChild("BreakAreaMode") :: ModuleScript)

type TabContext = {
	request: (action: string, payload: { [string]: any }) -> any,
	refresh: () -> (),
	summary: () -> any?,
}
type TabHandle = {
	render: (summary: any?) -> (),
	shown: ((visible: boolean) -> ())?,
}

local EmployeesTab = {}

local ROLES = { "Cashier", "LotWorker", "LotManager" }
local CARD_TOP = 80
local CARD_HEIGHT = 132
local CARD_PITCH = 140
local CARD_INSET = 16
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 44
local BAR_WIDTH = 200
local BAR_HEIGHT = 10
local LINE_HEIGHT = 20
local CONFIRM_SECONDS = 4

local STATUS_KEYS: { [string]: string } = {
	Working = "staffWorking",
	OnTheWay = "staffOnTheWay",
	Resting = "staffResting",
	Arriving = "staffArriving",
	Standby = "staffStandby",
}

-- Hire refusals and the sentence shown for each (inside errorStatus).
local ERROR_KEYS: { [string]: string } = {
	EmployeeLocked = "staffLocked",
	EmployeeCapacity = "staffCapacityFull",
	InsufficientFunds = "insufficientFunds",
	AlreadyHired = "staffHired",
	RateLimited = "saveErrorRateLimited",
}

type Card = {
	frame: Frame,
	name: TextLabel,
	role: TextLabel,
	cost: TextLabel,
	status: TextLabel,
	locked: TextLabel,
	bar: Frame,
	fill: Frame,
	button: TextButton,
}

local function place(item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(w, h)
end

-- Full width of the page minus `inset`, at offset (x, y).
local function placeWide(item: GuiObject, x: number, y: number, inset: number, h: number)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.new(1, -inset, 0, h)
end

local function wrap(label: TextLabel)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

function EmployeesTab.create(page: ScrollingFrame, context: TabContext): TabHandle
	local colors = UiKit.Colors
	local localized = UiKit.localized
	local fmt = UiKit.localizedFormat

	local title = UiKit.label(page, "EmployeesTitle", localized("employees"), UiTheme.TextSize.Title)
	placeWide(title, 0, 0, CARD_INSET, 28)
	local hiredCount = UiKit.label(page, "HiredCount", localized("loading"), UiTheme.TextSize.Body)
	placeWide(hiredCount, 0, 32, CARD_INSET, LINE_HEIGHT)
	local status = UiKit.label(page, "StaffStatus", "", UiTheme.TextSize.Small)
	placeWide(status, 0, 56, CARD_INSET, 18)

	local cards: { [string]: Card } = {}
	for _, role in ipairs(ROLES) do
		local frame = Instance.new("Frame")
		frame.Name = "Staff_" .. role
		frame.BackgroundColor3 = colors.Row
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = page
		UiKit.card(frame)
		local textInset = BUTTON_WIDTH + 30

		local name = UiKit.label(frame, "Name", localized("staff" .. role), UiTheme.TextSize.Body)
		placeWide(name, 10, 8, textInset, LINE_HEIGHT)
		local roleLine = UiKit.label(frame, "Role", localized("staff" .. role .. "Role"), UiTheme.TextSize.Small)
		placeWide(roleLine, 10, 30, textInset, 18)
		wrap(roleLine)
		local cost = UiKit.label(frame, "Cost", "", UiTheme.TextSize.Small)
		placeWide(cost, 10, 50, textInset, 18)
		local statusLine = UiKit.label(frame, "Status", "", UiTheme.TextSize.Small)
		placeWide(statusLine, 10, 74, textInset, 18)
		local locked = UiKit.label(frame, "Locked", localized("staffLocked"), UiTheme.TextSize.Small)
		placeWide(locked, 10, 74, textInset, 36)
		locked.TextColor3 = colors.Sand
		wrap(locked)
		local bar = Instance.new("Frame")
		bar.Name = "EnergyBar"
		bar.BackgroundColor3 = colors.ListWell
		bar.BorderSizePixel = 0
		place(bar, 10, 98, BAR_WIDTH, BAR_HEIGHT)
		bar.Parent = frame
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = colors.Gold
		fill.BorderSizePixel = 0
		place(fill, 0, 0, 0, BAR_HEIGHT)
		fill.Parent = bar
		local button = UiKit.button(frame, "Hire", localized("staffHire"), colors.Gold, UiTheme.TextSize.Small)
		button.Position = UDim2.new(1, -(BUTTON_WIDTH + 10), 0, math.floor((CARD_HEIGHT - BUTTON_HEIGHT) / 2))
		button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)

		cards[role] = {
			frame = frame,
			name = name,
			role = roleLine,
			cost = cost,
			status = statusLine,
			locked = locked,
			bar = bar,
			fill = fill,
			button = button,
		}
	end

	local noCashier = UiKit.label(page, "NoCashier", localized("staffNoCashier"), UiTheme.TextSize.Small)
	noCashier.TextColor3 = colors.Sand
	wrap(noCashier)
	noCashier.Visible = false
	local noWages = UiKit.label(page, "NoWages", localized("staffNoWages"), UiTheme.TextSize.Small)
	wrap(noWages)
	noWages.Visible = false
	local breakTitle = UiKit.label(page, "BreakAreaTitle", localized("breakAreaTitle"), UiTheme.TextSize.Body)
	breakTitle.Visible = false
	local moveButton =
		UiKit.button(page, "MoveBreakArea", localized("breakAreaMove"), colors.Sand, UiTheme.TextSize.Small)
	moveButton.Visible = false

	local entries: { [string]: any } = {}
	local cash: number? = nil
	local confirmUntil: { [string]: number } = {}
	local busy = false

	local function setButton(button: TextButton, text: string, enabled: boolean)
		button.Text = text
		button.Active = enabled
		button.BackgroundColor3 = if enabled then colors.Gold else colors.Disabled
	end

	-- Whether the role's button may send a hire.
	local function hireable(entry: any): boolean
		if entry.locked == true or entry.hired == true then
			return false
		end
		return cash == nil or cash >= entry.hireCost
	end

	local function renderCard(role: string)
		local card = cards[role]
		local entry = entries[role]
		if type(entry) ~= "table" then
			card.frame.Visible = false
			return
		end
		card.frame.Visible = true
		card.cost.Text = fmt("staffCost", UiTheme.formatMoney(entry.hireCost))
		local hired = entry.hired == true
		local statusKey = if hired then STATUS_KEYS[entry.status] else nil
		card.status.Visible = hired
		card.bar.Visible = hired
		if hired then
			local energy = math.floor(math.clamp(if type(entry.energy) == "number" then entry.energy else 0, 0, 100))
			card.status.Text = fmt("staffStatus", energy, localized(statusKey or "staffArriving"))
			card.fill.Size = UDim2.fromOffset(math.floor(BAR_WIDTH * energy / 100), BAR_HEIGHT)
		end
		card.locked.Visible = entry.locked == true
		local button = card.button
		if entry.locked == true then
			setButton(button, localized("staffLockedShort"), false)
		elseif hired then
			setButton(button, localized("staffHired"), false)
		elseif not hireable(entry) then
			setButton(button, localized("insufficientFunds"), false)
		elseif confirmUntil[role] ~= nil and os.clock() < confirmUntil[role] then
			setButton(button, fmt("staffHireConfirm", UiTheme.formatMoney(entry.hireCost)), not busy)
		else
			setButton(button, localized("staffHire"), not busy)
		end
	end

	-- Cards stack from CARD_TOP; the no-cashier line sits under the Cashier card.
	local function layout(showFooter: boolean)
		local y = CARD_TOP
		for _, role in ipairs(ROLES) do
			local card = cards[role]
			if card.frame.Visible then
				placeWide(card.frame, 0, y, CARD_INSET, CARD_HEIGHT)
				y += CARD_PITCH
				if role == "Cashier" and noCashier.Visible then
					placeWide(noCashier, 0, y - 4, CARD_INSET, 36)
					y += 36
				end
			end
		end
		noWages.Visible = showFooter
		breakTitle.Visible = showFooter
		moveButton.Visible = showFooter
		placeWide(noWages, 0, y, CARD_INSET, 36)
		y += 40
		placeWide(breakTitle, 0, y, CARD_INSET, LINE_HEIGHT)
		y += LINE_HEIGHT + 4
		place(moveButton, 0, y, 200, BUTTON_HEIGHT)
		y += BUTTON_HEIGHT + 8
		page.CanvasSize = UDim2.fromOffset(0, y)
	end

	local function renderAll()
		for _, role in ipairs(ROLES) do
			renderCard(role)
		end
		local cashier = entries.Cashier
		noCashier.Visible = type(cashier) == "table" and cashier.hired ~= true
		layout(next(entries) ~= nil)
	end

	local function showError(code: unknown)
		local key = if type(code) == "string" then ERROR_KEYS[code] else nil
		status.Text = fmt("errorStatus", if key then localized(key) else tostring(code))
	end

	local function hire(role: string)
		local entry = entries[role]
		if busy or type(entry) ~= "table" or not hireable(entry) then
			return
		end
		local now = os.clock()
		if confirmUntil[role] == nil or now >= confirmUntil[role] then
			-- First tap: the button asks to confirm for CONFIRM_SECONDS.
			confirmUntil[role] = now + CONFIRM_SECONDS
			renderCard(role)
			task.delay(CONFIRM_SECONDS, function()
				if confirmUntil[role] ~= nil and os.clock() >= confirmUntil[role] then
					confirmUntil[role] = nil
					renderCard(role)
				end
			end)
			return
		end
		confirmUntil[role] = nil
		busy = true
		renderAll()
		local response = context.request("Employee.Hire", { employeeId = role })
		busy = false
		if type(response) == "table" and response.ok == true then
			status.Text = ""
		else
			showError(if type(response) == "table" then response.errorCode else nil)
		end
		renderAll()
		context.refresh()
	end

	for _, role in ipairs(ROLES) do
		UiKit.onActivated(cards[role].button, function()
			hire(role)
		end)
	end
	UiKit.onActivated(moveButton, function()
		local plotId = (Players.LocalPlayer :: Player):GetAttribute("PlotId")
		if type(plotId) == "string" then
			BreakAreaMode.start(plotId, context.request, context.refresh)
		end
	end)

	local function render(summary: any?)
		local staff = if type(summary) == "table" then summary.staff else nil
		table.clear(entries)
		if type(staff) ~= "table" or type(staff.roles) ~= "table" then
			cash = nil
			hiredCount.Text = localized("loading")
			renderAll()
			return
		end
		cash = if type((summary :: any).cash) == "number" then (summary :: any).cash else nil
		for _, entry in ipairs(staff.roles) do
			if type(entry) == "table" and type(entry.id) == "string" and cards[entry.id] ~= nil then
				entries[entry.id] = entry
			end
		end
		local count = if type(staff.hiredCount) == "number" then math.floor(staff.hiredCount) else 0
		local capacity = if type(staff.capacity) == "number" then math.floor(staff.capacity) else 0
		hiredCount.Text = fmt("staffHiredCount", count, capacity)
		renderAll()
	end

	return {
		render = render,
		shown = function(visible: boolean)
			if not visible then
				table.clear(confirmUntil)
				status.Text = ""
				renderAll()
			end
		end,
	}
end

return EmployeesTab
