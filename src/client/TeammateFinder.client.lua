--!strict
-- Teammate finder (CM2-S3): players on this server who look for teammates. A joiner takes a
-- free seat on the searcher's save without a code; the searcher owns the save. Opens from the
-- "Teammates" button (while a save is played) or from the save picker's "Find teammates"
-- button through the FinderUI.Open BindableEvent. Mobile first; every button is at least
-- 44 px tall. The UI only sends Save.* requests; the server owns every result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local saveAction = remotes:WaitForChild("SaveAction") :: RemoteFunction

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat

local BUTTON_HEIGHT = UiTheme.MinTouch
local LISTING_ROW_HEIGHT = 64
local HINT_HEIGHT = 48
local GAP = 6
local SIZES = { "Duo", "Trio", "Quad" }
local DEFAULT_SIZE = "Duo"
local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand

local textLabel = UiKit.label
local textButton = UiKit.button

-- Layout ------------------------------------------------------------------------------------

-- The Teammates button lives in the left rail (slot 70).
local finderButton = UiKit.addRailButton("FinderButton", "finderButton", 70)

-- Above the save picker (DisplayOrder 20), which can open it.
local gui = UiKit.screenGui("FinderUI", 25)

local openEvent = Instance.new("BindableEvent")
openEvent.Name = "Open"
openEvent.Parent = gui

-- The size and position of the panel come from UiKit.bindDialog.
local panel = Instance.new("Frame")
panel.Name = "FinderPanel"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui
UiKit.window(panel, { dim = true })
UiKit.padding(panel, 12)

local title = textLabel(panel, "Title", localized("finderTitle"), 22)
title.Size = UDim2.new(1, 0, 0, 30)

local hint = textLabel(panel, "Hint", localized("finderHint"), UiTheme.TextSize.Small)
hint.Position = UDim2.fromOffset(0, 32)
hint.Size = UDim2.new(1, 0, 0, 36)
hint.TextWrapped = true

-- Footer, bottom up: Close, then either the search controls (sizes, Start, hint) or the own
-- listing (text, Stop). The status line is the first entry of the listing list.
local CLOSE_BOTTOM = 0
local HINT_BOTTOM = CLOSE_BOTTOM + BUTTON_HEIGHT + GAP
local START_BOTTOM = HINT_BOTTOM + HINT_HEIGHT + GAP
local SIZES_BOTTOM = START_BOTTOM + BUTTON_HEIGHT + GAP

-- The Footer frame (198 px high, see UiTheme.Dialogs.Finder) and the list are placed by
-- UiKit.bindDialog.
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.BorderSizePixel = 0
footer.Parent = panel

local listingList = Instance.new("ScrollingFrame")
listingList.Name = "ListingList"
listingList.BackgroundTransparency = 1
listingList.BorderSizePixel = 0
listingList.CanvasSize = UDim2.new()
listingList.AutomaticCanvasSize = Enum.AutomaticSize.Y
listingList.ScrollingDirection = Enum.ScrollingDirection.Y
listingList.ScrollBarThickness = 6
listingList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, GAP)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listingList

local status = UiKit.listStatus(listingList, "FinderStatus")

local empty = textLabel(listingList, "Empty", localized("finderEmpty"), 15)
empty.Size = UDim2.new(1, -8, 0, LISTING_ROW_HEIGHT)
empty.TextWrapped = true
empty.Visible = false

local selectedSize = DEFAULT_SIZE
local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(footer, "Size_" .. size, localized("saveSize" .. size), SAND)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new((index - 1) / 3, (index - 1) * 2, 1, -SIZES_BOTTOM)
	button.Size = UDim2.new(1 / 3, -4, 0, BUTTON_HEIGHT)
	sizeButtons[size] = button
end

local startListing = textButton(footer, "StartListing", localized("finderStart"), GOLD)
startListing.AnchorPoint = Vector2.new(0, 1)
startListing.Position = UDim2.new(0, 0, 1, -START_BOTTOM)
startListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

local startHint = textLabel(footer, "StartHint", localized("finderStartHint"), 13)
startHint.AnchorPoint = Vector2.new(0, 1)
startHint.Position = UDim2.new(0, 0, 1, -HINT_BOTTOM)
startHint.Size = UDim2.new(1, 0, 0, HINT_HEIGHT)
startHint.TextWrapped = true
startHint.TextTruncate = Enum.TextTruncate.None

local ownListing = textLabel(footer, "OwnListing", localized("finderOwnListing"), UiTheme.TextSize.Small)
ownListing.AnchorPoint = Vector2.new(0, 1)
ownListing.Position = UDim2.new(0, 0, 1, -(HINT_BOTTOM + BUTTON_HEIGHT + GAP))
ownListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
ownListing.TextWrapped = true
ownListing.Visible = false

local stopListing = textButton(footer, "StopListing", localized("finderStop"), SAND)
stopListing.AnchorPoint = Vector2.new(0, 1)
stopListing.Position = UDim2.new(0, 0, 1, -HINT_BOTTOM)
stopListing.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
stopListing.Visible = false

local closeButton = textButton(footer, "Close", localized("teamClose"), SAND)
closeButton.AnchorPoint = Vector2.new(0, 1)
closeButton.Position = UDim2.new(0, 0, 1, -CLOSE_BOTTOM)
closeButton.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

UiKit.bindDialog(
	gui,
	{ frame = panel, list = listingList, footer = footer, leftItems = { hint } },
	UiTheme.Dialogs.Finder
)

-- Requests ----------------------------------------------------------------------------------

-- One request in flight. A listing change announced during a request (FinderRevision) or an
-- own action asks for exactly one fetch after that request returns.
local inFlight = false
local refetchPending = false

local function send(action: string, payload: { [string]: any }): any
	inFlight = true
	local response = UiKit.request(saveAction, action, payload)
	inFlight = false
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

-- A successful Join, or a Start from the picker (no company yet), closes the panel; the picker closes itself on CompanyReady.
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
	UiKit.card(row)
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
	UiKit.onActivated(join, function()
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
	UiKit.claimModal("Finder", close)
	panel.Visible = true
	status.Text = ""
	fetchListings()
end

close = function()
	UiKit.releaseModal("Finder")
	panel.Visible = false
	refetchPending = false
end

for size, button in pairs(sizeButtons) do
	UiKit.onActivated(button, function()
		selectedSize = size
		updateSizeButtons()
	end)
end
updateSizeButtons()

UiKit.onActivated(startListing, function()
	act("Save.FinderStart", { size = selectedSize }, player:GetAttribute("CompanyReady") ~= true)
end)

UiKit.onActivated(stopListing, function()
	act("Save.FinderStop", {}, false)
end)

UiKit.onActivated(closeButton, close)
UiKit.onActivated(finderButton, function()
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
