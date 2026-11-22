--!strict
-- Shared UI kit (CM2-40): locale, element factories, ScreenGui settings, the request envelope,
-- the left button rail, the modal coordinator and the layout binding for dialogs. Every client
-- script requires this module, so its state (rail, modals) is shared by all of them.
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("Localization"))
local ModalCoordinator = require(Shared:WaitForChild("ModalCoordinator"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local UiKit = {}

export type DialogParts = {
	frame: Frame,
	list: GuiObject?,
	footer: Frame?,
	leftItems: { GuiObject }?,
	rightHeader: GuiObject?,
}

-- Locale rule: German or English, anything else is English (CM2-43 changes this one place).
local locale = string.lower(string.sub(LocalizationService.RobloxLocaleId, 1, 2))
if locale ~= "de" and locale ~= "en" then
	locale = "en"
end

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

-- playerText marks save names, usernames, codes and typed text: never auto-translated.
function UiKit.label(parent: Instance, name: string, text: string, textSize: number, playerText: boolean?): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	value.Text = text
	value.TextColor3 = colors.Cream
	value.Font = Enum.Font.GothamBold
	value.TextSize = textSize
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextTruncate = Enum.TextTruncate.AtEnd
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
	value.TextColor3 = colors.DarkText
	value.Font = Enum.Font.GothamBold
	value.TextSize = textSize or UiTheme.TextSize.Body
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	UiKit.corner(value, UiTheme.CornerRadius.Button)
	return value
end

function UiKit.textBox(parent: Instance, name: string, placeholder: string): TextBox
	local value = Instance.new("TextBox")
	value.Name = name
	value.BackgroundColor3 = colors.Cream
	value.TextColor3 = colors.DarkText
	value.PlaceholderText = placeholder
	value.PlaceholderColor3 = colors.Placeholder
	value.Font = Enum.Font.Gotham
	value.TextSize = 16
	value.Text = ""
	value.ClearTextOnFocus = false
	value.TextXAlignment = Enum.TextXAlignment.Left
	-- Typed names and codes are player text, never auto-translated.
	value.AutoLocalize = false
	value.Parent = parent
	UiKit.corner(value, UiTheme.CornerRadius.Button)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 8)
	inset.PaddingRight = UDim.new(0, 8)
	inset.Parent = value
	return value
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

-- Positions a dialog from UiTheme.dialogLayout. Compact screens use two columns: the list and
-- the left items on the left, the footer (and the right header) on the right. Regular screens
-- keep the original sizes and positions of the left items and the right header.
function UiKit.bindDialog(gui: ScreenGui, parts: DialogParts, spec: UiTheme.DialogSpec)
	local originals: { [GuiObject]: { anchor: Vector2, position: UDim2, size: UDim2 } } = {}
	local function remember(item: GuiObject)
		originals[item] = { anchor = item.AnchorPoint, position = item.Position, size = item.Size }
	end
	local function place(item: GuiObject, placed: UiTheme.Box)
		item.AnchorPoint = Vector2.new(0, 0)
		item.Position = UDim2.fromOffset(placed.x, placed.y)
		item.Size = UDim2.fromOffset(placed.w, placed.h)
	end
	local function restore(item: GuiObject)
		local original = originals[item]
		if original then
			item.AnchorPoint = original.anchor
			item.Position = original.position
			item.Size = original.size
		end
	end
	local leftItems = parts.leftItems or {}
	for _, item in ipairs(leftItems) do
		remember(item)
	end
	if parts.rightHeader then
		remember(parts.rightHeader)
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
			restore(item)
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
				restore(header)
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

-- Rail --------------------------------------------------------------------------------------

local RAIL_BUTTON_HEIGHT = UiTheme.MinTouch
local railFrame: ScrollingFrame? = nil
local railLayout: UIListLayout? = nil
local railMetrics: UiTheme.Metrics? = nil
local railButtons: { TextButton } = {}
local railHidden = false

local function applyRail()
	local frame, listLayout, m = railFrame, railLayout, railMetrics
	if not (frame and listLayout and m) then
		return
	end
	listLayout.Padding = UDim.new(0, m.railGap)
	local visible = 0
	for _, railButton in ipairs(railButtons) do
		if railButton.Visible then
			visible += 1
		end
	end
	local layout = UiTheme.hudLayout(m, visible)
	frame.Position = UDim2.fromOffset(layout.rail.x, layout.rail.y)
	frame.Size = UDim2.fromOffset(layout.rail.w, layout.rail.h)
	frame.ScrollingEnabled = layout.railScrolls
	frame.Visible = not railHidden
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
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = frame
	railFrame = frame
	railLayout = listLayout
	UiKit.onLayout(gui, function(m)
		railMetrics = m
		applyRail()
	end)
	return frame
end

-- Rail slots: 10 LotManagerButton, 20 Shop, 30 Quests, 40 Advent, 50 SavesButton, 60 TeamButton,
-- 70 FinderButton. Buttons start hidden; the owner of a button shows it.
function UiKit.addRailButton(name: string, textKey: string, order: number): TextButton
	local frame = ensureRail()
	local railButton = UiKit.button(frame, name, UiKit.localized(textKey), colors.Sand)
	railButton.LayoutOrder = order
	railButton.Size = UDim2.new(1, -6, 0, RAIL_BUTTON_HEIGHT)
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
