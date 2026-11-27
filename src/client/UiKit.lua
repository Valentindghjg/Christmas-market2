--!strict
-- Shared UI kit (CM2-40): locale, element factories, ScreenGui settings, the request envelope,
-- the left button rail, the modal coordinator and the layout binding for dialogs. Every client
-- script requires this module, so its state (rail, modals) is shared by all of them.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local ModalCoordinator = require(Shared:WaitForChild("ModalCoordinator"))
local UiStyle = require(Shared:WaitForChild("UiStyle"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local UiKit = {}

export type DialogParts = {
	frame: Frame,
	list: GuiObject?,
	footer: Frame?,
	leftItems: { GuiObject }?,
	rightHeader: GuiObject?,
}

-- Locale rule (CM2-43): English-only launch; the language comes from Localization.LaunchLanguage,
-- never from the Roblox locale, so a German client still reads English (auto-translation does the rest).
local locale = Localization.LaunchLanguage

function UiKit.localized(key: string): string
	return Localization.get(locale, key)
end

function UiKit.localizedFormat(key: string, ...: any): string
	return Localization.format(locale, key, ...)
end

local colors: { [string]: Color3 } = {}
for name, rgb in pairs(UiTheme.Colors) do
	colors[name] = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end
UiKit.Colors = colors

-- Factories ---------------------------------------------------------------------------------

-- Safe-area aware ScreenGui: AbsoluteSize is the usable area on every device.
function UiKit.screenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.ClipToDeviceSafeArea = true
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return gui
end

function UiKit.corner(parent: Instance, radius: number): UICorner
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
	return value
end

function UiKit.padding(parent: Instance, px: number): UIPadding
	local value = Instance.new("UIPadding")
	value.PaddingTop = UDim.new(0, px)
	value.PaddingBottom = UDim.new(0, px)
	value.PaddingLeft = UDim.new(0, px)
	value.PaddingRight = UDim.new(0, px)
	value.Parent = parent
	return value
end

-- Style kit (CM2-UI1) -------------------------------------------------------------------------

-- One running tween per instance and key: a new tween replaces the old one.
local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

local function play(instance: Instance, key: string, info: TweenInfo, goal: { [string]: any }): Tween
	local perInstance = running[instance]
	if not perInstance then
		perInstance = {}
		running[instance] = perInstance
	end
	local previous = perInstance[key]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(instance, info, goal)
	perInstance[key] = tween
	tween:Play()
	return tween
end

local function tweenInfo(time: number, style: string, direction: string): TweenInfo
	return TweenInfo.new(time, Enum.EasingStyle[style], Enum.EasingDirection[direction])
end

local function applyProps(instance: Instance, props: { [string]: any })
	local loose = instance :: any
	for key, value in pairs(props) do
		if key == "CornerRadius" then
			loose.CornerRadius = UDim.new(0, value)
		elseif key == "ApplyStrokeMode" then
			loose.ApplyStrokeMode = Enum.ApplyStrokeMode[value]
		elseif key == "Color" then
			loose.Color = colors[value]
		elseif key == "Top" then
			-- UIGradient tints text: a grey multiplier, white at the top.
			local top = value
			local bottom = props.Bottom or 1
			loose.Color = ColorSequence.new(Color3.new(top, top, top), Color3.new(bottom, bottom, bottom))
		elseif key ~= "Bottom" then
			loose[key] = value
		end
	end
end

-- Adds the kit decorations to target; reuses a child of the same class and name, and destroys an
-- unnamed UICorner first.
function UiKit.decorate(target: GuiObject, kind: UiStyle.Kind)
	for _, child in ipairs(target:GetChildren()) do
		if child:IsA("UICorner") and child.Name == "UICorner" then
			child:Destroy()
		end
	end
	for _, spec in ipairs(UiStyle.decorations(kind)) do
		local existing = target:FindFirstChild(spec.name)
		local instance: Instance
		if existing and existing.ClassName == spec.className then
			instance = existing
		else
			instance = Instance.new(spec.className)
			instance.Name = spec.name
		end
		applyProps(instance, spec.props)
		instance.Parent = target
	end
end

-- Buttons whose Activated handlers the Studio hook can call (weak keys).
local handlers: { [GuiButton]: { (...any) -> () } } = setmetatable({}, { __mode = "k" }) :: any
-- Hover state per button, so a release returns to hover or idle.
local hovering: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function ensureClickSound(): Sound
	local existing = SoundService:FindFirstChild("UiClick")
	if existing and existing:IsA("Sound") then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "UiClick"
	sound.SoundId = UiTheme.ClickSound.id
	sound.Volume = UiTheme.ClickSound.volume
	sound.Parent = SoundService
	return sound
end
local clickSound = ensureClickSound()

local function applyInteraction(button: GuiButton, state: string)
	local press = button:FindFirstChild("Press")
	if not (press and press:IsA("UIScale")) then
		return
	end
	local spec = UiStyle.interaction(state, hovering[button])
	play(press, "Scale", tweenInfo(spec.time, spec.style, spec.direction), { Scale = spec.scale })
end

local function isInteractive(button: GuiButton): boolean
	return UiStyle.interactive(button.Active, button:GetAttribute("KitDisabled") == true)
end

local function bindInteraction(button: GuiButton)
	button.InputBegan:Connect(function(input: InputObject)
		if not isInteractive(button) then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering[button] = true
			applyInteraction(button, "hover")
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			applyInteraction(button, "press")
		elseif input.UserInputType == Enum.UserInputType.Touch then
			applyInteraction(button, "touchPress")
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering[button] = false
			if isInteractive(button) then
				applyInteraction(button, "idle")
			end
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if isInteractive(button) then
				applyInteraction(button, "release")
			end
		end
	end)
end

-- Connects handler to Activated (click sound first) and registers it for the Studio hook.
function UiKit.onActivated(button: GuiButton, handler: (...any) -> ()): RBXScriptConnection
	local list = handlers[button]
	if not list then
		list = {}
		handlers[button] = list
	end
	table.insert(list, handler)
	return button.Activated:Connect(function(...)
		clickSound:Play()
		handler(...)
	end)
end

-- Text colour for a fill: the Colors entry whose value equals color decides (UiStyle.textOn);
-- an unknown colour gets DarkText.
function UiKit.textOn(color: Color3): Color3
	for name, value in pairs(colors) do
		if value == color then
			return colors[UiStyle.textOn(name)]
		end
	end
	return colors.DarkText
end

-- Sets a button's fill and, for text buttons, the matching text colour.
function UiKit.setFill(button: GuiButton, color: Color3)
	button.BackgroundColor3 = color
	if button:IsA("TextButton") then
		button.TextColor3 = UiKit.textOn(color)
	end
end

-- Marks a button disabled (no hover or press motion); with fill, also swaps the fill between fill
-- and Disabled.
function UiKit.setEnabled(button: GuiButton, enabled: boolean, fill: Color3?)
	button:SetAttribute("KitDisabled", if enabled then nil else true)
	if fill then
		UiKit.setFill(button, if enabled then fill else colors.Disabled)
	end
	if not enabled then
		hovering[button] = false
		local press = button:FindFirstChild("Press")
		if press and press:IsA("UIScale") then
			play(press, "Scale", tweenInfo(0, "Quad", "Out"), { Scale = 1 })
		end
	end
end

-- Title band for a window's Title label: Header fill, Cream text, rounded and shaded.
function UiKit.headerBand(title: TextLabel)
	UiKit.decorate(title, "header")
	title.BackgroundTransparency = 0
	title.BackgroundColor3 = colors.Header
	title.TextColor3 = colors.Cream
	local inset = title:FindFirstChild("HeaderInset")
	if not (inset and inset:IsA("UIPadding")) then
		inset = Instance.new("UIPadding")
		inset.Name = "HeaderInset"
		inset.Parent = title
	end
	local pad = inset :: UIPadding
	pad.PaddingLeft = UDim.new(0, UiTheme.Style.HeaderInset)
	pad.PaddingRight = UDim.new(0, UiTheme.Style.HeaderInset)
end

-- Selected tabs and mode buttons: a thicker Header-green outline.
function UiKit.setSelected(button: GuiButton, selected: boolean)
	local stroke = button:FindFirstChild("Outline")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Thickness = if selected then UiTheme.Style.StrokeSelected else UiTheme.Style.StrokeControl
		stroke.Color = if selected then colors.Header else colors.Outline
	end
end

function UiKit.setOutlineColor(button: GuiButton, color: Color3)
	local stroke = button:FindFirstChild("Outline")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = color
	end
end

function UiKit.card(frame: GuiObject)
	UiKit.decorate(frame, "card")
end

-- A drop shadow or dim layer behind a window.
local function backdrop(parent: Instance, name: string, zIndex: number, transparency: number): Frame
	local value = Instance.new("Frame")
	value.Name = name
	value.BackgroundColor3 = colors.Shadow
	value.BackgroundTransparency = transparency
	value.BorderSizePixel = 0
	value.Active = false
	value.ZIndex = zIndex
	value.Visible = false
	value.Parent = parent
	return value
end

-- Window chrome: kit decorations, a shadow (and optionally a dim layer) that follows the frame's
-- Visible, and the open motion. The frame itself hides at once.
function UiKit.window(frame: Frame, options: { dim: boolean? }?)
	UiKit.decorate(frame, "window")
	local open = frame:FindFirstChild("Open") :: UIScale
	local parent = frame.Parent :: Instance
	local style = UiTheme.Style
	local motion = UiTheme.Motion

	local dimmed = options ~= nil and options.dim == true
	if dimmed then
		frame.ZIndex = math.max(frame.ZIndex, 3)
	end
	local shadow = backdrop(parent, frame.Name .. "Shadow", frame.ZIndex - 1, style.ShadowTransparency)
	UiKit.corner(shadow, UiTheme.CornerRadius.Panel)
	local dim: Frame? = nil
	if dimmed then
		local layer = backdrop(parent, frame.Name .. "Dim", frame.ZIndex - 2, style.DimTransparency)
		layer.Size = UDim2.fromScale(1, 1)
		dim = layer
	end

	local function mirror()
		local position = frame.Position
		shadow.AnchorPoint = frame.AnchorPoint
		shadow.Size = frame.Size
		shadow.Position = UDim2.new(
			position.X.Scale,
			position.X.Offset + style.ShadowOffset,
			position.Y.Scale,
			position.Y.Offset + style.ShadowOffset
		)
	end
	mirror()
	frame:GetPropertyChangedSignal("AnchorPoint"):Connect(mirror)
	frame:GetPropertyChangedSignal("Size"):Connect(mirror)
	frame:GetPropertyChangedSignal("Position"):Connect(mirror)

	local layers: { { layer: Frame, shown: number } } = { { layer = shadow, shown = style.ShadowTransparency } }
	if dim then
		table.insert(layers, { layer = dim, shown = style.DimTransparency })
	end

	local function show(animate: boolean)
		for _, item in ipairs(layers) do
			item.layer.Visible = true
			if animate then
				item.layer.BackgroundTransparency = 1
				play(
					item.layer,
					"Fade",
					tweenInfo(motion.openTime, "Quad", "Out"),
					{ BackgroundTransparency = item.shown }
				)
			else
				item.layer.BackgroundTransparency = item.shown
			end
		end
		if animate then
			open.Scale = motion.openScale
			play(open, "Scale", tweenInfo(motion.openTime, "Quad", "Out"), { Scale = 1 })
		else
			open.Scale = 1
		end
	end

	local function hide()
		for _, item in ipairs(layers) do
			local layer = item.layer
			local tween =
				play(layer, "Fade", tweenInfo(motion.closeTime, "Quad", "Out"), { BackgroundTransparency = 1 })
			tween.Completed:Connect(function(status: Enum.PlaybackState)
				if status == Enum.PlaybackState.Completed and not frame.Visible then
					layer.Visible = false
				end
			end)
		end
	end

	if frame.Visible then
		show(false)
	end
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			show(true)
		else
			hide()
		end
	end)
	frame.Destroying:Connect(function()
		shadow:Destroy()
		if dim then
			dim:Destroy()
		end
	end)
end

-- Toast: slides in 12 px and fades; the caller owns Visible.
function UiKit.animateToast(toast: TextLabel, box: UiTheme.Box, shown: boolean)
	local motion = UiTheme.Motion
	local info = tweenInfo(motion.toastTime, "Quad", "Out")
	if shown then
		toast.Position = UDim2.fromOffset(box.x, box.y - motion.toastSlide)
		toast.BackgroundTransparency = 1
		toast.TextTransparency = 1
		play(toast, "Toast", info, {
			Position = UDim2.fromOffset(box.x, box.y),
			BackgroundTransparency = 0,
			TextTransparency = 0,
		})
	else
		play(toast, "Toast", info, { BackgroundTransparency = 1, TextTransparency = 1 })
	end
end

-- Dark outline for text that sits over the world (title sizes get it from label).
function UiKit.outlineText(label: TextLabel)
	local stroke = label:FindFirstChild("TitleOutline")
	if not (stroke and stroke:IsA("UIStroke")) then
		stroke = Instance.new("UIStroke")
		stroke.Name = "TitleOutline"
		stroke.Parent = label
	end
	local value = stroke :: UIStroke
	value.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	value.Color = colors.Outline
	value.Thickness = UiTheme.Style.StrokeTitle
end

-- playerText marks save names, usernames, codes and typed text: never auto-translated.
function UiKit.label(parent: Instance, name: string, text: string, textSize: number, playerText: boolean?): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	value.Text = text
	value.TextColor3 = colors.DarkText
	value.TextSize = textSize
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextTruncate = Enum.TextTruncate.AtEnd
	if textSize >= UiTheme.TextSize.Title then
		value.FontFace = UiTheme.fontFace("Title")
		UiKit.outlineText(value)
	else
		value.FontFace = UiTheme.fontFace("Body")
	end
	if playerText == true then
		value.AutoLocalize = false
	end
	value.Parent = parent
	return value
end

function UiKit.button(parent: Instance, name: string, text: string, color: Color3, textSize: number?): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.BackgroundColor3 = color
	value.TextColor3 = UiKit.textOn(color)
	value.FontFace = UiTheme.fontFace("Body")
	value.TextSize = textSize or UiTheme.TextSize.Body
	value.TextWrapped = true
	value.AutoButtonColor = false
	value.Text = text
	value.Parent = parent
	UiKit.decorate(value, "button")
	bindInteraction(value)
	return value
end

function UiKit.textBox(parent: Instance, name: string, placeholder: string): TextBox
	local value = Instance.new("TextBox")
	value.Name = name
	value.BackgroundColor3 = colors.Cream
	value.TextColor3 = colors.DarkText
	value.PlaceholderText = placeholder
	value.PlaceholderColor3 = colors.Placeholder
	value.FontFace = UiTheme.fontFace("Light")
	value.TextSize = UiTheme.TextSize.Input
	value.Text = ""
	value.ClearTextOnFocus = false
	value.TextXAlignment = Enum.TextXAlignment.Left
	-- Typed names and codes are player text, never auto-translated.
	value.AutoLocalize = false
	value.Parent = parent
	UiKit.decorate(value, "card")
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 8)
	inset.PaddingRight = UDim.new(0, 8)
	inset.Parent = value
	return value
end

-- Studio hook (CM2-UI1): the playtester presses buttons and sets interaction states without a
-- mouse. Only in Studio; "press" runs the registered Activated handlers.
local function resolve(path: string): Instance?
	local current: Instance? = (Players.LocalPlayer :: Player):FindFirstChild("PlayerGui")
	for segment in string.gmatch(path, "[^/]+") do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

local function isHidden(instance: Instance): boolean
	local current: Instance? = instance
	while current do
		if current:IsA("GuiObject") and not current.Visible then
			return true
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return true
		end
		current = current.Parent
	end
	return false
end

local function studioHook(action: string, path: string, state: string?): { [string]: any }
	local target = resolve(path)
	if not (target and target:IsA("GuiObject")) then
		return { ok = false, error = "NotFound" }
	end
	if action == "press" then
		if isHidden(target) then
			return { ok = false, error = "Hidden" }
		end
		local list = if target:IsA("GuiButton") then handlers[target] else nil
		if not list or #list == 0 then
			return { ok = false, error = "NoHandler" }
		end
		for _, handler in ipairs(list) do
			pcall(handler)
		end
		return { ok = true, handlers = #list }
	elseif action == "interact" and target:IsA("GuiButton") and type(state) == "string" then
		if not isInteractive(target) then
			return { ok = false, error = "Disabled" }
		end
		if state == "hover" then
			hovering[target] = true
		elseif state == "idle" then
			hovering[target] = false
		end
		applyInteraction(target, state)
		return { ok = true }
	end
	return { ok = false, error = "NotFound" }
end

if RunService:IsStudio() and Players.LocalPlayer then
	local hook = Instance.new("BindableFunction")
	hook.Name = "StudioUiHook"
	hook.OnInvoke = studioHook
	hook.Parent = Players.LocalPlayer
end

-- CM2-UVF4: a dialog's status line is the first, wrapped, auto-sized entry of its list (hidden
-- while empty) so long server messages fit; a new message scrolls the list to the top.
function UiKit.listStatus(list: ScrollingFrame, name: string): TextLabel
	local value = UiKit.label(list, name, "", UiTheme.TextSize.Small)
	value.LayoutOrder = -1
	value.Size = UDim2.new(1, -8, 0, 0)
	value.AutomaticSize = Enum.AutomaticSize.Y
	value.TextWrapped = true
	value.TextTruncate = Enum.TextTruncate.None
	value.TextYAlignment = Enum.TextYAlignment.Top
	value.Visible = false
	value:GetPropertyChangedSignal("Text"):Connect(function()
		value.Visible = value.Text ~= ""
		if value.Visible then
			list.CanvasPosition = Vector2.zero
		end
	end)
	return value
end

-- Requests ----------------------------------------------------------------------------------

-- InvokeServer can throw (server error, disconnect); the UI must stay usable.
function UiKit.request(remote: RemoteFunction, action: string, payload: { [string]: any }): any
	local called, response = pcall(remote.InvokeServer, remote, {
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = action,
		payload = payload,
	})
	if not called or type(response) ~= "table" then
		return { ok = false, errorCode = "ConnectionError" }
	end
	return response
end

-- Layout ------------------------------------------------------------------------------------

-- Calls the callback now and on every size change of the safe area.
function UiKit.onLayout(gui: ScreenGui, callback: (UiTheme.Metrics) -> ()): RBXScriptConnection
	local function apply()
		local size = gui.AbsoluteSize
		callback(UiTheme.metrics(size.X, size.Y))
	end
	apply()
	return gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
end

type Original = { anchor: Vector2, position: UDim2, size: UDim2 }

local function remember(originals: { [GuiObject]: Original }, item: GuiObject)
	originals[item] = { anchor = item.AnchorPoint, position = item.Position, size = item.Size }
end

local function place(item: GuiObject, placed: UiTheme.Box)
	item.AnchorPoint = Vector2.new(0, 0)
	item.Position = UDim2.fromOffset(placed.x, placed.y)
	item.Size = UDim2.fromOffset(placed.w, placed.h)
end

local function restore(originals: { [GuiObject]: Original }, item: GuiObject)
	local original = originals[item]
	if original then
		item.AnchorPoint = original.anchor
		item.Position = original.position
		item.Size = original.size
	end
end

-- Positions a dialog from UiTheme.dialogLayout. Compact screens use two columns: the list and
-- the left items on the left, the footer (and the right header) on the right. Regular screens
-- keep the original sizes and positions of the left items and the right header.
function UiKit.bindDialog(gui: ScreenGui, parts: DialogParts, spec: UiTheme.DialogSpec)
	local originals: { [GuiObject]: Original } = {}
	local leftItems = parts.leftItems or {}
	for _, item in ipairs(leftItems) do
		remember(originals, item)
	end
	if parts.rightHeader then
		remember(originals, parts.rightHeader)
	end

	UiKit.onLayout(gui, function(m)
		local layout = UiTheme.dialogLayout(m, spec)
		place(parts.frame, layout.frame)
		if parts.list and layout.list then
			place(parts.list, layout.list)
		end
		if parts.footer and layout.footer then
			place(parts.footer, layout.footer)
		end
		for _, item in ipairs(leftItems) do
			restore(originals, item)
			if layout.compact then
				local original = originals[item]
				local height = if original then original.size.Y.Offset else item.Size.Y.Offset
				item.Size = UDim2.fromOffset(layout.leftWidth, height)
			end
		end
		local header = parts.rightHeader
		if header then
			if layout.compact and layout.rightHeader then
				place(header, layout.rightHeader)
			else
				restore(originals, header)
			end
		end
	end)
end

-- Compact-only reflow (22a3b): boxes(m) returns a box per item key, or nil on regular screens; every
-- layout first restores each item's original UDim2s, so regular screens keep them exactly.
function UiKit.bindCompact(
	gui: ScreenGui,
	items: { [string]: GuiObject },
	boxes: (m: UiTheme.Metrics) -> { [string]: UiTheme.Box }?
): RBXScriptConnection
	local originals: { [GuiObject]: Original } = {}
	for _, item in pairs(items) do
		remember(originals, item)
	end
	return UiKit.onLayout(gui, function(m)
		for _, item in pairs(items) do
			restore(originals, item)
		end
		local placed = boxes(m)
		if placed then
			for key, item in pairs(items) do
				local box = placed[key]
				if box then
					place(item, box)
				end
			end
		end
	end)
end

-- Modals ------------------------------------------------------------------------------------

-- Lot Manager, Team panel, stocking bar and teammate finder: one of them at a time. The save
-- picker is the base layer (`setBaseLayer`): any claim closes it, except the finder, which opens
-- over it (ModalCoordinator.OverBase).
local modals = ModalCoordinator.new()

function UiKit.claimModal(id: string, close: () -> ())
	modals.claim(id, close)
end

function UiKit.releaseModal(id: string)
	modals.release(id)
end

function UiKit.closeModals()
	modals.closeAll()
end

function UiKit.setBaseLayer(close: (() -> ())?)
	modals.setBase(close)
end

-- CM2-49: the tutorial hint bar hides behind the base layer and most modals.
function UiKit.heldModal(): string?
	return modals.held()
end

function UiKit.baseLayerOpen(): boolean
	return modals.hasBase()
end

-- CM2-G11: called after every claim, release, closeAll or base change; returns its remover.
function UiKit.onModalsChanged(listener: () -> ()): () -> ()
	return modals.onChange(listener)
end

-- Rail --------------------------------------------------------------------------------------

local railFrame: ScrollingFrame? = nil
local railMetrics: UiTheme.Metrics? = nil
local railButtons: { TextButton } = {}
local railHidden = false

local function applyRail()
	local frame, m = railFrame, railMetrics
	if not (frame and m) then
		return
	end
	local visible: { TextButton } = {}
	for _, railButton in ipairs(railButtons) do
		if railButton.Visible then
			table.insert(visible, railButton)
		end
	end
	table.sort(visible, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end
		return a.Name < b.Name
	end)
	local layout = UiTheme.hudLayout(m, #visible)
	frame.Position = UDim2.fromOffset(layout.rail.x, layout.rail.y)
	frame.Size = UDim2.fromOffset(layout.rail.w, layout.rail.h)
	frame.ScrollingEnabled = layout.railScrolls
	frame.Visible = not railHidden
	for index, railButton in ipairs(visible) do
		local b = layout.railButtons[index]
		railButton.Position = UDim2.fromOffset(b.x, b.y)
		railButton.Size = UDim2.fromOffset(b.w, b.h)
		railButton.TextSize = if b.w < 100 then UiTheme.TextSize.Small else UiTheme.TextSize.Body
	end
end

local function ensureRail(): ScrollingFrame
	if railFrame then
		return railFrame
	end
	local gui = UiKit.screenGui("HudRailUI", 5)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "Rail"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.Parent = gui
	railFrame = frame
	UiKit.onLayout(gui, function(m)
		railMetrics = m
		applyRail()
	end)
	return frame
end

-- Rail slots: 10 LotManagerButton, 20 Shop, 30 Quests, 40 Advent, 50 SavesButton, 60 TeamButton,
-- 70 FinderButton. Buttons start hidden; the owner of a button shows it.
-- Phones: buttons that do not fit above the thumbstick go right of row 1 (CM2-UVF13).
function UiKit.addRailButton(name: string, textKey: string, order: number): TextButton
	local frame = ensureRail()
	local railButton = UiKit.button(frame, name, UiKit.localized(textKey), colors.Sand)
	railButton.LayoutOrder = order
	railButton.Visible = false
	table.insert(railButtons, railButton)
	railButton:GetPropertyChangedSignal("Visible"):Connect(applyRail)
	applyRail()
	return railButton
end

-- Hides the whole rail without touching the buttons' own Visible state.
function UiKit.setRailHidden(hidden: boolean)
	railHidden = hidden
	applyRail()
end

return UiKit
