--!strict
-- Teammate finder (CM2-S3): players on this server who look for teammates. A joiner takes a
-- free seat on the searcher's save without a code; the searcher owns the save. Opens from the
-- "Teammates" button (while a save is played) or from the save picker's "Find teammates"
-- button through the FinderUI.Open BindableEvent. Mobile first; every button is at least
-- 44 px tall. The UI only sends Save.* requests; the server owns every result.
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local saveAction = remotes:WaitForChild("SaveAction") :: RemoteFunction

local locale = string.lower(string.sub(LocalizationService.RobloxLocaleId, 1, 2))
if locale ~= "de" and locale ~= "en" then
	locale = "en"
end
local function localized(key: string): string
	return Localization.get(locale, key)
end
local function localizedFormat(key: string, ...: any): string
	return Localization.format(locale, key, ...)
end

local BUTTON_HEIGHT = 44
local LISTING_ROW_HEIGHT = 64
local STATUS_HEIGHT = 32
local HINT_HEIGHT = 32
local GAP = 6
local SIZES = { "Duo", "Trio", "Quad" }
local DEFAULT_SIZE = "Duo"
local CREAM = Color3.fromRGB(255, 244, 217)
local DARK_TEXT = Color3.fromRGB(30, 48, 35)
local PANEL = Color3.fromRGB(20, 68, 48)
local ROW = Color3.fromRGB(38, 89, 63)
local GOLD = Color3.fromRGB(201, 153, 53)
local SAND = Color3.fromRGB(237, 212, 142)

local function corner(parent: Instance, radius: number)
	Instance.new("UICorner", parent).CornerRadius = UDim.new(0, radius)
end

local function textLabel(parent: Instance, name: string, text: string, textSize: number): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	value.Text = text
	value.TextColor3 = CREAM
	value.Font = Enum.Font.GothamBold
	value.TextSize = textSize
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextTruncate = Enum.TextTruncate.AtEnd
	value.Parent = parent
	return value
end

local function textButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.BackgroundColor3 = color
	value.TextColor3 = DARK_TEXT
	value.Font = Enum.Font.GothamBold
	value.TextSize = 15
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	corner(value, 8)
	return value
end

-- Layout ------------------------------------------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")

local buttonGui = Instance.new("ScreenGui")
buttonGui.Name = "FinderButtonUI"
buttonGui.DisplayOrder = 15
buttonGui.ResetOnSpawn = false
buttonGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
buttonGui.Parent = playerGui

local finderButton = textButton(buttonGui, "FinderButton", localized("finderButton"), SAND)
finderButton.AnchorPoint = Vector2.new(1, 0)
finderButton.Position = UDim2.new(1, -228, 0, 12)
finderButton.Size = UDim2.fromOffset(120, BUTTON_HEIGHT)
finderButton.Visible = false

local gui = Instance.new("ScreenGui")
gui.Name = "FinderUI"
-- Above the save picker (DisplayOrder 20), which can open it.
gui.DisplayOrder = 25
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "Open"
openEvent.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "FinderPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.92, 0.8)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui
corner(panel, 14)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(420, 560)
constraint.Parent = panel
local padding = Instance.new("UIPadding")
for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	(padding :: any)[side] = UDim.new(0, 12)
end
padding.Parent = panel

local title = textLabel(panel, "Title", localized("finderTitle"), 22)
title.Size = UDim2.new(1, 0, 0, 30)

local hint = textLabel(panel, "Hint", localized("finderHint"), 14)
hint.Position = UDim2.fromOffset(0, 32)
hint.Size = UDim2.new(1, 0, 0, 36)
hint.TextWrapped = true

-- Footer, bottom up: status, Close, then either the search controls (sizes, Start, hint) or
-- the own listing (text, Stop).
local CLOSE_BOTTOM = STATUS_HEIGHT + GAP
local HINT_BOTTOM = CLOSE_BOTTOM + BUTTON_HEIGHT + GAP
local START_BOTTOM = HINT_BOTTOM + HINT_HEIGHT + GAP
local SIZES_BOTTOM = START_BOTTOM + BUTTON_HEIGHT + GAP
local FOOTER_HEIGHT = SIZES_BOTTOM + BUTTON_HEIGHT
local LIST_TOP = 72

local listingList = Instance.new("ScrollingFrame")
listingList.Name = "ListingList"
listingList.BackgroundTransparency = 1
listingList.BorderSizePixel = 0
listingList.Position = UDim2.fromOffset(0, LIST_TOP)
listingList.Size = UDim2.new(1, 0, 1, -(LIST_TOP + FOOTER_HEIGHT + GAP))
listingList.CanvasSize = UDim2.new()
listingList.AutomaticCanvasSize = Enum.AutomaticSize.Y
listingList.ScrollingDirection = Enum.ScrollingDirection.Y
listingList.ScrollBarThickness = 6
listingList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, GAP)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listingList

local empty = textLabel(listingList, "Empty", localized("finderEmpty"), 15)
empty.Size = UDim2.new(1, -8, 0, LISTING_ROW_HEIGHT)
empty.TextWrapped = true
empty.Visible = false

local selectedSize = DEFAULT_SIZE
local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(panel, "Size_" .. size, localized("saveSize" .. size), SAND)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new((index - 1) / 3, (index - 1) * 2, 1, -SIZES_BOTTOM)
	button.Size = UDim2.new(1 / 3, -4, 0, BUTTON_HEIGHT)
	sizeButtons[size] = button
end

local startListing = textButton(panel, "StartListing", localized("finderStart"), GOLD)
startListing.AnchorPoint = Vector2.new(0, 1)
startListing.Position = UDim2.new(0, 0, 1, -START_BOTTOM)
startListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

local startHint = textLabel(panel, "StartHint", localized("finderStartHint"), 13)
startHint.AnchorPoint = Vector2.new(0, 1)
startHint.Position = UDim2.new(0, 0, 1, -HINT_BOTTOM)
startHint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
startHint.TextWrapped = true
startHint.TextTruncate = Enum.TextTruncate.None

local ownListing = textLabel(panel, "OwnListing", localized("finderOwnListing"), 15)
ownListing.AnchorPoint = Vector2.new(0, 1)
ownListing.Position = UDim2.new(0, 0, 1, -(HINT_BOTTOM + BUTTON_HEIGHT + GAP))
ownListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
ownListing.TextWrapped = true
ownListing.Visible = false

local stopListing = textButton(panel, "StopListing", localized("finderStop"), SAND)
stopListing.AnchorPoint = Vector2.new(0, 1)
stopListing.Position = UDim2.new(0, 0, 1, -HINT_BOTTOM)
stopListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
stopListing.Visible = false

local closeButton = textButton(panel, "Close", localized("teamClose"), SAND)
closeButton.AnchorPoint = Vector2.new(0, 1)
closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_BOTTOM)
closeButton.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

local status = textLabel(panel, "FinderStatus", "", 13)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.fromScale(0, 1)
status.Size = UDim2.new(1, 0, 0, STATUS_HEIGHT)
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None

-- Requests ----------------------------------------------------------------------------------

-- One request in flight. A listing change announced during a request (FinderRevision) or an
-- own action asks for exactly one fetch after that request returns.
local inFlight = false
local refetchPending = false

local function send(action: string, payload: { [string]: any }): any
	inFlight = true
	local called, response = pcall(saveAction.InvokeServer, saveAction, {
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = action,
		payload = payload,
	})
	inFlight = false
	if not called or type(response) ~= "table" then
		return { ok = false, errorCode = "ConnectionError" }
	end
	return response
end

local function showError(code: unknown)
	status.Text = localized(Localization.saveErrorKey(code))
end

local render: (data: any) -> ()
local fetchListings: () -> ()
local close: () -> ()

local function afterRequest()
	if refetchPending and panel.Visible then
		refetchPending = false
		fetchListings()
	end
end

fetchListings = function()
	if inFlight then
		refetchPending = true
		return
	end
	local response = send("Save.FinderList", {})
	if response.ok and type(response.data) == "table" then
		render(response.data)
	else
		showError(response.errorCode)
	end
	afterRequest()
end

-- A successful Start or Join closes the panel; the picker closes itself on CompanyReady.
local function act(action: string, payload: { [string]: any }, closeOnSuccess: boolean)
	if inFlight then
		return
	end
	local response = send(action, payload)
	if response.ok then
		status.Text = ""
		if closeOnSuccess then
			close()
			return
		end
	else
		showError(response.errorCode)
	end
	refetchPending = true
	afterRequest()
end

-- Rendering ---------------------------------------------------------------------------------

local function clearRows()
	for _, child in listingList:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 8) == "Listing_" then
			child:Destroy()
		end
	end
end

local function buildRow(index: number, listing)
	local row = Instance.new("Frame")
	row.Name = "Listing_" .. index
	row.LayoutOrder = index
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, LISTING_ROW_HEIGHT)
	corner(row, 10)
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingTop = UDim.new(0, 6)
	rowPadding.PaddingBottom = UDim.new(0, 6)
	rowPadding.PaddingLeft = UDim.new(0, 8)
	rowPadding.PaddingRight = UDim.new(0, 8)
	rowPadding.Parent = row

	local nameText = if type(listing.ownerName) == "string" then listing.ownerName else localized("teamUnknownPlayer")
	local nameLabel = textLabel(row, "OwnerName", nameText, 16)
	nameLabel.Size = UDim2.new(0.68, 0, 0, 26)
	-- Usernames are never auto-translated.
	nameLabel.AutoLocalize = false

	local taken = if type(listing.taken) == "number" then listing.taken else 0
	local seats = if type(listing.seats) == "number" then listing.seats else 0
	local seatsLabel = textLabel(row, "ListingSeats", localizedFormat("finderSeats", taken, seats), 13)
	seatsLabel.Position = UDim2.fromOffset(0, 28)
	seatsLabel.Size = UDim2.new(0.68, 0, 0, 22)

	local join = textButton(row, "JoinListing", localized("finderJoin"), GOLD)
	join.AnchorPoint = Vector2.new(1, 0.5)
	join.Position = UDim2.fromScale(1, 0.5)
	join.Size = UDim2.new(0.3, 0, 0, BUTTON_HEIGHT)
	join.Activated:Connect(function()
		if type(listing.saveId) == "string" then
			act("Save.FinderJoin", { saveId = listing.saveId }, true)
		end
	end)
	row.Parent = listingList
end

local function updateSizeButtons()
	for size, button in pairs(sizeButtons) do
		button.BackgroundColor3 = if size == selectedSize then GOLD else SAND
	end
end

render = function(data)
	local listings = if type(data.listings) == "table" then data.listings else {}
	clearRows()
	empty.Visible = #listings == 0
	for index, listing in ipairs(listings) do
		buildRow(index, listing)
	end
	local listed = type(data.ownSaveId) == "string"
	for _, button in pairs(sizeButtons) do
		button.Visible = not listed
	end
	startListing.Visible = not listed
	startHint.Visible = not listed
	ownListing.Visible = listed
	stopListing.Visible = listed
	updateSizeButtons()
end

-- Open and close ----------------------------------------------------------------------------

local function open()
	panel.Visible = true
	status.Text = ""
	fetchListings()
end

close = function()
	panel.Visible = false
	refetchPending = false
end

for size, button in pairs(sizeButtons) do
	button.Activated:Connect(function()
		selectedSize = size
		updateSizeButtons()
	end)
end
updateSizeButtons()

startListing.Activated:Connect(function()
	act("Save.FinderStart", { size = selectedSize }, true)
end)

stopListing.Activated:Connect(function()
	act("Save.FinderStop", {}, false)
end)

closeButton.Activated:Connect(close)
finderButton.Activated:Connect(function()
	if panel.Visible then
		close()
	else
		open()
	end
end)
openEvent.Event:Connect(function()
	if not panel.Visible then
		open()
	end
end)

local function updateReady()
	finderButton.Visible = player:GetAttribute("CompanyReady") == true
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
updateReady()

ReplicatedStorage:GetAttributeChangedSignal("FinderRevision"):Connect(function()
	if panel.Visible then
		fetchListings()
	end
end)
