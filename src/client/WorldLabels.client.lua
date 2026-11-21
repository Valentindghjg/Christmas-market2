--!strict
-- Localizes server-created world labels and prompts from their attributes, and shows
-- short server notifications (order complete, wrong car, out of reach). Presentation
-- only: every action stays a server-validated prompt or request.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local TreeHeight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeHeight"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local locale = string.lower(string.sub(LocalizationService.RobloxLocaleId, 1, 2))
if locale ~= "de" and locale ~= "en" then
	locale = "en"
end

local function number(instance: Instance, attribute: string): number
	local value = instance:GetAttribute(attribute)
	return if type(value) == "number" then value else 0
end

local function speciesName(speciesId: unknown): string
	local tree = type(speciesId) == "string" and GameConfig.Trees[speciesId]
	return if tree then tree.displayName else tostring(speciesId)
end

local function localizeLabel(label: TextLabel)
	local kind = label:GetAttribute("LabelKind")
	if kind == "DisplayTree" then
		label.Text = Localization.format(
			locale,
			"treeLabel",
			speciesName(label:GetAttribute("SpeciesId")),
			Localization.get(locale, "size" .. tostring(label:GetAttribute("SizeId"))),
			TreeHeight.feetText(number(label, "HeightTenths")),
			number(label, "Price")
		)
	elseif kind == "PickupOrder" then
		label.Text = Localization.format(locale, "pickupOrder", number(label, "OrderNumber"))
	elseif kind == "CarNumber" then
		label.Text = Localization.format(locale, "carNumber", number(label, "OrderNumber"))
	end
end

local function localizePrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("PromptKind")
	local orderNumber = number(prompt, "OrderNumber")
	if kind == "CarryOrder" then
		prompt.ActionText = Localization.get(locale, "promptCarry")
	elseif kind == "LoadOrder" then
		prompt.ActionText = Localization.get(locale, "promptLoad")
	else
		return
	end
	prompt.ObjectText = Localization.format(locale, "promptObject", orderNumber)
end

local function visit(instance: Instance)
	if instance:IsA("TextLabel") and instance:GetAttribute("LabelKind") ~= nil then
		localizeLabel(instance)
	elseif instance:IsA("ProximityPrompt") and instance:GetAttribute("PromptKind") ~= nil then
		localizePrompt(instance)
	end
end

-- Streaming can add world parts at any time, so watch for new descendants.
for _, descendant in workspace:GetDescendants() do
	visit(descendant)
end
workspace.DescendantAdded:Connect(visit)

-- Toast for server notifications { key = string, args = { number } }.
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "ChristmasMarketNotifications"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.08)
toast.Size = UDim2.fromOffset(460, 44)
toast.BackgroundColor3 = Color3.fromRGB(24, 74, 50)
toast.TextColor3 = Color3.fromRGB(255, 244, 217)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)

local shownAt = 0
local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
notify.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.key) ~= "string" then
		return
	end
	local args = if type(message.args) == "table" then message.args else {}
	toast.Text = Localization.format(locale, message.key, table.unpack(args))
	toast.Visible = true
	local token = os.clock()
	shownAt = token
	task.delay(3, function()
		if shownAt == token then
			toast.Visible = false
		end
	end)
end)
