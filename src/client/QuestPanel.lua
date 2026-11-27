--!strict
-- Daily rewards and quests panel (CM2-G11, docs/archive/plans/CM2-G11.md): the 7-day streak with its
-- claim button and the group line from the Daily* player attributes, and the save's quest
-- board from the company summary (`summary.quests`). It only sends Daily.Claim and
-- Quest.Claim through the validated BusinessAction remote; the server owns every reward.
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local LotManager = require(script.Parent:WaitForChild("LotManager") :: ModuleScript)

local QuestPanel = {}

export type Panel = { render: (summary: any?) -> () }

local MODAL_ID = "Quests"
local BUTTON_HEIGHT = UiTheme.MinTouch
local ROW_HEIGHT = 72
local CLAIM_WIDTH = 120
local SLOT_COUNT = 4
local DAY_COUNT = #GameConfig.DailyRewards.Days

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat
local textLabel = UiKit.label
local textButton = UiKit.button
local corner = UiKit.corner

local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local GOLD_TEXT = UiKit.Colors.GoldText
local PRIMARY = UiKit.Colors.Primary
local RED = UiKit.Colors.Red
local SAND = UiKit.Colors.Sand
local DARK = UiKit.Colors.DarkText

local ERROR_KEYS: { [string]: string } = {
	AlreadyClaimed = "rewardErrorClaimed",
	Incomplete = "questErrorIncomplete",
	BonusLocked = "questErrorLocked",
	QuestsRotated = "questErrorRotated",
	RateLimited = "shopErrorBusy",
	ClaimBusy = "shopErrorBusy",
}

local function errorText(code: unknown): string
	local key = if type(code) == "string" then ERROR_KEYS[code] else nil
	return localized(key or "rewardErrorFailed")
end

local function formatTime(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return localizedFormat("questsTime", whole // 3600, (whole % 3600) // 60)
end

local function setButton(button: TextButton, text: string, active: boolean)
	button.Text = text
	button.BackgroundColor3 = if active then GOLD else SAND
	button.Active = active
end

local function questText(row: any): string
	if row.kind == "SalesCash" then
		return localizedFormat(row.textKey, UiTheme.formatMoney(row.target))
	end
	return localizedFormat(row.textKey, row.target)
end

local function progressText(row: any): string
	if row.kind == "SalesCash" then
		return localizedFormat("questProgress", UiTheme.formatMoney(row.progress), UiTheme.formatMoney(row.target))
	end
	return localizedFormat("questProgress", tostring(row.progress), tostring(row.target))
end

local function rewardText(row: any): string
	if type(row.rewardReputation) == "number" and row.rewardReputation > 0 then
		return localizedFormat("questRewardBoth", UiTheme.formatMoney(row.rewardCash), row.rewardReputation)
	end
	return localizedFormat("questRewardCash", UiTheme.formatMoney(row.rewardCash))
end

local function listFrame(parent: Instance, name: string, order: number, height: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.Parent = parent
	return frame
end

function QuestPanel.new(context: LotManager.TabContext): Panel
	-- Layout --------------------------------------------------------------------------------

	local gui = UiKit.screenGui("QuestUI", 15)
	local railButton = UiKit.addRailButton("QuestsButton", "questsButton", 30)

	local panel = Instance.new("Frame")
	panel.Name = "QuestPanel"
	panel.BackgroundColor3 = PANEL
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	UiKit.window(panel)
	UiKit.padding(panel, 12)

	local title = textLabel(panel, "Title", localized("questsTitle"), 22)
	UiKit.headerBand(title)
	title.Size = UDim2.new(1, 0, 0, 30)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 6
	list.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.BorderSizePixel = 0
	footer.Parent = panel

	local status = textLabel(footer, "Status", "", UiTheme.TextSize.Small)
	status.Size = UDim2.new(1, -(CLAIM_WIDTH + 8), 1, 0)
	status.TextWrapped = true

	local closeButton = textButton(footer, "CloseButton", localized("questsClose"), RED)
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.fromScale(1, 1)
	closeButton.Size = UDim2.fromOffset(CLAIM_WIDTH, BUTTON_HEIGHT)

	UiKit.bindDialog(gui, { frame = panel, list = list, footer = footer, rightHeader = title }, UiTheme.Dialogs.Quests)

	-- Daily reward section.
	local dailyHeader = textLabel(list, "DailyHeader", localized("dailyHeader"), UiTheme.TextSize.Body)
	dailyHeader.LayoutOrder = 1
	dailyHeader.Size = UDim2.new(1, -8, 0, 22)

	local strip = listFrame(list, "DailyStrip", 2, 56)
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.Padding = UDim.new(0, 4)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip
	local dayLabels: { TextLabel } = {}
	for index = 1, DAY_COUNT do
		local day = GameConfig.DailyRewards.Days[index]
		local dayText = if day.cash > 0
			then localizedFormat("dailyCardCash", index, UiTheme.formatMoney(day.cash))
			else localizedFormat("dailyCardReputation", index, day.reputation)
		local label = textLabel(strip, "Day_" .. index, dayText, UiTheme.TextSize.Small)
		label.LayoutOrder = index
		label.Size = UDim2.new(1 / DAY_COUNT, -4, 1, 0)
		label.BackgroundTransparency = 0
		label.BackgroundColor3 = ROW
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextWrapped = true
		label.TextTruncate = Enum.TextTruncate.None
		corner(label, UiTheme.CornerRadius.Button)
		dayLabels[index] = label
	end

	local dailyButton = textButton(list, "DailyClaimButton", "", SAND)
	dailyButton.LayoutOrder = 3
	dailyButton.Size = UDim2.new(1, -8, 0, BUTTON_HEIGHT)

	local groupLine = listFrame(list, "GroupLine", 4, BUTTON_HEIGHT)
	groupLine.Visible = false
	local groupText = textLabel(groupLine, "Text", "", UiTheme.TextSize.Small)
	groupText.TextWrapped = true
	groupText.TextTruncate = Enum.TextTruncate.None
	local groupJoinButton = textButton(groupLine, "GroupJoinButton", localized("dailyGroupJoinButton"), PRIMARY)
	groupJoinButton.AnchorPoint = Vector2.new(1, 0.5)
	groupJoinButton.Position = UDim2.fromScale(1, 0.5)
	groupJoinButton.Size = UDim2.fromOffset(CLAIM_WIDTH, BUTTON_HEIGHT)

	-- Quest board section.
	local questsHeader = listFrame(list, "QuestsHeader", 5, 22)
	local questsLabel = textLabel(questsHeader, "Title", localized("questsButton"), UiTheme.TextSize.Body)
	questsLabel.Size = UDim2.fromScale(0.5, 1)
	local questsTimer = textLabel(questsHeader, "QuestsTimer", "", UiTheme.TextSize.Small)
	questsTimer.Position = UDim2.fromScale(0.5, 0)
	questsTimer.Size = UDim2.fromScale(0.5, 1)
	questsTimer.TextXAlignment = Enum.TextXAlignment.Right

	type QuestRow = {
		frame: Frame,
		text: TextLabel,
		progress: TextLabel,
		reward: TextLabel,
		bonus: TextLabel?,
		claim: TextButton,
	}
	local questRows: { QuestRow } = {}
	for slot = 1, SLOT_COUNT do
		local frame = Instance.new("Frame")
		frame.Name = "Quest_" .. slot
		frame.LayoutOrder = 5 + slot
		frame.BackgroundColor3 = ROW
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		frame.Parent = list
		UiKit.card(frame)
		local rowPadding = Instance.new("UIPadding")
		rowPadding.PaddingTop = UDim.new(0, 6)
		rowPadding.PaddingBottom = UDim.new(0, 6)
		rowPadding.PaddingLeft = UDim.new(0, 8)
		rowPadding.PaddingRight = UDim.new(0, 8)
		rowPadding.Parent = frame

		local text = textLabel(frame, "Text", localized("loading"), UiTheme.TextSize.Body)
		text.Size = UDim2.new(1, -(CLAIM_WIDTH + 8), 0, 20)
		local progress = textLabel(frame, "Progress", "", UiTheme.TextSize.Small)
		progress.Position = UDim2.fromOffset(0, 22)
		progress.Size = UDim2.new(0.4, 0, 0, 18)
		local reward = textLabel(frame, "Reward", "", UiTheme.TextSize.Small)
		reward.Position = UDim2.fromOffset(0, 42)
		reward.Size = UDim2.new(1, -(CLAIM_WIDTH + 8), 0, 18)
		local bonus: TextLabel? = nil
		if slot == SLOT_COUNT then
			local label = textLabel(frame, "Bonus", localized("questErrorLocked"), UiTheme.TextSize.Small)
			label.Position = UDim2.new(0.4, 0, 0, 22)
			label.Size = UDim2.new(0.6, -(CLAIM_WIDTH + 8), 0, 18)
			label.TextColor3 = GOLD_TEXT
			label.Visible = false
			bonus = label
		end
		local claim = textButton(frame, "ClaimButton", localized("questClaim"), SAND)
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Position = UDim2.fromScale(1, 0.5)
		claim.Size = UDim2.fromOffset(CLAIM_WIDTH, BUTTON_HEIGHT)
		setButton(claim, localized("questClaim"), false)
		questRows[slot] = {
			frame = frame,
			text = text,
			progress = progress,
			reward = reward,
			bonus = bonus,
			claim = claim,
		}
	end

	-- State ---------------------------------------------------------------------------------

	local board: any = nil
	local boardAt = os.clock()
	local dailyAt = os.clock()
	local inFlight = false
	local openToken = 0
	local autoOpened = false

	local function dailyClaimable(): boolean
		return player:GetAttribute("DailyClaimable") == true
	end

	local function dailyNext(): number
		local value = player:GetAttribute("DailyNext")
		return if type(value) == "number" and value >= 1 and value <= DAY_COUNT then math.floor(value) else 1
	end

	local function dailySecondsLeft(): number
		local value = player:GetAttribute("DailySecondsLeft")
		local seconds = if type(value) == "number" then value else 0
		return seconds - (os.clock() - dailyAt)
	end

	local function updateTimers()
		if board ~= nil and type(board.endsIn) == "number" then
			questsTimer.Text = localizedFormat("questsNewIn", formatTime(board.endsIn - (os.clock() - boardAt)))
		else
			questsTimer.Text = ""
		end
		if not dailyClaimable() then
			dailyButton.Text = localizedFormat("dailyComeBack", formatTime(dailySecondsLeft()))
		end
	end

	local function updateBadge()
		local count = if board ~= nil and type(board.claimable) == "number" then board.claimable else 0
		if dailyClaimable() then
			count += 1
		end
		railButton.Text = if count > 0 then localizedFormat("questsButtonCount", count) else localized("questsButton")
	end

	local function updateDaily()
		local claimable = dailyClaimable()
		local nextDay = dailyNext()
		for index, label in ipairs(dayLabels) do
			local color = if index == nextDay and claimable then GOLD elseif index < nextDay then SAND else ROW
			label.BackgroundColor3 = color
			label.TextColor3 = DARK
		end
		if claimable then
			setButton(dailyButton, localizedFormat("dailyClaim", nextDay), not inFlight)
		else
			setButton(dailyButton, localizedFormat("dailyComeBack", formatTime(dailySecondsLeft())), false)
		end
		local groupState = player:GetAttribute("DailyGroup")
		groupLine.Visible = groupState == "Join" or groupState == "Active"
		groupJoinButton.Visible = groupState == "Join"
		groupText.Size = if groupState == "Join" then UDim2.new(1, -(CLAIM_WIDTH + 8), 1, 0) else UDim2.fromScale(1, 1)
		groupText.Text = if groupState == "Join"
			then localized("dailyGroupJoin")
			elseif groupState == "Active" then localized("dailyGroupActive")
			else ""
		updateBadge()
	end

	local function rowClaimable(row: any): boolean
		return row.complete == true and row.claimed ~= true and row.locked ~= true
	end

	local function renderBoard()
		local rows = if board ~= nil and type(board.quests) == "table" then board.quests else nil
		for slot, view in ipairs(questRows) do
			local row = if rows ~= nil then rows[slot] else nil
			if type(row) ~= "table" then
				view.text.Text = localized("loading")
				view.progress.Text = ""
				view.reward.Text = ""
				if view.bonus then
					view.bonus.Visible = false
				end
				setButton(view.claim, localized("questClaim"), false)
			else
				view.text.Text = questText(row)
				view.progress.Text = progressText(row)
				view.reward.Text = rewardText(row)
				if view.bonus then
					view.bonus.Visible = row.locked == true
				end
				if row.claimed == true then
					setButton(view.claim, localized("questDone"), false)
				elseif row.locked == true then
					setButton(view.claim, localized("questLocked"), false)
				else
					setButton(view.claim, localized("questClaim"), rowClaimable(row) and not inFlight)
				end
			end
		end
		updateTimers()
		updateBadge()
	end

	-- Claims --------------------------------------------------------------------------------

	local function finishClaim(text: string)
		inFlight = false
		status.Text = text
		renderBoard()
		updateDaily()
		context.refresh()
	end

	local function claimQuest(slot: number)
		local rows = if board ~= nil and type(board.quests) == "table" then board.quests else nil
		local row = if rows ~= nil then rows[slot] else nil
		if inFlight or type(row) ~= "table" or not rowClaimable(row) then
			return
		end
		inFlight = true
		renderBoard()
		updateDaily()
		local response = context.request("Quest.Claim", { slot = slot, period = board.period })
		if response.ok and type(response.data) == "table" then
			finishClaim(localizedFormat("questComplete", UiTheme.formatMoney(response.data.cash)))
		else
			finishClaim(errorText(response.errorCode))
		end
	end

	local function claimDaily()
		if inFlight or not dailyClaimable() then
			return
		end
		inFlight = true
		renderBoard()
		updateDaily()
		local response = context.request("Daily.Claim", {})
		if response.ok and type(response.data) == "table" then
			local data = response.data
			if type(data.cash) == "number" and data.cash > 0 then
				finishClaim(localizedFormat("dailyClaimedCash", UiTheme.formatMoney(data.cash)))
			else
				finishClaim(localizedFormat("dailyClaimedReputation", data.reputation))
			end
		else
			finishClaim(errorText(response.errorCode))
		end
	end

	for slot, view in ipairs(questRows) do
		UiKit.onActivated(view.claim, function()
			claimQuest(slot)
		end)
	end
	UiKit.onActivated(dailyButton, claimDaily)

	UiKit.onActivated(groupJoinButton, function()
		local ok, result = pcall(GroupService.PromptJoinAsync, GroupService, GameConfig.DailyRewards.GroupId)
		if ok and result == Enum.GroupMembershipStatus.Joined then
			status.Text = localized("dailyGroupJoined")
		end
	end)

	-- Open and close ------------------------------------------------------------------------

	local close: () -> ()

	local function startCountdown(token: number)
		task.spawn(function()
			while panel.Visible and openToken == token do
				task.wait(1)
				if panel.Visible and openToken == token then
					updateTimers()
				end
			end
		end)
	end

	local function open()
		UiKit.claimModal(MODAL_ID, close)
		openToken += 1
		panel.Visible = true
		status.Text = ""
		renderBoard()
		updateDaily()
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

	-- Opens once per client session when the day's reward waits and nothing else is open.
	local function checkAutoOpen()
		if autoOpened or panel.Visible then
			return
		end
		local step = player:GetAttribute("TutorialStep")
		local autoOpenState = "Opened"
		if player:GetAttribute("CompanyReady") ~= true then
			autoOpenState = "NotReady"
		elseif not dailyClaimable() then
			autoOpenState = "NotClaimable"
		elseif step ~= "Done" and step ~= "Skipped" then
			autoOpenState = "Tutorial"
		elseif UiKit.heldModal() ~= nil then
			autoOpenState = "Modal"
		elseif UiKit.baseLayerOpen() then
			autoOpenState = "BaseLayer"
		end
		gui:SetAttribute("AutoOpenState", autoOpenState)
		if autoOpenState == "Opened" then
			autoOpened = true
			open()
		end
	end

	local function updateReady()
		local ready = player:GetAttribute("CompanyReady") == true
		railButton.Visible = ready
		if not ready and panel.Visible then
			close()
		end
	end

	player:GetAttributeChangedSignal("CompanyReady"):Connect(function()
		updateReady()
		task.defer(checkAutoOpen)
	end)
	player:GetAttributeChangedSignal("DailyClaimable"):Connect(function()
		updateDaily()
		task.defer(checkAutoOpen)
	end)
	player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
		task.defer(checkAutoOpen)
	end)
	-- A modal or base layer held at an attribute change is re-checked once it closes.
	UiKit.onModalsChanged(function()
		task.defer(checkAutoOpen)
	end)
	player:GetAttributeChangedSignal("DailySecondsLeft"):Connect(function()
		dailyAt = os.clock()
		updateDaily()
	end)
	for _, attribute in { "DailyNext", "DailyGroup" } do
		player:GetAttributeChangedSignal(attribute):Connect(updateDaily)
	end
	updateReady()
	updateDaily()
	renderBoard()
	task.defer(checkAutoOpen)

	local function render(summary: any?)
		if type(summary) == "table" and type(summary.quests) == "table" then
			board = summary.quests
			boardAt = os.clock()
		else
			board = nil
		end
		renderBoard()
	end

	return { render = render }
end

return QuestPanel
