--!strict
-- Land tab of the Lot Manager (CM2-G9b, docs/archive/plans/CM2-G9b.md): one card each for the lot
-- expansion, parking and HQ ladders and the Elf Workshop. Every requirement row, unlock line and
-- the `ready` flag come from the summary's `progression` table (Progression.summary); the tab
-- computes nothing. Buying is a two-tap confirm that sends the next target.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local LandView = require(Shared:WaitForChild("LandView"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit") :: ModuleScript)

type TabContext = {
	request: (action: string, payload: { [string]: any }) -> any,
	refresh: () -> (),
	summary: () -> any?,
}
type TabHandle = {
	render: (summary: any?) -> (),
	shown: ((visible: boolean) -> ())?,
}

local LandTab = {}

local CARD_TOP = 60
local CARD_GAP = 8
local CARD_INSET = 16
local BUTTON_WIDTH = 140
local BUTTON_HEIGHT = 44
local ROW_TOP = 72
local ROW_PITCH = 20
local ROW_HEIGHT = 18
local UNLOCK_HEIGHT = 18
local CARD_BOTTOM = 10
local STATE_WIDTH = 90
local ROW_INSET = 110
local CONFIRM_SECONDS = 4

-- Per card: kind, name, section key in `progression`, title key, action and payload field.
local SPECS = {
	{
		kind = "LotExpansion",
		name = "Land_LotExpansion",
		section = "lotExpansion",
		titleKey = "landLotTitle",
		action = "Progression.BuyLotExpansion",
		field = "level",
	},
	{
		kind = "Parking",
		name = "Land_Parking",
		section = "parking",
		titleKey = "landParkingTitle",
		action = "Progression.BuyParking",
		field = "tier",
	},
	{
		kind = "HQ",
		name = "Land_HQ",
		section = "hq",
		titleKey = "landHqTitle",
		action = "Progression.BuyHQ",
		field = "level",
	},
}
local WORKSHOP_NAME = "Land_Workshop"

type Card = {
	frame: Frame,
	status: TextLabel,
	next: TextLabel,
	button: TextButton?,
	dynamic: { GuiObject },
}

local function placeWide(item: GuiObject, x: number, y: number, inset: number, h: number)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.new(1, -inset, 0, h)
end

local function wrap(label: TextLabel)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

function LandTab.create(page: ScrollingFrame, context: TabContext): TabHandle
	local colors = UiKit.Colors
	local localized = UiKit.localized
	local fmt = UiKit.localizedFormat

	local title = UiKit.label(page, "LandTitle", localized("land"), UiTheme.TextSize.Title)
	placeWide(title, 0, 0, CARD_INSET, 28)
	local status = UiKit.label(page, "LandStatus", "", UiTheme.TextSize.Small)
	placeWide(status, 0, 32, CARD_INSET, 18)

	local function makeCard(name: string, titleKey: string, withButton: boolean): Card
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundColor3 = colors.Row
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = page
		UiKit.card(frame)
		local textInset = if withButton then BUTTON_WIDTH + 30 else 20
		local cardTitle = UiKit.label(frame, "Title", localized(titleKey), UiTheme.TextSize.Body)
		placeWide(cardTitle, 10, 8, textInset, 20)
		local cardStatus = UiKit.label(frame, "Status", "", UiTheme.TextSize.Small)
		placeWide(cardStatus, 10, 30, textInset, 18)
		wrap(cardStatus)
		local cardNext = UiKit.label(frame, "Next", "", UiTheme.TextSize.Small)
		placeWide(cardNext, 10, 50, textInset, 18)
		wrap(cardNext)
		local button: TextButton? = nil
		if withButton then
			local made = UiKit.button(frame, "Buy", localized("landBuy"), colors.Primary, UiTheme.TextSize.Small)
			made.Position = UDim2.new(1, -(BUTTON_WIDTH + 10), 0, 8)
			made.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
			button = made
		end
		return { frame = frame, status = cardStatus, next = cardNext, button = button, dynamic = {} }
	end

	local cards: { [string]: Card } = {}
	for _, spec in ipairs(SPECS) do
		cards[spec.kind] = makeCard(spec.name, spec.titleKey, true)
	end
	local workshop = makeCard(WORKSHOP_NAME, "landWorkshopTitle", false)

	local progression: any? = nil
	local confirmUntil: { [string]: number } = {}
	local busy = false

	-- Localizes `{nameKey = k}` args, then formats the line's sentence.
	local function text(line: LandView.Line): string
		local args: { any } = {}
		for index, value in ipairs(line.args) do
			if type(value) == "table" and type(value.nameKey) == "string" then
				args[index] = localized(value.nameKey)
			else
				args[index] = value
			end
		end
		return fmt(line.key, table.unpack(args, 1, #line.args))
	end

	local function clearDynamic(card: Card)
		for _, item in ipairs(card.dynamic) do
			item:Destroy()
		end
		table.clear(card.dynamic)
	end

	-- One Row_i label plus its Done/Missing state per requirement; returns the next free y.
	local function addRows(card: Card, rows: any): number
		local y = ROW_TOP
		if type(rows) ~= "table" then
			return y
		end
		for index, row in ipairs(rows) do
			local line = LandView.rowLine(row)
			local label = UiKit.label(card.frame, "Row_" .. index, text(line), UiTheme.TextSize.Small)
			placeWide(label, 10, y, ROW_INSET, ROW_HEIGHT)
			local state = UiKit.label(
				card.frame,
				"RowState_" .. index,
				localized(if line.met == true then "landRowDone" else "landRowMissing"),
				UiTheme.TextSize.Small
			)
			state.Position = UDim2.new(1, -(STATE_WIDTH + 10), 0, y)
			state.Size = UDim2.fromOffset(STATE_WIDTH, ROW_HEIGHT)
			state.TextXAlignment = Enum.TextXAlignment.Right
			state.TextColor3 = if line.met == true then colors.GoldText else colors.Muted
			table.insert(card.dynamic, label)
			table.insert(card.dynamic, state)
			y += ROW_PITCH
		end
		return y
	end

	local function addUnlocks(card: Card, unlocks: any, startY: number): number
		local y = startY
		if type(unlocks) ~= "table" then
			return y
		end
		for index, unlock in ipairs(unlocks) do
			local label =
				UiKit.label(card.frame, "Unlock_" .. index, text(LandView.unlockLine(unlock)), UiTheme.TextSize.Small)
			placeWide(label, 10, y, 20, UNLOCK_HEIGHT)
			table.insert(card.dynamic, label)
			y += UNLOCK_HEIGHT
		end
		return y
	end

	local function setButton(button: TextButton, label: string, enabled: boolean)
		button.Text = label
		button.Active = enabled
		UiKit.setEnabled(button, enabled, colors.Primary)
	end

	local function renderButton(kind: string, offer: any?)
		local button = cards[kind].button
		if button == nil then
			return
		end
		if offer == nil then
			button.Visible = false
			return
		end
		button.Visible = true
		local window = confirmUntil[kind]
		if busy then
			setButton(button, localized("loading"), false)
		elseif offer.ready ~= true then
			setButton(button, localized("landNotReady"), false)
		elseif window ~= nil and os.clock() < window then
			setButton(button, fmt("landBuyConfirm", "$" .. UiTheme.formatMoney(offer.cashCost)), true)
		else
			setButton(button, localized("landBuy"), true)
		end
	end

	local function renderAll()
		local data = progression
		if type(data) ~= "table" then
			status.Text = localized("loading")
			for _, card in pairs(cards) do
				card.frame.Visible = false
			end
			workshop.frame.Visible = false
			UiKit.setCanvasHeight(page, CARD_TOP)
			return
		end
		local y = CARD_TOP
		for _, spec in ipairs(SPECS) do
			local card = cards[spec.kind]
			local section = data[spec.section]
			if type(section) ~= "table" then
				card.frame.Visible = false
			else
				clearDynamic(card)
				card.frame.Visible = true
				card.status.Text = text(LandView.statusLine(spec.kind, section))
				card.next.Text = text(LandView.nextLine(spec.kind, section.next))
				local offer = section.next
				local rowEnd = if offer ~= nil then addRows(card, offer.rows) else ROW_TOP
				local unlockEnd = if offer ~= nil then addUnlocks(card, offer.unlocks, rowEnd) else rowEnd
				local height = unlockEnd + CARD_BOTTOM
				placeWide(card.frame, 0, y, CARD_INSET, height)
				y += height + CARD_GAP
				renderButton(spec.kind, offer)
			end
		end
		local shop = data.workshop
		if type(shop) == "table" then
			clearDynamic(workshop)
			workshop.frame.Visible = true
			workshop.status.Text =
				localized(if shop.unlocked == true then "landWorkshopUnlocked" else "landWorkshopLocked")
			workshop.next.Text = localized("landComingSoon")
			workshop.next.TextColor3 = colors.Muted
			local height = addRows(workshop, shop.rows) + CARD_BOTTOM
			placeWide(workshop.frame, 0, y, CARD_INSET, height)
			y += height + CARD_GAP
		else
			workshop.frame.Visible = false
		end
		UiKit.setCanvasHeight(page, y)
	end

	local function showError(code: unknown)
		local key = if type(code) == "string" then LandView.ERROR_KEYS[code] else nil
		status.Text = fmt("errorStatus", if key then localized(key) else tostring(code))
	end

	local function buy(spec: any)
		local data = progression
		local section = if type(data) == "table" then data[spec.section] else nil
		local offer = if type(section) == "table" then section.next else nil
		if busy or type(offer) ~= "table" or offer.ready ~= true then
			return
		end
		local kind: string = spec.kind
		local now = os.clock()
		local window = confirmUntil[kind]
		if window == nil or now >= window then
			-- First tap: the button asks to confirm for CONFIRM_SECONDS.
			local newWindow = now + CONFIRM_SECONDS
			confirmUntil[kind] = newWindow
			renderButton(kind, offer)
			task.delay(CONFIRM_SECONDS, function()
				if confirmUntil[kind] == newWindow then
					confirmUntil[kind] = nil
					renderAll()
				end
			end)
			return
		end
		confirmUntil[kind] = nil
		busy = true
		renderAll()
		local payload: { [string]: any } = {}
		payload[spec.field] = offer.target
		local response = context.request(spec.action, payload)
		busy = false
		if type(response) == "table" and response.ok == true then
			status.Text = ""
		else
			showError(if type(response) == "table" then response.errorCode else nil)
		end
		renderAll()
		context.refresh()
	end

	for _, spec in ipairs(SPECS) do
		local button = cards[spec.kind].button
		if button ~= nil then
			UiKit.onActivated(button, function()
				buy(spec)
			end)
		end
	end

	local function render(summary: any?)
		local data = if type(summary) == "table" then summary.progression else nil
		progression = if type(data) == "table" then data else nil
		if progression ~= nil and status.Text == localized("loading") then
			status.Text = ""
		end
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

return LandTab
