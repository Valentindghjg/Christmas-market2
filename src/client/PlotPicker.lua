--!strict
-- Plot picker at session start (CM2-PP): the first player of a save on this server browses the
-- plots from a camera view over the map ("Plot N of 6", prev/next), chooses a free one and
-- confirms. Nothing is reserved while browsing; the server claims the chosen plot on
-- Save.Play {saveId, plotId} and answers PlotTaken when someone was faster. Mobile first; every
-- button is at least 44 px. Keyboard A/D or Left/Right, gamepad L1/R1 browse; Enter or A
-- chooses and confirms; B cancels.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local PlotPicker = {}

export type Request = (action: string, payload: { [string]: any }) -> any -- nil while another request is in flight
export type Callbacks = { onBack: () -> (), onFailed: (errorCode: string) -> () }

type Row = { plotId: string, number: number, side: string, free: boolean, name: string? }
type State = {
	saveId: string,
	rows: { Row },
	total: number,
	index: number,
	request: Request,
	callbacks: Callbacks,
	confirming: boolean,
	busy: boolean,
}

local CONFIG = UiTheme.PlotPicker
local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat
local PANEL = UiKit.Colors.Panel
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand
local DISABLED = UiKit.Colors.Disabled

local ACTION_PREV = "PlotPickerPrev"
local ACTION_NEXT = "PlotPickerNext"
local ACTION_ACCEPT = "PlotPickerAccept"
local ACTION_CANCEL = "PlotPickerCancel"

-- Layout ------------------------------------------------------------------------------------

local gui = UiKit.screenGui("PlotPickerUI", CONFIG.displayOrder)
gui:SetAttribute("Open", false)

local function frame(name: string): Frame
	local value = Instance.new("Frame")
	value.Name = name
	value.BackgroundColor3 = PANEL
	value.BorderSizePixel = 0
	value.Active = true
	value.Visible = false
	value.Parent = gui
	UiKit.corner(value, UiTheme.CornerRadius.Panel)
	return value
end

local panel = frame("Panel")
local title = UiKit.label(panel, "Title", localized("plotPickerTitle"), UiTheme.TextSize.Title)
local prevButton = UiKit.button(panel, "Prev", localized("plotPickerPrev"), SAND, 20)
local nextButton = UiKit.button(panel, "Next", localized("plotPickerNext"), SAND, 20)
local plotNumber = UiKit.label(panel, "PlotNumber", "", CONFIG.numberTextSize)
local plotStatus = UiKit.label(panel, "PlotStatus", "", UiTheme.TextSize.Small)
plotStatus.TextWrapped = true
-- May contain a lot-sign name (a filtered save name or a username).
plotStatus.AutoLocalize = false
local message = UiKit.label(panel, "Message", "", UiTheme.TextSize.Small)
message.AutoLocalize = false
local backButton = UiKit.button(panel, "Back", localized("plotPickerBack"), SAND, 16)
local chooseButton = UiKit.button(panel, "Choose", localized("plotPickerChoose"), GOLD, 16)

local confirm = frame("Confirm")
confirm.ZIndex = 2
local confirmText = UiKit.label(confirm, "ConfirmText", "", 16)
confirmText.TextWrapped = true
local yesButton = UiKit.button(confirm, "Yes", localized("plotPickerYes"), GOLD)
local noButton = UiKit.button(confirm, "No", localized("plotPickerNo"), SAND)

local function place(object: GuiObject, b: UiTheme.Box)
	object.Position = UDim2.fromOffset(b.x, b.y)
	object.Size = UDim2.fromOffset(b.w, b.h)
end

UiKit.onLayout(gui, function(m)
	local layout = UiTheme.plotPickerLayout(m)
	place(panel, layout.panel)
	place(title, layout.title)
	place(prevButton, layout.prevButton)
	place(nextButton, layout.nextButton)
	place(plotNumber, layout.plotNumber)
	place(plotStatus, layout.status)
	place(message, layout.message)
	place(backButton, layout.back)
	place(chooseButton, layout.choose)
	place(confirm, layout.confirm)
	place(confirmText, layout.confirmText)
	place(yesButton, layout.yes)
	place(noButton, layout.no)
end)

-- State -------------------------------------------------------------------------------------

local state: State? = nil
local tween: Tween? = nil

local function controls(): any
	local playerScripts = player:FindFirstChild("PlayerScripts")
	local module = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local required, playerModule = pcall(require, module :: any)
	if not required or type(playerModule) ~= "table" then
		return nil
	end
	local got, value = pcall(function()
		return (playerModule :: any):GetControls()
	end)
	return if got then value else nil
end

local function setControlsEnabled(enabled: boolean)
	local value = controls()
	if value == nil then
		return
	end
	pcall(function()
		if enabled then
			value:Enable()
		else
			value:Disable()
		end
	end)
end

local function cancelTween()
	if tween then
		tween:Cancel()
		tween = nil
	end
end

local function redraw()
	local current = state
	if not current then
		return
	end
	local row = current.rows[current.index]
	if not row then
		return
	end
	plotNumber.Text = localizedFormat("plotPickerNumber", row.number, current.total)
	if row.free then
		plotStatus.Text = localized(if row.side == "South" then "plotPickerFreeSouth" else "plotPickerFreeNorth")
	elseif type(row.name) == "string" then
		plotStatus.Text = localizedFormat("plotPickerOccupiedBy", row.name)
	else
		plotStatus.Text = localized("plotPickerOccupied")
	end
	chooseButton.Active = row.free
	chooseButton.AutoButtonColor = row.free
	chooseButton.BackgroundColor3 = if row.free then GOLD else DISABLED
	gui:SetAttribute("SelectedPlotId", row.plotId)
end

-- Selects a row (the index wraps) and moves the camera over its plot.
local function focus(index: number, animate: boolean)
	local current = state
	if not current or #current.rows == 0 then
		return
	end
	current.index = ((index - 1) % #current.rows) + 1
	redraw()
	local row = current.rows[current.index]
	local spot = MapLayout.PLOTS[row.number]
	local camera = workspace.CurrentCamera
	if not (spot and camera) then
		return
	end
	local center = Vector3.new(spot.x, 0, spot.z)
	local goal = CFrame.lookAt(center + Vector3.new(0, CONFIG.cameraHeight, spot.facing * CONFIG.cameraBack), center)
	cancelTween()
	if animate then
		local value = TweenService:Create(
			camera,
			TweenInfo.new(CONFIG.tweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = goal }
		)
		tween = value
		value:Play()
	else
		camera.CFrame = goal
	end
	-- StreamingEnabled: the plot around the camera must stream in.
	task.spawn(function()
		pcall(player.RequestStreamAroundAsync, player, center)
	end)
end

local function browse(step: number)
	local current = state
	if not current or current.confirming or current.busy then
		return
	end
	focus(current.index + step, true)
end

local function exit()
	ContextActionService:UnbindAction(ACTION_PREV)
	ContextActionService:UnbindAction(ACTION_NEXT)
	ContextActionService:UnbindAction(ACTION_ACCEPT)
	ContextActionService:UnbindAction(ACTION_CANCEL)
	setControlsEnabled(true)
	cancelTween()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	panel.Visible = false
	confirm.Visible = false
	message.Text = ""
	UiKit.setBaseLayer(nil)
	UiKit.setRailHidden(false)
	gui:SetAttribute("Open", false)
	gui:SetAttribute("SelectedPlotId", nil)
	state = nil
end

local function hideConfirm()
	confirm.Visible = false
	local current = state
	if current then
		current.confirming = false
	end
end

local function choose()
	local current = state
	if not current or current.confirming or current.busy then
		return
	end
	local row = current.rows[current.index]
	if not (row and row.free) then
		return
	end
	current.confirming = true
	confirmText.Text = localizedFormat("plotPickerConfirm", row.number)
	confirm.Visible = true
end

local function back()
	local current = state
	if not current or current.busy then
		return
	end
	exit()
	current.callbacks.onBack()
end

local function failed(current: State, errorCode: unknown)
	exit()
	current.callbacks.onFailed(if type(errorCode) == "string" then errorCode else "InternalError")
end

-- Someone took the chosen plot first: reload the list, or play without a plot when the save no
-- longer needs a pick (attach or the automatic path).
local function plotTaken(current: State)
	hideConfirm()
	message.Text = localized(Localization.saveErrorKey("PlotTaken"))
	local response = current.request("Save.Plots", { saveId = current.saveId })
	if state ~= current then
		return
	end
	if response == nil then
		current.busy = false
		return
	end
	if not response.ok then
		failed(current, response.errorCode)
		return
	end
	local data = response.data
	if type(data) == "table" and data.pick == true and type(data.plots) == "table" and #data.plots > 0 then
		current.rows = data.plots
		current.total = if type(data.total) == "number" then data.total else #data.plots
		if current.index > #current.rows then
			current.index = #current.rows
		end
		redraw()
		current.busy = false
		return
	end
	local played = current.request("Save.Play", { saveId = current.saveId })
	if state ~= current then
		return
	end
	if played == nil then
		current.busy = false
		return
	end
	if played.ok then
		exit()
	else
		failed(current, played.errorCode)
	end
end

local function accept()
	local current = state
	if not current or not current.confirming or current.busy then
		return
	end
	local row = current.rows[current.index]
	current.busy = true
	message.Text = localized("plotPickerMoving")
	local response = current.request("Save.Play", { saveId = current.saveId, plotId = row.plotId })
	if state ~= current then
		return
	end
	if response == nil then
		current.busy = false
		return
	end
	if response.ok then
		exit()
	elseif response.errorCode == "PlotTaken" then
		plotTaken(current)
	else
		failed(current, response.errorCode)
	end
end

local function decline()
	local current = state
	if not current or current.busy then
		return
	end
	hideConfirm()
end

prevButton.Activated:Connect(function()
	browse(-1)
end)
nextButton.Activated:Connect(function()
	browse(1)
end)
chooseButton.Activated:Connect(choose)
backButton.Activated:Connect(back)
yesButton.Activated:Connect(accept)
noButton.Activated:Connect(decline)

local function handler(callback: () -> ())
	return function(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			callback()
		end
		return Enum.ContextActionResult.Sink
	end
end

local function bindActions()
	local priority = Enum.ContextActionPriority.High.Value
	ContextActionService:BindActionAtPriority(
		ACTION_PREV,
		handler(function()
			browse(-1)
		end),
		false,
		priority,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindActionAtPriority(
		ACTION_NEXT,
		handler(function()
			browse(1)
		end),
		false,
		priority,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindActionAtPriority(
		ACTION_ACCEPT,
		handler(function()
			local current = state
			if current and current.confirming then
				accept()
			else
				choose()
			end
		end),
		false,
		priority,
		Enum.KeyCode.Return,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindActionAtPriority(
		ACTION_CANCEL,
		handler(function()
			local current = state
			if current and current.confirming then
				decline()
			else
				back()
			end
		end),
		false,
		priority,
		Enum.KeyCode.ButtonB
	)
end

-- API ---------------------------------------------------------------------------------------

-- choices is the Save.Plots data with pick == true.
function PlotPicker.open(saveId: string, choices: any, request: Request, callbacks: Callbacks)
	if state then
		exit()
	end
	local rows: { Row } = if type(choices) == "table" and type(choices.plots) == "table" then choices.plots else {}
	if #rows == 0 then
		callbacks.onBack()
		return
	end
	local index = nil
	for position, row in ipairs(rows) do
		if row.plotId == choices.preselectId then
			index = position
			break
		end
	end
	if index == nil then
		for position, row in ipairs(rows) do
			if row.free then
				index = position
				break
			end
		end
	end
	state = {
		saveId = saveId,
		rows = rows,
		total = if type(choices.total) == "number" then choices.total else #rows,
		index = index or 1,
		request = request,
		callbacks = callbacks,
		confirming = false,
		busy = false,
	}
	UiKit.closeModals()
	UiKit.setBaseLayer(back)
	UiKit.setRailHidden(true)
	setControlsEnabled(false)
	bindActions()
	message.Text = ""
	confirm.Visible = false
	panel.Visible = true
	gui:SetAttribute("Open", true)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	focus(index or 1, false)
end

function PlotPicker.isOpen(): boolean
	return state ~= nil
end

return PlotPicker
