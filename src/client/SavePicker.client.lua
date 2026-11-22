--!strict
-- Save picker (CM2-S1): choose, create, rename and delete saves, and switch saves through
-- the "Saves" button. CM2-S2 adds the save size, joining by invite code and shared (Member)
-- rows, which show the owner's username instead of the save name and can only be left.
-- CM2-S3 adds "Being played by X" rows with Join (Save.Teleport), the teleport after a code
-- join of a save played elsewhere and the "Find teammates" button. Mobile first; every
-- button is at least 44 px tall. The UI only sends Save.* requests; the server validates,
-- filters names and owns every result.
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
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
local ROW_HEIGHT = 120
local CREAM = Color3.fromRGB(255, 244, 217)
local DARK_TEXT = Color3.fromRGB(30, 48, 35)
local PANEL = Color3.fromRGB(20, 68, 48)
local ROW = Color3.fromRGB(38, 89, 63)
local GOLD = Color3.fromRGB(201, 153, 53)
local SAND = Color3.fromRGB(237, 212, 142)
local RED = Color3.fromRGB(196, 58, 52)
local DISABLED = Color3.fromRGB(120, 120, 120)

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
	value.Parent = parent
	return value
end

local function textButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.BackgroundColor3 = color
	value.TextColor3 = DARK_TEXT
	value.Font = Enum.Font.GothamBold
	value.TextSize = 16
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	corner(value, 8)
	return value
end

local function textBox(parent: Instance, name: string, placeholder: string): TextBox
	local value = Instance.new("TextBox")
	value.Name = name
	value.BackgroundColor3 = CREAM
	value.TextColor3 = DARK_TEXT
	value.PlaceholderText = placeholder
	value.PlaceholderColor3 = Color3.fromRGB(120, 110, 90)
	value.Font = Enum.Font.Gotham
	value.TextSize = 16
	value.Text = ""
	value.ClearTextOnFocus = false
	value.TextXAlignment = Enum.TextXAlignment.Left
	-- Typed save names are player text, never auto-translated.
	value.AutoLocalize = false
	value.Parent = parent
	corner(value, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = value
	return value
end

-- Layout ------------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "SavePickerUI"
gui.DisplayOrder = 20
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function dialogFrame(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.92, 0.86)
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui
	corner(frame, 14)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(480, 600)
	constraint.Parent = frame
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 12)
	end
	padding.Parent = frame
	return frame
end

local picker = dialogFrame("Picker")
picker.Visible = false

local title = textLabel(picker, "Title", localized("savePickerTitle"), 22)
title.Size = UDim2.new(0.6, -4, 0, 30)

local hint = textLabel(picker, "Hint", localized("savePickerHint"), 14)
hint.Position = UDim2.fromOffset(0, 32)
hint.Size = UDim2.new(0.6, -4, 0, 22)
hint.TextWrapped = true
hint.TextTruncate = Enum.TextTruncate.AtEnd

-- CM2-S3: opens the teammate finder (TeammateFinder.client.lua) above the picker.
local findTeammates = textButton(picker, "FindTeammates", localized("finderOpen"), SAND)
findTeammates.AnchorPoint = Vector2.new(1, 0)
findTeammates.Position = UDim2.fromScale(1, 0)
findTeammates.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

-- Four footer rows: size toggles, new save, join by code, status and back.
local FOOTER_HEIGHT = BUTTON_HEIGHT * 4 + 24
local FOOTER_ROW = BUTTON_HEIGHT + 8
local list = Instance.new("ScrollingFrame")
list.Name = "SaveList"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 60)
list.Size = UDim2.new(1, 0, 1, -(60 + FOOTER_HEIGHT + 8))
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.ScrollBarThickness = 6
list.Parent = picker
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local empty = textLabel(list, "Empty", localized("savePickerEmpty"), 15)
empty.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
empty.TextWrapped = true
empty.Visible = false

-- Footer row 1: the size of the next new save (default Solo).
local SIZES = { "Solo", "Duo", "Trio", "Quad" }
local selectedSize = "Solo"
local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(picker, "Size_" .. size, localized("saveSize" .. size), SAND)
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
local newName = textBox(picker, "NewSaveName", localized("saveNamePlaceholder"))
newName.AnchorPoint = Vector2.new(0, 1)
newName.Position = UDim2.new(0, 0, 1, -(FOOTER_ROW * 2))
newName.Size = UDim2.new(0.6, -4, 0, BUTTON_HEIGHT)

local createSave = textButton(picker, "CreateSave", localized("saveNew"), GOLD)
createSave.AnchorPoint = Vector2.new(1, 1)
createSave.Position = UDim2.new(1, 0, 1, -(FOOTER_ROW * 2))
createSave.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

-- Footer row 3: join a friend's save by invite code.
local joinCode = textBox(picker, "JoinCode", localized("joinCodePlaceholder"))
joinCode.AnchorPoint = Vector2.new(0, 1)
joinCode.Position = UDim2.new(0, 0, 1, -FOOTER_ROW)
joinCode.Size = UDim2.new(0.6, -4, 0, BUTTON_HEIGHT)

local joinSave = textButton(picker, "JoinSave", localized("joinButton"), GOLD)
joinSave.AnchorPoint = Vector2.new(1, 1)
joinSave.Position = UDim2.new(1, 0, 1, -FOOTER_ROW)
joinSave.Size = UDim2.new(0.4, -4, 0, BUTTON_HEIGHT)

local status = textLabel(picker, "PickerStatus", "", 14)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.fromScale(0, 1)
status.Size = UDim2.new(0.6, -4, 0, BUTTON_HEIGHT)
status.TextWrapped = true

local backToGame = textButton(picker, "BackToGame", localized("saveBack"), SAND)
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

-- "Saves" button, top right, while the picker is closed.
local savesButton = textButton(gui, "SavesButton", localized("savesButton"), SAND)
savesButton.AnchorPoint = Vector2.new(1, 0)
savesButton.Position = UDim2.new(1, -12, 0, 12)
savesButton.Size = UDim2.fromOffset(96, BUTTON_HEIGHT)
savesButton.Visible = false

-- Requests ----------------------------------------------------------------------------------

-- Only one request is in flight at a time; a tap during one is ignored.
local inFlight = false
local function request(action: string, payload: { [string]: any }): any
	if inFlight then
		return nil
	end
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
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
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
		local nameLabel = textLabel(row, "SaveName", shownName, 18)
		nameLabel.Size = UDim2.new(0.6, 0, 0, 34)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		-- Player-chosen names are never auto-translated.
		nameLabel.AutoLocalize = false
		local subKey = if entry.active then "saveRowActive" elseif entry.lastPlayed then "saveRowLastPlayed" else nil
		local sub = textLabel(row, "SaveState", if subKey then localized(subKey) else "", 13)
		sub.AnchorPoint = Vector2.new(1, 0)
		sub.Position = UDim2.fromScale(1, 0)
		sub.Size = UDim2.new(0.4, -4, 0, 34)
		sub.TextXAlignment = Enum.TextXAlignment.Right
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
	local kind = textLabel(row, "SaveKind", kindText, 13)
	kind.Position = UDim2.fromOffset(0, 34)
	kind.Size = UDim2.new(1, 0, 0, 22)
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
	picker.Visible = true
	savesButton.Visible = false
	updateBackButton()
	refreshList()
end

close = function()
	picker.Visible = false
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
		status.Text = ""
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
