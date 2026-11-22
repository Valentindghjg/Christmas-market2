--!strict
-- Save picker (CM2-S1): choose, create, rename and delete saves, and switch saves through
-- the "Saves" button. CM2-S2 adds the save size, joining by invite code and shared (Member)
-- rows, which show the owner's username instead of the save name and can only be left.
-- CM2-S3 adds "Being played by X" rows with Join (Save.Teleport), the teleport after a code
-- join of a save played elsewhere and the "Find teammates" button. Mobile first; every
-- button is at least 44 px tall. The UI only sends Save.* requests; the server validates,
-- filters names and owns every result. CM2-UVF1: the picker is the modal base layer
-- (UiKit.setBaseLayer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local saveAction = remotes:WaitForChild("SaveAction") :: RemoteFunction

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat

local BUTTON_HEIGHT = UiTheme.MinTouch
local SAVE_ROW = UiTheme.SaveRow
local ROW_HEIGHT = SAVE_ROW.height
local CREAM = UiKit.Colors.Cream
local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand
local RED = UiKit.Colors.Red
local DISABLED = UiKit.Colors.Disabled

local corner = UiKit.corner
local textLabel = UiKit.label
local textBox = UiKit.textBox

-- The picker's buttons keep their 16 px text.
local function textButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	return UiKit.button(parent, name, text, color, 16)
end

-- Layout ------------------------------------------------------------------------------------

local gui = UiKit.screenGui("SavePickerUI", 20)

-- The size and position of every dialog frame come from UiKit.bindDialog.
local function dialogFrame(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui
	corner(frame, UiTheme.CornerRadius.Panel)
	UiKit.padding(frame, 12)
	return frame
end

local picker = dialogFrame("Picker")
picker.Visible = false

local title = textLabel(picker, "Title", localized("savePickerTitle"), 22)
title.Size = UDim2.new(0.6, -4, 0, 30)

local hint = textLabel(picker, "Hint", localized("savePickerHint"), UiTheme.TextSize.Small)
hint.Position = UDim2.fromOffset(0, 30)
hint.Size = UDim2.new(0.6, -4, 0, 28)
hint.TextWrapped = true
hint.TextTruncate = Enum.TextTruncate.AtEnd

-- CM2-S3: opens the teammate finder (TeammateFinder.client.lua) above the picker.
local findTeammates = textButton(picker, "FindTeammates", localized("finderOpen"), SAND)
findTeammates.AnchorPoint = Vector2.new(1, 0)
findTeammates.Position = UDim2.fromScale(1, 0)
findTeammates.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

-- Four footer rows: size toggles, new save, join by code, back. The status line is the first
-- entry of the save list (UiKit.listStatus). The Footer frame (200 px high, see
-- UiTheme.Dialogs.Picker) and the list are placed by UiKit.bindDialog.
local FOOTER_ROW = BUTTON_HEIGHT + 8
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.BorderSizePixel = 0
footer.Parent = picker
local list = Instance.new("ScrollingFrame")
list.Name = "SaveList"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 6
list.Parent = picker
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local status = UiKit.listStatus(list, "PickerStatus")

local empty = textLabel(list, "Empty", localized("savePickerEmpty"), 15)
empty.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
empty.TextWrapped = true
empty.Visible = false

-- Footer row 1: the size of the next new save (default Solo).
local SIZES = { "Solo", "Duo", "Trio", "Quad" }
local selectedSize = "Solo"
local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(footer, "Size_" .. size, localized("saveSize" .. size), SAND)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new((index - 1) * 0.25, (index - 1) * 2, 1, -(FOOTER_ROW * 3))
	button.Size = UDim2.new(0.25, -6, 0, BUTTON_HEIGHT)
	sizeButtons[size] = button
end

local function updateSizeButtons()
	for size, button in pairs(sizeButtons) do
		button.BackgroundColor3 = if size == selectedSize then GOLD else SAND
	end
end
updateSizeButtons()
for size, button in pairs(sizeButtons) do
	button.Activated:Connect(function()
		selectedSize = size
		updateSizeButtons()
	end)
end

-- Footer row 2: new save.
local newName = textBox(footer, "NewSaveName", localized("saveNamePlaceholder"))
newName.AnchorPoint = Vector2.new(0, 1)
newName.Position = UDim2.new(0, 0, 1, -(FOOTER_ROW * 2))
newName.Size = UDim2.new(0.6, -4, 0, BUTTON_HEIGHT)

local createSave = textButton(footer, "CreateSave", localized("saveNew"), GOLD)
createSave.AnchorPoint = Vector2.new(1, 1)
createSave.Position = UDim2.new(1, 0, 1, -(FOOTER_ROW * 2))
createSave.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

-- Footer row 3: join a friend's save by invite code.
local joinCode = textBox(footer, "JoinCode", localized("joinCodePlaceholder"))
joinCode.AnchorPoint = Vector2.new(0, 1)
joinCode.Position = UDim2.new(0, 0, 1, -FOOTER_ROW)
joinCode.Size = UDim2.new(0.6, -4, 0, BUTTON_HEIGHT)

local joinSave = textButton(footer, "JoinSave", localized("joinButton"), GOLD)
joinSave.AnchorPoint = Vector2.new(1, 1)
joinSave.Position = UDim2.new(1, 0, 1, -FOOTER_ROW)
joinSave.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

local backToGame = textButton(footer, "BackToGame", localized("saveBack"), SAND)
backToGame.AnchorPoint = Vector2.new(1, 1)
backToGame.Position = UDim2.fromScale(1, 1)
backToGame.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)
backToGame.Visible = false

-- Delete confirmation, over the picker.
local confirm = dialogFrame("DeleteConfirm")
confirm.ZIndex = 2
confirm.Visible = false

local confirmTitle = textLabel(confirm, "Title", localized("saveDeleteTitle"), 22)
confirmTitle.Size = UDim2.new(1, 0, 0, 30)

local warning = textLabel(confirm, "Warning", localized("saveDeleteWarning"), 15)
warning.Position = UDim2.fromOffset(0, 36)
warning.Size = UDim2.new(1, 0, 0, 60)
warning.TextWrapped = true
warning.TextYAlignment = Enum.TextYAlignment.Top

local instruction = textLabel(confirm, "Instruction", "", 15)
instruction.Position = UDim2.fromOffset(0, 100)
instruction.Size = UDim2.new(1, 0, 0, 44)
instruction.TextWrapped = true
-- Contains the player's save name.
instruction.AutoLocalize = false

local confirmName = textBox(confirm, "ConfirmName", "")
confirmName.Position = UDim2.fromOffset(0, 150)
confirmName.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

local confirmDelete = textButton(confirm, "ConfirmDelete", localized("saveDeleteConfirm"), RED)
confirmDelete.TextColor3 = CREAM
confirmDelete.Position = UDim2.fromOffset(0, 202)
confirmDelete.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)

local confirmCancel = textButton(confirm, "Cancel", localized("saveCancel"), SAND)
confirmCancel.AnchorPoint = Vector2.new(1, 0)
confirmCancel.Position = UDim2.new(1, 0, 0, 202)
confirmCancel.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)

-- Both dialogs are placed by UiKit.bindDialog. The picker is the base layer: opening the Lot
-- Manager, Team or the stocking bar closes it; the finder opens over it.
UiKit.bindDialog(gui, {
	frame = picker,
	list = list,
	footer = footer,
	leftItems = { title, hint },
	rightHeader = findTeammates,
}, UiTheme.Dialogs.Picker)
UiKit.bindDialog(gui, { frame = confirm }, UiTheme.Dialogs.DeleteConfirm)

-- "Saves" button in the left rail (slot 50), while the picker is closed.
local savesButton = UiKit.addRailButton("SavesButton", "savesButton", 50)

-- Requests ----------------------------------------------------------------------------------

-- Only one request is in flight at a time; a tap during one is ignored.
local inFlight = false
local function request(action: string, payload: { [string]: any }): any
	if inFlight then
		return nil
	end
	inFlight = true
	local response = UiKit.request(saveAction, action, payload)
	inFlight = false
	return response
end

local function showError(code: unknown)
	status.Text = localized(Localization.saveErrorKey(code))
end

-- Rows --------------------------------------------------------------------------------------

local renamingSaveId: string? = nil
local deleteTarget: any = nil
local refreshList: () -> ()
local redrawRows: () -> ()
local close: () -> ()

local function updateConfirmButton()
	local matches = deleteTarget ~= nil and SaveProfile.confirmMatches(deleteTarget.name, confirmName.Text)
	confirmDelete.Active = matches
	confirmDelete.AutoButtonColor = matches
	confirmDelete.BackgroundColor3 = if matches then RED else DISABLED
end
confirmName:GetPropertyChangedSignal("Text"):Connect(updateConfirmButton)

local function openDeleteConfirm(entry)
	deleteTarget = entry
	instruction.Text = localizedFormat("saveDeleteInstruction", entry.name)
	confirmName.Text = ""
	updateConfirmButton()
	confirm.Visible = true
end

local function closeDeleteConfirm()
	deleteTarget = nil
	confirm.Visible = false
end

-- CM2-S3: moves the player to the server that plays the save ({saveId} or {code}).
local function teleportTo(payload: { [string]: any })
	local response = request("Save.Teleport", payload)
	if response == nil then
		return
	end
	if not response.ok then
		showError(response.errorCode)
		return
	end
	status.Text = localized("teleportJoining")
end

local function play(entry)
	status.Text = localized("saveLoading")
	local response = request("Save.Play", { saveId = entry.saveId })
	if response == nil then
		return
	end
	if not response.ok then
		showError(response.errorCode)
		if response.errorCode == "SaveInUseElsewhere" then
			-- The row now offers Join.
			refreshList()
		end
		return
	end
	-- Choosing the save that is already running needs no reload.
	if player:GetAttribute("CompanyReady") == true then
		close()
	end
end

local function rename(entry, box: TextBox)
	local response = request("Save.Rename", { saveId = entry.saveId, name = box.Text })
	if response == nil then
		return
	end
	if not response.ok then
		showError(response.errorCode)
		return
	end
	renamingSaveId = nil
	status.Text = ""
	refreshList()
end

-- A shared save whose Leave button was tapped once.
local leaveArmedSaveId: string? = nil

local function leaveTeam(entry)
	local response = request("Save.LeaveTeam", { saveId = entry.saveId })
	if response == nil then
		return
	end
	if not response.ok then
		showError(response.errorCode)
	else
		status.Text = ""
	end
	refreshList()
end

local function buildRow(index: number, entry)
	local row = Instance.new("Frame")
	row.Name = "SaveRow_" .. index
	row.LayoutOrder = index
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	corner(row, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, SAVE_ROW.padding)
	padding.PaddingBottom = UDim.new(0, SAVE_ROW.padding)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = row

	local member = entry.role == "Member"
	local renaming = not member and renamingSaveId == entry.saveId
	local nameBox: TextBox? = nil
	if renaming then
		local box = textBox(row, "NameBox", localized("saveNamePlaceholder"))
		box.Text = entry.name
		box.Size = UDim2.new(1, 0, 0, 34)
		nameBox = box
	else
		-- A member never receives the save name; the owner's username stands in for it.
		local shownName = if not member
			then entry.name
			elseif type(entry.ownerName) == "string" then localizedFormat("sharedSaveName", entry.ownerName)
			else localized("sharedSaveNameUnknown")
		local nameLabel = textLabel(row, "SaveName", shownName, SAVE_ROW.nameTextSize)
		nameLabel.Size = UDim2.new(1, 0, 0, SAVE_ROW.nameHeight)
		nameLabel.TextWrapped = true
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		-- Player-chosen names are never auto-translated.
		nameLabel.AutoLocalize = false
		local subKey = if entry.active then "saveRowActive" elseif entry.lastPlayed then "saveRowLastPlayed" else nil
		local sub = textLabel(row, "SaveState", if subKey then localized(subKey) else "", SAVE_ROW.textSize)
		sub.Position = UDim2.fromOffset(0, SAVE_ROW.nameHeight + SAVE_ROW.kindHeight)
		sub.Size = UDim2.new(1, 0, 0, SAVE_ROW.stateHeight)
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		-- CM2-S3: another server plays this save.
		if entry.elsewhere == true then
			if type(entry.hostName) == "string" then
				sub.Text = localizedFormat("saveRowElsewhere", entry.hostName)
				-- Contains a username.
				sub.AutoLocalize = false
			else
				sub.Text = localized("saveRowElsewhereUnknown")
			end
		end
	end

	-- Solo, or a co-op save with its seat count.
	local seats = if type(entry.seats) == "number" then entry.seats else 1
	local kindText = if entry.size == "Solo" or seats <= 1
		then localized("saveRowSolo")
		elseif member then localizedFormat("saveRowCoopMember", seats)
		else localizedFormat("saveRowCoopOwner", seats)
	local kind = textLabel(row, "SaveKind", kindText, SAVE_ROW.textSize)
	kind.Position = UDim2.fromOffset(0, SAVE_ROW.nameHeight)
	kind.Size = UDim2.new(1, 0, 0, SAVE_ROW.kindHeight)
	kind.TextWrapped = true
	kind.TextTruncate = Enum.TextTruncate.AtEnd

	local function rowButton(name: string, text: string, color: Color3, column: number): TextButton
		local value = textButton(row, name, text, color)
		value.AnchorPoint = Vector2.new(0, 1)
		value.Position = UDim2.fromScale(column * 0.35, 1)
		value.Size = UDim2.new(0.3, 0, 0, BUTTON_HEIGHT)
		return value
	end

	local elsewhere = entry.elsewhere == true
	local playButton = rowButton("Play", localized(if elsewhere then "saveJoinServer" else "savePlay"), GOLD, 0)
	playButton.Activated:Connect(function()
		if elsewhere then
			teleportTo({ saveId = entry.saveId })
		else
			play(entry)
		end
	end)

	if member then
		-- Members cannot rename; they leave instead of deleting (two taps).
		local armed = leaveArmedSaveId == entry.saveId
		local leaveButton = rowButton("Leave", localized(if armed then "teamLeaveConfirm" else "saveLeave"), SAND, 2)
		leaveButton.Activated:Connect(function()
			if leaveArmedSaveId ~= entry.saveId then
				leaveArmedSaveId = entry.saveId
				redrawRows()
				return
			end
			leaveArmedSaveId = nil
			leaveTeam(entry)
		end)
		row.Parent = list
		return
	end

	local renameButton = rowButton("Rename", localized(if renaming then "saveRenameConfirm" else "saveRename"), SAND, 1)
	local deleteButton = rowButton("Delete", localized(if renaming then "saveCancel" else "saveDelete"), SAND, 2)

	renameButton.Activated:Connect(function()
		if renaming and nameBox then
			rename(entry, nameBox)
		else
			renamingSaveId = entry.saveId
			redrawRows()
		end
	end)
	deleteButton.Activated:Connect(function()
		if renaming then
			renamingSaveId = nil
			redrawRows()
		else
			openDeleteConfirm(entry)
		end
	end)
	row.Parent = list
end

local lastSaves: { any } = {}

local function renderRows(saves: { any })
	lastSaves = saves
	for _, child in list:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 8) == "SaveRow_" then
			child:Destroy()
		end
	end
	empty.Visible = #saves == 0
	for index, entry in ipairs(saves) do
		buildRow(index, entry)
	end
end

-- Entering or leaving rename mode redraws the last list without asking the server.
redrawRows = function()
	renderRows(lastSaves)
end

refreshList = function()
	local response = request("Save.List", {})
	if response == nil then
		renderRows(lastSaves)
		return
	end
	if not response.ok or type(response.data) ~= "table" then
		showError(response.errorCode)
		renderRows(lastSaves)
		return
	end
	renderRows(if type(response.data.saves) == "table" then response.data.saves else {})
end

-- Open and close ----------------------------------------------------------------------------

local function updateBackButton()
	backToGame.Visible = player:GetAttribute("CompanyReady") == true
end

local function open()
	UiKit.closeModals()
	UiKit.setBaseLayer(close)
	picker.Visible = true
	savesButton.Visible = false
	updateBackButton()
	refreshList()
end

close = function()
	UiKit.setBaseLayer(nil)
	picker.Visible = false
	-- A closed picker keeps no message (CM2-UVF4 UVF4-D1).
	status.Text = ""
	closeDeleteConfirm()
	renamingSaveId = nil
	leaveArmedSaveId = nil
	savesButton.Visible = true
end

createSave.Activated:Connect(function()
	local response = request("Save.Create", { name = newName.Text, size = selectedSize })
	if response == nil then
		return
	end
	if not response.ok then
		showError(response.errorCode)
		return
	end
	newName.Text = ""
	status.Text = ""
	selectedSize = "Solo"
	updateSizeButtons()
	refreshList()
end)

-- Joins by code, then plays the joined save at once.
joinSave.Activated:Connect(function()
	local code = string.gsub(joinCode.Text, "%s", "")
	local response = request("Save.Join", { code = code })
	if response == nil then
		return
	end
	if not response.ok and response.errorCode == "SaveInUseElsewhere" then
		-- CM2-S3: the tap already says "join", so go to that server at once.
		teleportTo({ code = code })
		return
	end
	if not response.ok or type(response.data) ~= "table" then
		showError(response.errorCode)
		return
	end
	joinCode.Text = ""
	status.Text = ""
	play({ saveId = response.data.saveId })
	refreshList()
end)

confirmDelete.Activated:Connect(function()
	local target = deleteTarget
	if target == nil or not SaveProfile.confirmMatches(target.name, confirmName.Text) then
		return
	end
	local response = request("Save.Delete", { saveId = target.saveId, confirmName = confirmName.Text })
	if response == nil then
		return
	end
	closeDeleteConfirm()
	if not response.ok then
		showError(response.errorCode)
	else
		status.Text = ""
	end
	refreshList()
end)

confirmCancel.Activated:Connect(closeDeleteConfirm)
backToGame.Activated:Connect(close)
savesButton.Activated:Connect(open)

-- Opens the teammate finder; nothing happens while it is not built yet.
findTeammates.Activated:Connect(function()
	local finderGui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("FinderUI")
	local openEvent = finderGui and finderGui:FindFirstChild("Open")
	if openEvent and openEvent:IsA("BindableEvent") then
		openEvent:Fire()
	end
end)

-- CM2-S3: a failed move to another server (ServerFull, SaveServerGone, TeleportFailed).
player:GetAttributeChangedSignal("SaveTeleportError"):Connect(function()
	local code = player:GetAttribute("SaveTeleportError")
	if code == nil then
		return
	end
	if not picker.Visible then
		open()
	end
	showError(code)
end)

player:GetAttributeChangedSignal("CompanyReady"):Connect(function()
	updateBackButton()
	if player:GetAttribute("CompanyReady") == true and picker.Visible then
		close()
	end
end)

player:GetAttributeChangedSignal("ActiveSaveId"):Connect(function()
	if player:GetAttribute("ActiveSaveId") == nil and not picker.Visible then
		open()
	end
end)

player:GetAttributeChangedSignal("CompanyError"):Connect(function()
	local code = player:GetAttribute("CompanyError")
	if code == nil then
		return
	end
	if not picker.Visible then
		open()
	end
	showError(code)
end)

-- The profile becomes readable a moment after joining; refresh an open picker then.
player:GetAttributeChangedSignal("ProfileReady"):Connect(function()
	if picker.Visible and player:GetAttribute("ProfileReady") == true then
		refreshList()
	end
end)

if player:GetAttribute("ActiveSaveId") == nil or player:GetAttribute("CompanyError") ~= nil then
	open()
	local code = player:GetAttribute("CompanyError")
	if code ~= nil then
		showError(code)
	end
else
	savesButton.Visible = true
end
