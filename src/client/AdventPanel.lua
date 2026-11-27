--!strict
-- Advent calendar panel (CM2-A1, docs/plans/CM2-A1.md): 24 doors from the Advent* player
-- attributes. It only sends Advent.Open {door} through the validated BusinessAction remote; the
-- server owns the date, the opened doors and every reward.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local LotManager = require(script.Parent:WaitForChild("LotManager") :: ModuleScript)

local AdventPanel = {}

export type Panel = {}

local MODAL_ID = "Advent"
local BUTTON_HEIGHT = UiTheme.MinTouch
local CLOSE_WIDTH = 120
local DOOR_COUNT = GameConfig.Advent.LastDay
local SPECIAL_DOORS = { [6] = true, [24] = true }

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat
local textLabel = UiKit.label
local textButton = UiKit.button
local corner = UiKit.corner

local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand
local CREAM = UiKit.Colors.Cream
local DARK = UiKit.Colors.DarkText

local ERROR_KEYS: { [string]: string } = {
	CalendarClosed = "adventErrorClosed",
	AlreadyClaimed = "rewardErrorClaimed",
	RateLimited = "shopErrorBusy",
	ClaimBusy = "shopErrorBusy",
}

local function numberAttribute(name: string): number
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value and value >= 0 then
		return math.floor(value)
	end
	return 0
end

local function decorName(id: unknown): string
	return localized("decorName" .. tostring(id))
end

-- The status line for a successful open; amounts come from the server's response.
local function successText(door: number, data: any): string
	local cash = if type(data.cash) == "number" then data.cash else 0
	local reputation = if type(data.reputation) == "number" then data.reputation else 0
	if type(data.decor) == "string" and cash > 0 then
		return localizedFormat("adventGotSpecial", door, UiTheme.formatMoney(cash), reputation, decorName(data.decor))
	end
	if type(data.decor) == "string" then
		return localizedFormat("adventGotDecor", door, decorName(data.decor))
	end
	if AdventCalendar.rewardFor(door).boostSeconds > 0 then
		local applied = if type(data.boostSeconds) == "number" then data.boostSeconds else 0
		if applied <= 0 then
			return localizedFormat("adventGotBoostFull", door)
		end
		return localizedFormat("adventGotBoost", door, math.ceil(applied / 60))
	end
	if cash > 0 then
		return localizedFormat("adventGotCash", door, UiTheme.formatMoney(cash))
	end
	return localizedFormat("adventGotReputation", door, reputation)
end

local function errorText(code: unknown, door: number): string
	if code == "DoorLocked" then
		return localizedFormat("adventErrorLocked", door)
	end
	local key = if type(code) == "string" then ERROR_KEYS[code] else nil
	return localized(key or "rewardErrorFailed")
end

function AdventPanel.new(context: LotManager.TabContext): Panel
	-- Layout --------------------------------------------------------------------------------

	local gui = UiKit.screenGui("AdventUI", 15)
	local railButton = UiKit.addRailButton("AdventButton", "adventButton", 40)

	local panel = Instance.new("Frame")
	panel.Name = "AdventPanel"
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	corner(panel, UiTheme.CornerRadius.Panel)
	UiKit.padding(panel, 12)

	local title = textLabel(panel, "Title", localized("adventTitle"), 22)
	title.Size = UDim2.new(1, 0, 0, 30)

	local hint = textLabel(panel, "Hint", localized("adventHint"), UiTheme.TextSize.Small)
	hint.Position = UDim2.fromOffset(0, 30)
	hint.Size = UDim2.new(1, 0, 0, 30)
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
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 6, -6, 0, 56)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.BorderSizePixel = 0
	footer.Parent = panel

	local status = textLabel(footer, "Status", "", UiTheme.TextSize.Small)
	status.Size = UDim2.new(1, -(CLOSE_WIDTH + 8), 1, 0)
	status.TextWrapped = true

	local closeButton = textButton(footer, "CloseButton", localized("adventClose"), SAND)
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.fromScale(1, 1)
	closeButton.Size = UDim2.fromOffset(CLOSE_WIDTH, BUTTON_HEIGHT)

	UiKit.bindDialog(
		gui,
		{ frame = panel, list = list, footer = footer, rightHeader = title, leftItems = { hint } },
		UiTheme.Dialogs.Advent
	)

	local doors: { TextButton } = {}
	for door = 1, DOOR_COUNT do
		local button = textButton(list, "Door_" .. door, "", ROW, UiTheme.TextSize.Small)
		button.LayoutOrder = door
		if SPECIAL_DOORS[door] then
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = GOLD
			stroke.Thickness = 2
			stroke.Parent = button
		end
		doors[door] = button
	end

	-- State ---------------------------------------------------------------------------------

	local inFlight = false

	local function isOpenPhase(): boolean
		return player:GetAttribute("AdventPhase") == "Open"
	end

	local function isReady(): boolean
		return player:GetAttribute("CompanyReady") == true
	end

	local function renderDoors()
		local today = if isOpenPhase() then numberAttribute("AdventToday") else 0
		local opened = numberAttribute("AdventOpened")
		for door, button in ipairs(doors) do
			local isOpened = bit32.band(opened, bit32.lshift(1, door - 1)) ~= 0
			local stateKey, color, active
			if isOpened then
				stateKey, color, active = "adventDoorOpened", SAND, false
			elseif door <= today then
				stateKey, color, active = "adventDoorOpen", GOLD, not inFlight
			else
				stateKey, color, active = "adventDoorLocked", ROW, false
			end
			button.Text = tostring(door) .. "\n" .. localized(stateKey)
			button.BackgroundColor3 = color
			button.TextColor3 = if color == ROW then CREAM else DARK
			button.Active = active
			button.AutoButtonColor = active
		end
	end

	local function updateRail()
		railButton.Visible = isReady() and isOpenPhase()
		local claimable = numberAttribute("AdventClaimable")
		railButton.Text = if claimable > 0
			then localizedFormat("adventButtonCount", claimable)
			else localized("adventButton")
	end

	-- Open a door ---------------------------------------------------------------------------

	local function openDoor(door: number)
		if inFlight then
			return
		end
		inFlight = true
		renderDoors()
		local response = context.request("Advent.Open", { door = door })
		inFlight = false
		if response.ok and type(response.data) == "table" then
			status.Text = successText(door, response.data)
		else
			status.Text = errorText(response.errorCode, door)
		end
		renderDoors()
		context.refresh()
	end

	for door, button in ipairs(doors) do
		button.Activated:Connect(function()
			openDoor(door)
		end)
	end

	-- Open and close ------------------------------------------------------------------------

	local close: () -> ()

	local function open()
		UiKit.claimModal(MODAL_ID, close)
		panel.Visible = true
		status.Text = ""
		renderDoors()
	end

	close = function()
		UiKit.releaseModal(MODAL_ID)
		panel.Visible = false
	end

	closeButton.Activated:Connect(close)
	railButton.Activated:Connect(function()
		if panel.Visible then
			close()
		else
			open()
		end
	end)

	local function update()
		updateRail()
		renderDoors()
		if panel.Visible and (not isReady() or not isOpenPhase()) then
			close()
		end
	end

	for _, attribute in { "CompanyReady", "AdventPhase", "AdventToday", "AdventOpened", "AdventClaimable" } do
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
	update()

	return {}
end

return AdventPanel
