--!strict
-- Localizes server-created world labels and prompts from their attributes, and shows
-- short server notifications (order complete, wrong car, out of reach). Presentation
-- only: every action stays a server-validated prompt or request.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreeHeight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeHeight"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

-- The locale rule lives in UiKit (one place for CM2-43).

local function number(instance: Instance, attribute: string): number
	local value = instance:GetAttribute(attribute)
	return if type(value) == "number" then value else 0
end

local function speciesName(speciesId: unknown): string
	local tree = type(speciesId) == "string" and GameConfig.Trees[speciesId]
	return if tree then tree.displayName else tostring(speciesId)
end

-- Bay counts as "a Small · b Medium · c Large" (promptStockObject) and the header form.
local function bayHeader(instance: Instance): string
	return UiKit.localizedFormat(
		"stockingHeader",
		speciesName(instance:GetAttribute("SpeciesId")),
		number(instance, "CountSmall"),
		number(instance, "CountMedium"),
		number(instance, "CountLarge")
	)
end

local function countdownText(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function localizeLabel(label: TextLabel)
	local kind = label:GetAttribute("LabelKind")
	if kind == "BayFree" then
		label.Text = UiKit.localized("bayFree")
	elseif kind == "BayArriving" then
		label.Text = UiKit.localizedFormat("bayArriving", countdownText(number(label, "ArrivesIn")))
	elseif kind == "BayContents" then
		label.Text = bayHeader(label)
	elseif kind == "DisplayTree" and label:GetAttribute("Reserved") == true then
		label.Text = UiKit.localized("treeReserved")
	elseif kind == "DisplayTree" then
		label.Text = UiKit.localizedFormat(
			"treeLabel",
			speciesName(label:GetAttribute("SpeciesId")),
			UiKit.localized("size" .. tostring(label:GetAttribute("SizeId"))),
			TreeHeight.feetText(number(label, "HeightTenths")),
			number(label, "Price")
		)
	elseif kind == "PickupOrder" then
		label.Text = UiKit.localizedFormat("pickupOrder", number(label, "OrderNumber"))
	elseif kind == "CarNumber" then
		label.Text = UiKit.localizedFormat("carNumber", number(label, "OrderNumber"))
	end
end

local function localizePrompt(prompt: ProximityPrompt)
	local kind = prompt:GetAttribute("PromptKind")
	local orderNumber = number(prompt, "OrderNumber")
	if kind == "StockBay" then
		prompt.ActionText = UiKit.localizedFormat("promptStock", speciesName(prompt:GetAttribute("SpeciesId")))
		prompt.ObjectText = UiKit.localizedFormat(
			"promptStockObject",
			number(prompt, "CountSmall"),
			number(prompt, "CountMedium"),
			number(prompt, "CountLarge")
		)
		return
	elseif kind == "CarryOrder" then
		prompt.ActionText = UiKit.localized("promptCarry")
	elseif kind == "LoadOrder" then
		prompt.ActionText = UiKit.localized("promptLoad")
	else
		return
	end
	prompt.ObjectText = UiKit.localizedFormat("promptObject", orderNumber)
end

-- Bay labels and stocking prompts change in place (CM2-G14), so they re-localize on every
-- attribute change; the connection is made once per instance.
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isBayLabel(label: TextLabel): boolean
	local kind = label:GetAttribute("LabelKind")
	return type(kind) == "string" and string.sub(kind, 1, 3) == "Bay"
end

local function visit(instance: Instance)
	if instance:IsA("TextLabel") and instance:GetAttribute("LabelKind") ~= nil then
		localizeLabel(instance)
		if isBayLabel(instance) and not watched[instance] then
			watched[instance] = true
			instance.AttributeChanged:Connect(function()
				localizeLabel(instance)
			end)
		end
	elseif instance:IsA("ProximityPrompt") and instance:GetAttribute("PromptKind") ~= nil then
		localizePrompt(instance)
		if instance:GetAttribute("PromptKind") == "StockBay" and not watched[instance] then
			watched[instance] = true
			instance.AttributeChanged:Connect(function()
				localizePrompt(instance)
			end)
		end
	end
end

-- Streaming can add world parts at any time, so watch for new descendants.
for _, descendant in workspace:GetDescendants() do
	visit(descendant)
end
workspace.DescendantAdded:Connect(visit)

-- Toast for server notifications { key = string, args = { number } }.
-- A transient overlay above every other screen; the HUD layout keeps it clear of the HUD and the rail.
local gui = UiKit.screenGui("ChristmasMarketNotifications", 30)
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.BackgroundColor3 = Color3.fromRGB(24, 74, 50)
toast.TextColor3 = UiKit.Colors.Cream
toast.Font = Enum.Font.GothamBold
toast.TextSize = UiTheme.TextSize.Body
toast.TextWrapped = true
toast.Visible = false
toast.Parent = gui
UiKit.corner(toast, UiTheme.CornerRadius.Row)
UiKit.onLayout(gui, function(m)
	local box = UiTheme.hudLayout(m, 0).toast
	toast.Position = UDim2.fromOffset(box.x, box.y)
	toast.Size = UDim2.fromOffset(box.w, box.h)
end)

local shownAt = 0
local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
notify.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.key) ~= "string" then
		return
	end
	local args = if type(message.args) == "table" then message.args else {}
	toast.Text = UiKit.localizedFormat(message.key, table.unpack(args))
	toast.Visible = true
	local token = os.clock()
	shownAt = token
	task.delay(3, function()
		if shownAt == token then
			toast.Visible = false
		end
	end)
end)
