--!strict
-- Team panel (CM2-S2): who shares the active save, its seats and invite code. The owner
-- resizes the save, makes a new code and removes members; a member can leave. Mobile first;
-- every button is at least 44 px tall. The UI only sends Save.* requests; the server checks
-- every permission and owns every result.
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
local MEMBER_ROW_HEIGHT = 56
local SIZES = { "Solo", "Duo", "Trio", "Quad" }
local CREAM = UiKit.Colors.Cream
local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand
local RED = UiKit.Colors.Red

local textLabel = UiKit.label
local textButton = UiKit.button

-- Layout ------------------------------------------------------------------------------------

local gui = UiKit.screenGui("TeamUI", 15)

-- The Team button lives in the left rail (slot 60).
local teamButton = UiKit.addRailButton("TeamButton", "teamButton", 60)

-- The size and position of the panel come from UiKit.bindDialog.
local panel = Instance.new("Frame")
panel.Name = "TeamPanel"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui
UiKit.window(panel)
UiKit.padding(panel, 12)

local title = textLabel(panel, "Title", localized("teamTitle"), 22)
title.Size = UDim2.new(1, 0, 0, 30)

local seatsLine = textLabel(panel, "SeatsLine", "", 15)
seatsLine.Position = UDim2.fromOffset(0, 34)
seatsLine.Size = UDim2.new(1, 0, 0, 22)

local codeLine = textLabel(panel, "CodeLine", "", 18)
codeLine.Position = UDim2.fromOffset(0, 58)
codeLine.Size = UDim2.new(1, 0, 0, 38)
codeLine.TextWrapped = true
-- The invite code is never auto-translated.
codeLine.AutoLocalize = false

local codeHint = textLabel(panel, "CodeHint", localized("teamCodeHint"), 13)
codeHint.Position = UDim2.fromOffset(0, 98)
codeHint.Size = UDim2.new(1, 0, 0, 20)
codeHint.TextWrapped = true

-- Footer, bottom up: New code / Leave save with Close, then the owner's sizes (96 px, see
-- UiTheme.Dialogs.Team). The status line is the first entry of the member list. The Footer
-- frame and the list are placed by UiKit.bindDialog.
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.BorderSizePixel = 0
footer.Parent = panel

local memberList = Instance.new("ScrollingFrame")
memberList.Name = "MemberList"
memberList.BackgroundTransparency = 1
memberList.BorderSizePixel = 0
memberList.CanvasSize = UDim2.new()
memberList.AutomaticCanvasSize = Enum.AutomaticSize.Y
memberList.ScrollingDirection = Enum.ScrollingDirection.Y
memberList.ScrollBarThickness = 6
memberList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = memberList

local status = UiKit.listStatus(memberList, "TeamStatus")

local sizeButtons: { [string]: TextButton } = {}
for index, size in ipairs(SIZES) do
	local button = textButton(footer, "Size_" .. size, localized("saveSize" .. size), SAND)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.new((index - 1) * 0.25, (index - 1) * 2, 1, -(BUTTON_HEIGHT + 8))
	button.Size = UDim2.new(0.25, -6, 0, BUTTON_HEIGHT)
	button.Visible = false
	sizeButtons[size] = button
end

local newCode = textButton(footer, "NewCode", localized("teamNewCode"), GOLD)
newCode.AnchorPoint = Vector2.new(0, 1)
newCode.Position = UDim2.fromScale(0, 1)
newCode.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)
newCode.Visible = false

local leaveTeam = textButton(footer, "LeaveTeam", localized("teamLeave"), RED)
leaveTeam.TextColor3 = CREAM
leaveTeam.AnchorPoint = Vector2.new(0, 1)
leaveTeam.Position = UDim2.fromScale(0, 1)
leaveTeam.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)
leaveTeam.Visible = false

local closeButton = textButton(footer, "Close", localized("teamClose"), SAND)
closeButton.AnchorPoint = Vector2.new(1, 1)
closeButton.Position = UDim2.fromScale(1, 1)
closeButton.Size = UDim2.new(0.5, -4, 0, BUTTON_HEIGHT)

UiKit.bindDialog(gui, { frame = panel, list = memberList, footer = footer }, UiTheme.Dialogs.Team)

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
	local response = UiKit.request(saveAction, action, payload)
	inFlight = false
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
	UiKit.card(row)
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
		UiKit.onActivated(remove, function()
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
	-- Solo saves have no invite code, so the owner gets no New code button (CM2-UVF6).
	newCode.Visible = owner and not solo
	leaveTeam.Visible = not owner
	leaveTeam.Text = localized(if leaveArmed then "teamLeaveConfirm" else "teamLeave")
end

-- Open and close ----------------------------------------------------------------------------

local close: () -> ()

local function open()
	UiKit.claimModal("Team", close)
	panel.Visible = true
	status.Text = ""
	removeArmed = nil
	leaveArmed = false
	fetchTeam()
end

close = function()
	UiKit.releaseModal("Team")
	panel.Visible = false
	removeArmed = nil
	leaveArmed = false
	refetchPending = false
end

for size, button in pairs(sizeButtons) do
	UiKit.onActivated(button, function()
		act("Save.SetSize", { size = size })
	end)
end

UiKit.onActivated(newCode, function()
	act("Save.RegenerateCode", {})
end)

UiKit.onActivated(leaveTeam, function()
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

UiKit.onActivated(closeButton, close)
UiKit.onActivated(teamButton, function()
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
