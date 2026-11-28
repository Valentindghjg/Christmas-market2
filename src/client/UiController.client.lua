--!strict
-- HUD shell (CM2-40): cash, reputation, day and lot status chips with the save status line, the
-- rail button and key M for the Lot Manager, and the summary poll. It only sends validated
-- requests and renders responses; the Supplier tab lives in LotManagerTabs/SupplierTab.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction") :: RemoteFunction
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local LotManager = require(script.Parent:WaitForChild("LotManager") :: ModuleScript)
local QuestPanel = require(script.Parent:WaitForChild("QuestPanel") :: ModuleScript)
local AdventPanel = require(script.Parent:WaitForChild("AdventPanel") :: ModuleScript)
local EventShopPanel = require(script.Parent:WaitForChild("EventShopPanel") :: ModuleScript)

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat

local gui = UiKit.screenGui("ChristmasMarketUI", 10)

local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.BackgroundTransparency = 1
hud.BorderSizePixel = 0
hud.Parent = gui

-- Chip text is the player's own numbers or a status word; cash and reputation are never
-- auto-translated.
local function chip(name: string, text: string, playerText: boolean): TextLabel
	local value = UiKit.label(hud, name, text, UiTheme.TextSize.Chip, playerText)
	value.BackgroundColor3 = UiKit.Colors.Panel
	value.BackgroundTransparency = 0.1
	value.TextXAlignment = Enum.TextXAlignment.Center
	UiKit.card(value)
	return value
end
-- CashLabel is named so playtests can compare the HUD cash with the server cash (CM2-S2).
local cashLabel = chip("CashLabel", localized("loading"), true)
local reputationLabel = chip("ReputationLabel", localized("loading"), true)
local dayLabel = chip("DayLabel", localized("hudDayUnknown"), false)
local lotStatusLabel = chip("LotStatusLabel", localized("hudLotClosed"), false)
local chipLabels: { [string]: TextLabel } = {
	Cash = cashLabel,
	Reputation = reputationLabel,
	Day = dayLabel,
	Lot = lotStatusLabel,
}

local status = UiKit.label(hud, "SaveStatus", "Christmas Market 2", UiTheme.TextSize.Small)
status.TextXAlignment = Enum.TextXAlignment.Center
status.TextWrapped = true
status.TextScaled = true
status.TextColor3 = UiKit.Colors.DarkText
-- CM2-UIFIX: a Panel plate under the chips, so the line reads on any background.
status.BackgroundColor3 = UiKit.Colors.Panel
status.BackgroundTransparency = 0.1
UiKit.card(status)
local STATUS_MAX_TEXT = UiTheme.TextSize.Small
local STATUS_MIN_TEXT = 10
local statusSize = Instance.new("UITextSizeConstraint")
statusSize.Name = "StatusSize"
statusSize.MaxTextSize = STATUS_MAX_TEXT
statusSize.MinTextSize = STATUS_MIN_TEXT
statusSize.Parent = status
local statusInset = Instance.new("UIPadding")
statusInset.Name = "StatusInset"
statusInset.PaddingLeft = UDim.new(0, 8)
statusInset.PaddingRight = UDim.new(0, 8)
statusInset.PaddingTop = UDim.new(0, 2)
statusInset.PaddingBottom = UDim.new(0, 2)
statusInset.Parent = status

local lotManagerButton = UiKit.addRailButton("LotManagerButton", "lotManagerButton", 10)

local lastSummary: any = nil
local managerOpen = false
local currentMetrics = UiTheme.metrics(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
local refreshSummary: () -> ()

local context: LotManager.TabContext = {
	request = function(action: string, payload: { [string]: any }): any
		return UiKit.request(remote, action, payload)
	end,
	refresh = function()
		refreshSummary()
	end,
	summary = function(): any?
		return lastSummary
	end,
}

-- Daily rewards and quests (CM2-G11) render from the same summary poll.
local questPanel = QuestPanel.new(context)
-- Advent calendar (CM2-A1) renders from the Advent* player attributes.
AdventPanel.new(context)
-- Event shop (CM2-45) renders summary.event from the same summary poll.
local eventPanel = EventShopPanel.new(context)

-- On a phone the open Lot Manager covers the middle of the safe area (70 % x 80 %), so the HUD and the rail step aside.
local function updateChrome()
	local hide = managerOpen and currentMetrics.compact
	hud.Visible = not hide
	UiKit.setRailHidden(hide)
end

local manager = LotManager.new(gui, context, function(open: boolean)
	managerOpen = open
	updateChrome()
end)

UiKit.onLayout(gui, function(m)
	currentMetrics = m
	local layout = UiTheme.hudLayout(m, 0)
	hud.Position = UDim2.fromOffset(layout.hud.x, layout.hud.y)
	hud.Size = UDim2.fromOffset(layout.hud.w, layout.hud.h)
	local shown: { [string]: boolean } = {}
	for _, placed in ipairs(layout.chips) do
		local label = chipLabels[placed.id]
		shown[placed.id] = true
		label.Visible = true
		label.Position = UDim2.fromOffset(placed.box.x, placed.box.y)
		label.Size = UDim2.fromOffset(placed.box.w, placed.box.h)
	end
	for id, label in pairs(chipLabels) do
		if not shown[id] then
			label.Visible = false
		end
	end
	status.Position = UDim2.fromOffset(layout.status.x, layout.status.y)
	status.Size = UDim2.fromOffset(layout.status.w, layout.status.h)
	manager.applyLayout(m, layout.manager)
	updateChrome()
end)

-- CM2-R3: the HUD says which save runs, why it stopped, or that one must be chosen.
local function updateReady()
	local ready = player:GetAttribute("CompanyReady") == true
	local errorCode = player:GetAttribute("CompanyError")
	-- The ready lines carry a save name or a username and must not be auto-translated.
	status.AutoLocalize = not ready
	if ready and player:GetAttribute("ActiveSaveRole") == "Member" then
		-- Members never receive the save name; the owner's username stands in for it.
		local ownerName = player:GetAttribute("ActiveSaveOwnerName")
		local plotId = UiTheme.plotNumber(player:GetAttribute("PlotId"))
		status.Text = if type(ownerName) == "string"
			then localizedFormat("hudSharedSaveStatus", ownerName, plotId)
			else localizedFormat("hudSharedSaveStatusUnknown", plotId)
	elseif ready then
		status.Text = localizedFormat(
			"hudSaveStatus",
			tostring(player:GetAttribute("ActiveSaveName") or ""),
			UiTheme.plotNumber(player:GetAttribute("PlotId"))
		)
	elseif errorCode ~= nil then
		status.Text = localized(Localization.saveErrorKey(errorCode))
	elseif player:GetAttribute("ActiveSaveId") == nil then
		status.Text = localized("hudChooseSave")
	else
		status.Text = localized("saveLoading")
	end
	lotStatusLabel.Text = if ready
		then localized("hudLotOpen")
		elseif errorCode ~= nil then localized("hudLotPaused")
		else localized("hudLotClosed")
	-- The Lot Manager only works on a running save.
	lotManagerButton.Visible = ready
	if not ready then
		manager.close()
	end
end
for _, attribute in
	{
		"CompanyReady",
		"CompanyError",
		"ActiveSaveId",
		"ActiveSaveName",
		"ActiveSaveRole",
		"ActiveSaveOwnerName",
		"PlotId",
	}
do
	player:GetAttributeChangedSignal(attribute):Connect(updateReady)
end
updateReady()

local function renderChips(summary: any)
	if type(summary) ~= "table" then
		cashLabel.Text = localized("loading")
		reputationLabel.Text = localized("loading")
		dayLabel.Text = localized("hudDayUnknown")
		return
	end
	cashLabel.Text = localizedFormat("hudCash", UiTheme.formatMoney(summary.cash))
	reputationLabel.Text = localizedFormat("hudReputation", math.floor(summary.reputation))
	dayLabel.Text = if type(summary.day) == "number"
		then localizedFormat("hudDay", math.floor(summary.day))
		else localized("hudDayUnknown")
end

refreshSummary = function()
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local response = UiKit.request(remote, "Company.GetSummary", {})
	if not (response.ok and response.data) then
		return
	end
	lastSummary = response.data
	renderChips(response.data)
	manager.render(response.data)
	questPanel.render(response.data)
	eventPanel.render(response.data)
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(refreshSummary)
-- A switched save starts from its own summary, never the previous save's figures.
player:GetAttributeChangedSignal("ActiveSaveId"):Connect(function()
	lastSummary = nil
	renderChips(nil)
	manager.render(nil)
	questPanel.render(nil)
	eventPanel.render(nil)
	refreshSummary()
end)

UiKit.onActivated(lotManagerButton, manager.toggle)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == Enum.KeyCode.M and player:GetAttribute("CompanyReady") == true then
		manager.toggle()
	end
end)

task.spawn(function()
	while gui.Parent do
		refreshSummary()
		task.wait(5)
	end
end)
