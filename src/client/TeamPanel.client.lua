--!strict
-- Team panel (CM2-S2): who shares the active save, its seats and invite code. The owner
-- resizes the save, makes a new code and removes members; a member can leave. Mobile first;
-- every button is at least 44 px tall. The UI only sends Save.* requests; the server checks
-- every permission and owns every result.
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
local MEMBER_ROW_HEIGHT = 56
local STATUS_HEIGHT = 36
local SIZES = { "Solo", "Duo", "Trio", "Quad" }
local CREAM = Color3.fromRGB(255, 244, 217)
local DARK_TEXT = Color3.fromRGB(30, 48, 35)
local PANEL = Color3.fromRGB(20, 68, 48)
local ROW = Color3.fromRGB(38, 89, 63)
local GOLD = Color3.fromRGB(201, 153, 53)
local SAND = Color3.fromRGB(237, 212, 142)
local RED = Color3.fromRGB(196, 58, 52)

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

local gui = Instance.new("ScreenGui")
gui.Name = "TeamUI"
gui.DisplayOrder = 15
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local teamButton = textButton(gui, "TeamButton", localized("teamButton"), SAND)
teamButton.AnchorPoint = Vector2.new(1, 0)
teamButton.Position = UDim2.new(1, -120, 0, 12)
teamButton.Size = UDim2.fromOffset(96, BUTTON_HEIGHT)
teamButton.Visible = false

local panel = Instance.new("Frame")
panel.Name = "TeamPanel"
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

local title = textLabel(panel, "Title", localized("teamTitle"), 22)
title.Size = UDim2.new(1, 0, 0, 30)

local seatsLine = textLabel(panel, "SeatsLine", "", 15)
seatsLine.Position = UDim2.fromOffset(0, 34)
seatsLine.Size = UDim2.new(1, 0, 0, 22)

local codeLine = textLabel(panel, "CodeLine", "", 18)
codeLine.Position = UDim2.fromOffset(0, 58)
codeLine.Size = UDim2.new(1, 0, 0, 26)
-- The invite code is never auto-translated.
codeLine.AutoLocalize = false

local codeHint = textLabel(panel, "CodeHint", localized("teamCodeHint"), 13)
codeHint.Position = UDim2.fromOffset(0, 86)
codeHint.Size = UDim2.new(1, 0, 0, 20)
codeHint.TextWrapped = true

-- Footer, bottom up: status, then New code / Leave save with Close, then the owner's sizes.
local FOOTER_HEIGHT = STATUS_HEIGHT + 8 + BUTTON_HEIGHT + 8 + BUTTON_HEIGHT
local LIST_TOP = 110

local memberList = Instance.new("ScrollingFrame")
memberList.Name = "MemberList"
memberList.BackgroundTransparency = 1
memberList.BorderSizePixel = 0
memberList.Position = UDim2.fromOffset(0, LIST_TOP)
memberList.Size = UDim2.new(1, 0, 1, -(LIST_TOP + FOOTER_HEIGHT + 8))
memberList.CanvasSize = UDim2.new()
memberList.AutomaticCanvasSize = Enum.AutomaticSize.Y
memberList.ScrollingDirection = Enum.ScrollingDirection.Y
memberList.ScrollBarThickness = 6
memberList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = memberList

local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(panel, "Size_" .. size, localized("saveSize" .. size), SAND)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new((index - 1) * 0.25, (index - 1) * 2, 1, -(STATUS_HEIGHT + 8 + BUTTON_HEIGHT + 8))
	button.Size = UDim2.new(0.25, -6, 0, BUTTON_HEIGHT)
	button.Visible = false
	sizeButtons[size] = button
end

local newCode = textButton(panel, "NewCode", localized("teamNewCode"), GOLD)
newCode.AnchorPoint = Vector2.new(0, 1)
newCode.Position = UDim2.new(0, 0, 1, -(STATUS_HEIGHT + 8))
newCode.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)
newCode.Visible = false

local leaveTeam = textButton(panel, "LeaveTeam", localized("teamLeave"), RED)
leaveTeam.TextColor3 = CREAM
leaveTeam.AnchorPoint = Vector2.new(0, 1)
leaveTeam.Position = UDim2.new(0, 0, 1, -(STATUS_HEIGHT + 8))
leaveTeam.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)
leaveTeam.Visible = false

local closeButton = textButton(panel, "Close", localized("teamClose"), SAND)
closeButton.AnchorPoint = Vector2.new(1, 1)
closeButton.Position = UDim2.new(1, 0, 1, -(STATUS_HEIGHT + 8))
closeButton.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)

local status = textLabel(panel, "TeamStatus", "", 13)
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.fromScale(0, 1)
status.Size = UDim2.new(1, 0, 0, STATUS_HEIGHT)
status.TextWrapped = true
status.TextTruncate = Enum.TextTruncate.None

-- Requests ----------------------------------------------------------------------------------

-- One request in flight. A team change announced during a request (TeamRevision) or an own
-- action asks for exactly one fetch after that request returns.
local inFlight = false
local refetchPending = false
local team: any = nil
local removeArmed: number? = nil
local leaveArmed = false

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
local fetchTeam: () -> ()

local function afterRequest()
	if refetchPending and panel.Visible then
		refetchPending = false
		fetchTeam()
	end
end

fetchTeam = function()
	if inFlight then
		refetchPending = true
		return
	end
	local response = send("Save.Team", {})
	if response.ok and type(response.data) == "table" then
		render(response.data)
	else
		showError(response.errorCode)
	end
	afterRequest()
end

local function act(action: string, payload: { [string]: any })
	if inFlight then
		return
	end
	local response = send(action, payload)
	if response.ok then
		status.Text = ""
	else
		showError(response.errorCode)
	end
	refetchPending = true
	afterRequest()
end

-- Rendering ---------------------------------------------------------------------------------

local function clearRows()
	for _, child in memberList:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 7) == "Member_" then
			child:Destroy()
		end
	end
end

local function buildRow(index: number, member, viewerIsOwner: boolean)
	local row = Instance.new("Frame")
	row.Name = "Member_" .. index
	row.LayoutOrder = index
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, MEMBER_ROW_HEIGHT)
	corner(row, 10)
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingTop = UDim.new(0, 4)
	rowPadding.PaddingBottom = UDim.new(0, 4)
	rowPadding.PaddingLeft = UDim.new(0, 8)
	rowPadding.PaddingRight = UDim.new(0, 8)
	rowPadding.Parent = row

	local nameText = if type(member.name) == "string" then member.name else localized("teamUnknownPlayer")
	local nameLabel = textLabel(row, "PlayerName", nameText, 16)
	nameLabel.Size = UDim2.new(0.6, 0, 0, 24)
	-- Usernames are never auto-translated.
	nameLabel.AutoLocalize = false

	local roleTag =
		textLabel(row, "RoleTag", localized(if member.role == "Owner" then "teamOwnerTag" else "teamMemberTag"), 13)
	roleTag.Position = UDim2.fromOffset(0, 26)
	roleTag.Size = UDim2.new(0.3, 0, 0, 20)

	local online = textLabel(row, "OnlineState", localized(if member.online then "teamOnline" else "teamOffline"), 13)
	online.Position = UDim2.new(0.3, 0, 0, 26)
	online.Size = UDim2.new(0.3, 0, 0, 20)

	if viewerIsOwner and member.role ~= "Owner" then
		local armed = removeArmed == member.userId
		local remove = textButton(row, "Remove", localized(if armed then "teamRemoveConfirm" else "teamRemove"), SAND)
		remove.AnchorPoint = Vector2.new(1, 0.5)
		remove.Position = UDim2.fromScale(1, 0.5)
		remove.Size = UDim2.new(0.38, 0, 0, BUTTON_HEIGHT)
		remove.Activated:Connect(function()
			if removeArmed ~= member.userId then
				removeArmed = member.userId
				render(team)
				return
			end
			removeArmed = nil
			act("Save.RemoveMember", { userId = member.userId })
		end)
	end
	row.Parent = memberList
end

render = function(data)
	team = data
	local members = if type(data.members) == "table" then data.members else {}
	local seats = if type(data.seats) == "number" then data.seats else 1
	local solo = data.size == "Solo"
	local owner = data.role == "Owner"
	seatsLine.Text = localizedFormat("teamSeats", #members, seats)
	if solo then
		codeLine.Text = localized("teamNoCode")
	elseif type(data.inviteCode) == "string" then
		codeLine.Text = localizedFormat("teamCode", data.inviteCode)
	else
		codeLine.Text = localized("teamCodePending")
	end
	codeHint.Visible = not solo
	clearRows()
	for index, member in ipairs(members) do
		buildRow(index, member, owner)
	end
	for size, button in pairs(sizeButtons) do
		button.Visible = owner
		button.BackgroundColor3 = if size == data.size then GOLD else SAND
	end
	newCode.Visible = owner
	leaveTeam.Visible = not owner
	leaveTeam.Text = localized(if leaveArmed then "teamLeaveConfirm" else "teamLeave")
end

-- Open and close ----------------------------------------------------------------------------

local function open()
	panel.Visible = true
	status.Text = ""
	removeArmed = nil
	leaveArmed = false
	fetchTeam()
end

local function close()
	panel.Visible = false
	removeArmed = nil
	leaveArmed = false
	refetchPending = false
end

for size, button in pairs(sizeButtons) do
	button.Activated:Connect(function()
		act("Save.SetSize", { size = size })
	end)
end

newCode.Activated:Connect(function()
	act("Save.RegenerateCode", {})
end)

leaveTeam.Activated:Connect(function()
	if team == nil or type(team.saveId) ~= "string" then
		return
	end
	if not leaveArmed then
		leaveArmed = true
		render(team)
		return
	end
	leaveArmed = false
	act("Save.LeaveTeam", { saveId = team.saveId })
end)

closeButton.Activated:Connect(close)
teamButton.Activated:Connect(function()
	if panel.Visible then
		close()
	else
		open()
	end
end)

local function updateReady()
	local ready = player:GetAttribute("CompanyReady") == true
	teamButton.Visible = ready
	if not ready and panel.Visible then
		close()
	end
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
updateReady()

player:GetAttributeChangedSignal("TeamRevision"):Connect(function()
	if panel.Visible then
		fetchTeam()
	end
end)
