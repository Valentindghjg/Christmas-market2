--!strict
-- Guided tutorial hints (CM2-49, docs/plans/CM2-49.md): a one-line hint bar with Skip, a GUI
-- arrow and highlight, and a world arrow above the bay or counter. The server owns the progress
-- and mirrors it into the `TutorialStep` attribute; this script only reads it and asks for
-- Tutorial.Skip. It never blocks or changes a gameplay action. PROVISIONAL design.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local player = Players.LocalPlayer :: Player
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction") :: RemoteFunction

local BAR = UiTheme.TutorialBar
local localized = UiKit.localized
local colors = UiKit.Colors
local ACTIVE_STEPS = { Order = true, Stock = true, Checkout = true }
local FAILED_SECONDS = 3

-- Objects -----------------------------------------------------------------------------------

local gui = UiKit.screenGui("TutorialUI", BAR.displayOrder)

local bar = Instance.new("Frame")
bar.Name = "HintBar"
bar.BackgroundColor3 = colors.Panel
bar.BorderSizePixel = 0
bar.Active = false
bar.Visible = false
bar.Parent = gui
UiKit.corner(bar, UiTheme.CornerRadius.Row)

local hintText = UiKit.label(bar, "HintText", "", BAR.textSize)
hintText.TextWrapped = true
hintText.TextXAlignment = Enum.TextXAlignment.Left

local skipButton = UiKit.button(bar, "SkipTutorial", localized("tutorialSkip"), colors.Sand)

local arrow = Instance.new("TextLabel")
arrow.Name = "TutorialArrow"
arrow.Text = localized("tutorialArrow")
arrow.TextColor3 = colors.Gold
arrow.Font = Enum.Font.GothamBold
arrow.TextSize = 36
arrow.Size = UDim2.fromOffset(BAR.arrowSize, BAR.arrowSize)
arrow.BackgroundTransparency = 1
arrow.Active = false
arrow.Interactable = false
arrow.Visible = false
arrow.Parent = gui

local highlight = Instance.new("Frame")
highlight.Name = "TutorialHighlight"
highlight.BackgroundTransparency = 1
highlight.BorderSizePixel = 0
highlight.Active = false
highlight.Interactable = false
highlight.Visible = false
highlight.Parent = gui
local stroke = Instance.new("UIStroke")
stroke.Color = colors.Gold
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = highlight

local currentMetrics: UiTheme.Metrics? = nil
local docked = false
local textShown = true

local function applyLayout()
	if currentMetrics == nil then
		return
	end
	local layout = UiTheme.tutorialBarLayout(currentMetrics, docked)
	bar.Position = UDim2.fromOffset(layout.frame.x, layout.frame.y)
	bar.Size = UDim2.fromOffset(layout.frame.w, layout.frame.h)
	hintText.Position = UDim2.fromOffset(layout.text.x, layout.text.y)
	hintText.Size = UDim2.fromOffset(layout.text.w, layout.text.h)
	skipButton.Position = UDim2.fromOffset(layout.skip.x, layout.skip.y)
	skipButton.Size = UDim2.fromOffset(layout.skip.w, layout.skip.h)
	textShown = layout.showText
	hintText.Visible = layout.showText
end

local function setDocked(value: boolean)
	if docked ~= value then
		docked = value
		applyLayout()
	end
end

UiKit.onLayout(gui, function(m)
	currentMetrics = m
	applyLayout()
end)

local worldArrow = Instance.new("BillboardGui")
worldArrow.Name = "TutorialWorldArrow"
worldArrow.Size = UDim2.fromOffset(BAR.arrowSize, BAR.arrowSize)
worldArrow.StudsOffset = Vector3.new(0, BAR.worldArrowStuds, 0)
worldArrow.AlwaysOnTop = true
worldArrow.MaxDistance = 250
worldArrow.ResetOnSpawn = false
worldArrow.Enabled = false
local worldArrowText = Instance.new("TextLabel")
worldArrowText.Name = "Arrow"
worldArrowText.Size = UDim2.fromScale(1, 1)
worldArrowText.BackgroundTransparency = 1
worldArrowText.Text = "▼"
worldArrowText.Font = Enum.Font.GothamBold
worldArrowText.TextSize = 40
worldArrowText.TextColor3 = colors.Gold
worldArrowText.TextStrokeTransparency = 0
worldArrowText.Parent = worldArrow
worldArrow.Parent = playerGui

-- Targets -----------------------------------------------------------------------------------

-- The object and every GuiObject ancestor up to its ScreenGui are visible.
local function shown(object: Instance?): boolean
	if object == nil then
		return false
	end
	local current: Instance? = object
	while current ~= nil and not current:IsA("LayerCollector") do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		current = current.Parent
	end
	return current ~= nil
end

local function guiObject(instance: Instance?): GuiObject?
	if instance ~= nil and instance:IsA("GuiObject") then
		return instance
	end
	return nil
end

local function lotManagerButton(): GuiObject?
	local rail = playerGui:FindFirstChild("HudRailUI")
	return guiObject(rail and rail:FindFirstChild("LotManagerButton", true))
end

-- The Supplier tab button and the Order button inside the Lot Manager's Supplier page.
local function supplierTargets(): (GuiObject?, GuiObject?)
	local main = playerGui:FindFirstChild("ChristmasMarketUI")
	local manager = main and main:FindFirstChild("LotManager")
	if manager == nil then
		return nil, nil
	end
	local tab = guiObject(manager:FindFirstChild("Tab_Supplier", true))
	local page = manager:FindFirstChild("Page_Supplier", true)
	local order = guiObject(page and page:FindFirstChild("OrderTrees", true))
	return tab, order
end

local function plotModel(): Instance?
	local plotId = player:GetAttribute("PlotId")
	if type(plotId) ~= "string" then
		return nil
	end
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plots = world and world:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(plotId)
end

local function promptEnabled(parent: Instance?, name: string): boolean
	local prompt = parent and parent:FindFirstChild(name)
	return prompt ~= nil and prompt:IsA("ProximityPrompt") and prompt.Enabled
end

-- The lowest bay with trees and the lowest bay with a delivery on the way.
local function bayTargets(plot: Instance?): (BasePart?, BasePart?)
	local receiving = plot and plot:FindFirstChild("Receiving")
	if receiving == nil then
		return nil, nil
	end
	local withTrees: BasePart? = nil
	local arriving: BasePart? = nil
	for index = 1, GameConfig.Receiving.BayCount do
		local bay = receiving:FindFirstChild("Bay_" .. index)
		if bay and bay:IsA("BasePart") then
			if withTrees == nil and promptEnabled(bay, "StockBay") then
				withTrees = bay
			end
			local label = bay:FindFirstChild("Label")
			local text = label and label:FindFirstChild("Text")
			if arriving == nil and text and text:GetAttribute("LabelKind") == "BayArriving" then
				arriving = bay
			end
		end
	end
	return withTrees, arriving
end

local function counterBase(plot: Instance?): BasePart?
	local counter = plot and plot:FindFirstChild("CheckoutCounter")
	local base = counter and counter:FindFirstChild("CounterBase")
	if base and base:IsA("BasePart") then
		return base
	end
	return nil
end

-- State -------------------------------------------------------------------------------------

local lastStep: any = player:GetAttribute("TutorialStep")
local doneUntil: number? = nil
local armedUntil: number? = nil
local failedUntil: number? = nil
local sending = false
local dismissed = false
local guiTarget: GuiObject? = nil
local arrowOnTarget = false
local renderConnection: RBXScriptConnection? = nil

local function placeOverlays()
	local target = guiTarget
	if target == nil then
		return
	end
	if not shown(target) then
		highlight.Visible = false
		arrow.Visible = false
		return
	end
	-- Positions are relative to this ScreenGui; both guis share one coordinate space.
	local origin = gui.AbsolutePosition
	local position = target.AbsolutePosition - origin
	local size = target.AbsoluteSize
	local pad = BAR.highlightPad
	highlight.Position = UDim2.fromOffset(position.X - pad, position.Y - pad)
	highlight.Size = UDim2.fromOffset(size.X + 2 * pad, size.Y + 2 * pad)
	highlight.Visible = true
	arrow.Position = UDim2.fromOffset(position.X + size.X + 4, position.Y + math.floor((size.Y - BAR.arrowSize) / 2))
	arrow.Visible = arrowOnTarget
end

local function setGuiTarget(target: GuiObject?, withArrow: boolean)
	guiTarget = target
	arrowOnTarget = withArrow and target ~= nil
	if target == nil then
		highlight.Visible = false
		arrow.Visible = false
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		return
	end
	if renderConnection == nil then
		renderConnection = RunService.RenderStepped:Connect(placeOverlays)
	end
	placeOverlays()
end

local function setWorldTarget(part: BasePart?)
	worldArrow.Adornee = part
	worldArrow.Enabled = part ~= nil
end

local function showBar(text: string?, withSkip: boolean)
	if text == nil then
		bar.Visible = false
		return
	end
	if not textShown and not withSkip then
		bar.Visible = false
		return
	end
	local now = os.clock()
	if failedUntil ~= nil and now < failedUntil then
		hintText.Text = localized("tutorialSkipFailed")
	else
		hintText.Text = text
	end
	local armed = armedUntil ~= nil and now < armedUntil
	skipButton.Text = localized(if armed then "tutorialSkipConfirm" else "tutorialSkip")
	skipButton.Visible = withSkip
	bar.Visible = true
end

local function hideAll()
	showBar(nil, false)
	setGuiTarget(nil, false)
	setWorldTarget(nil)
end

-- The step's own hint text and world arrow without a modal (the table's last three rows).
local function stepHint(step: string, plot: Instance?): (string, BasePart?)
	if step == "Order" then
		return localized("tutorialOrder"), nil
	elseif step == "Stock" then
		local withTrees, arriving = bayTargets(plot)
		if withTrees then
			return localized("tutorialStock"), withTrees
		end
		return localized("tutorialDelivery"), arriving
	end
	local base = counterBase(plot)
	local waiting = promptEnabled(base, "CheckoutPrompt")
	return localized(if waiting then "tutorialCheckout" else "tutorialCheckoutWait"), base
end

-- Refresh -----------------------------------------------------------------------------------

local function refresh()
	if player:GetAttribute("CompanyReady") ~= true or UiKit.baseLayerOpen() then
		hideAll()
		return
	end
	setDocked(UiKit.heldModal() == "Stocking")
	local now = os.clock()
	if doneUntil ~= nil then
		if now < doneUntil then
			showBar(localized("tutorialDone"), false)
			setGuiTarget(nil, false)
			setWorldTarget(nil)
			return
		end
		doneUntil = nil
	end
	local step = player:GetAttribute("TutorialStep")
	local held = UiKit.heldModal()
	if
		dismissed
		or type(step) ~= "string"
		or not ACTIVE_STEPS[step]
		or (held ~= nil and held ~= "LotManager" and held ~= "Stocking")
	then
		hideAll()
		return
	end
	local plot = plotModel()
	local text, worldTarget = stepHint(step, plot)
	if held == "LotManager" then
		showBar(nil, false)
		if step == "Order" then
			local tab, order = supplierTargets()
			setGuiTarget(if shown(order) then order else tab, false)
		else
			setGuiTarget(nil, false)
		end
		setWorldTarget(worldTarget)
	elseif held == "Stocking" then
		showBar(if step == "Stock" then localized("tutorialPlace") else text, true)
		setGuiTarget(nil, false)
		setWorldTarget(nil)
	else
		showBar(text, true)
		setGuiTarget(if step == "Order" then lotManagerButton() else nil, step == "Order")
		setWorldTarget(worldTarget)
	end
end

-- Skip --------------------------------------------------------------------------------------

skipButton.Activated:Connect(function()
	if sending then
		return
	end
	local now = os.clock()
	if armedUntil == nil or now >= armedUntil then
		armedUntil = now + BAR.confirmSeconds
		refresh()
		task.delay(BAR.confirmSeconds, refresh)
		return
	end
	armedUntil = nil
	sending = true
	local response = UiKit.request(remote, "Tutorial.Skip", {})
	sending = false
	if response.ok or response.errorCode == "TutorialDone" then
		-- Hidden until the server's next TutorialStep value; the client never sets the step.
		dismissed = true
		hideAll()
		return
	end
	failedUntil = os.clock() + FAILED_SECONDS
	refresh()
	task.delay(FAILED_SECONDS, refresh)
end)

player:GetAttributeChangedSignal("TutorialStep"):Connect(function()
	local step = player:GetAttribute("TutorialStep")
	if type(lastStep) == "string" and ACTIVE_STEPS[lastStep] and step == "Done" then
		doneUntil = os.clock() + BAR.doneSeconds
	else
		doneUntil = nil
	end
	lastStep = step
	dismissed = false
	armedUntil = nil
	failedUntil = nil
	refresh()
end)

player:GetAttributeChangedSignal("CompanyReady"):Connect(refresh)

task.spawn(function()
	while true do
		refresh()
		task.wait(BAR.refreshSeconds)
	end
end)
