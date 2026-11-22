--!strict
-- Localizes server-created world labels and prompts from their attributes, and shows
-- short server notifications (reviews, wrong car, out of reach). Presentation only: every
-- action stays a server-validated prompt or request.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")
local LabelDeclutter = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LabelDeclutter"))
local TreeHeight = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeHeight"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Reviews = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reviews"))
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
		local total = number(label, "CountSmall") + number(label, "CountMedium") + number(label, "CountLarge")
		local name = speciesName(label:GetAttribute("SpeciesId"))
		if total == 1 then
			label.Text = UiKit.localizedFormat("bayContentsOne", name)
		else
			label.Text = UiKit.localizedFormat("bayContents", name, total)
		end
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
	elseif kind == "NpcThanks" then
		label.Text = UiKit.localized("npcThanks")
	elseif kind == "LotSignName" then
		-- CM2-G15: a filtered save name stays as the server wrote it.
		local source = label:GetAttribute("NameSource")
		if source == "Free" then
			label.Text = UiKit.localized("lotSignFree")
		elseif source == "Default" then
			label.Text = UiKit.localized("lotSignDefault")
		elseif source == "Owner" then
			label.Text = UiKit.localizedFormat("lotSignOwnerLot", tostring(label:GetAttribute("OwnerName")))
		end
	elseif kind == "LotSignRating" then
		local tenths = label:GetAttribute("RatingTenths")
		if label:GetAttribute("Active") ~= true then
			label.Text = ""
		elseif number(label, "ReviewCount") == 0 or type(tenths) ~= "number" then
			label.Text = UiKit.localized("lotSignNoReviews")
		else
			label.Text = UiKit.localizedFormat("lotSignRating", string.format("%.1f", tenths / 10))
		end
	elseif kind == "LotSignLikes" then
		if label:GetAttribute("Active") ~= true then
			label.Text = ""
		else
			label.Text = UiKit.localizedFormat("lotSignLikes", number(label, "Likes"))
		end
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
	elseif kind == "Checkout" then
		-- CM2-N2: the counter prompt shows the tree of the customer at the counter.
		prompt.ActionText = UiKit.localized("promptCheckout")
		local speciesId = prompt:GetAttribute("SpeciesId")
		if type(speciesId) == "string" then
			prompt.ObjectText = UiKit.localizedFormat(
				"treeLabel",
				speciesName(speciesId),
				UiKit.localized("size" .. tostring(prompt:GetAttribute("SizeId"))),
				TreeHeight.feetText(number(prompt, "HeightTenths")),
				number(prompt, "Price")
			)
		else
			prompt.ObjectText = ""
		end
		return
	elseif kind == "CarryOrder" then
		prompt.ActionText = UiKit.localized("promptCarry")
	elseif kind == "LoadOrder" then
		prompt.ActionText = UiKit.localized("promptLoad")
	elseif kind == "LikeLot" then
		prompt.ActionText = UiKit.localized("promptLike")
		prompt.ObjectText = UiKit.localized("promptLikeObject")
		return
	else
		return
	end
	prompt.ObjectText = UiKit.localizedFormat("promptObject", orderNumber)
end

-- Bay labels, stocking prompts (CM2-G14), the checkout prompt (CM2-N2) and the lot sign
-- (CM2-G15) change in place, so they re-localize on every attribute change; the connection is
-- made once per instance.
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isLiveLabel(label: TextLabel): boolean
	local kind = label:GetAttribute("LabelKind")
	return type(kind) == "string" and (string.sub(kind, 1, 3) == "Bay" or string.sub(kind, 1, 7) == "LotSign")
end

-- CM2-UVF2: every world billboard is registered here and shown or hidden by the declutter pass. Strong keys: a weak Instance key is dropped once no Luau reference remains (CM2-UVF2-D1); the pass prunes guis that left workspace.
local labelGuis: { [BillboardGui]: boolean } = {}

local function visit(instance: Instance)
	if instance:IsA("TextLabel") and instance:GetAttribute("LabelKind") ~= nil then
		local parent = instance.Parent
		if parent and parent:IsA("BillboardGui") then
			labelGuis[parent] = true
			-- CM2-UVF7: the client owns the draw distance; the engine's MaxDistance is not measured from the camera position.
			if type(parent:GetAttribute("LabelRange")) ~= "number" then
				parent:SetAttribute("LabelRange", parent.MaxDistance)
				parent.MaxDistance = math.huge
			end
			parent.Enabled = false
		end
		localizeLabel(instance)
		if isLiveLabel(instance) and not watched[instance] then
			watched[instance] = true
			instance.AttributeChanged:Connect(function()
				localizeLabel(instance)
			end)
		end
	elseif instance:IsA("ProximityPrompt") and instance:GetAttribute("PromptKind") ~= nil then
		localizePrompt(instance)
		local kind = instance:GetAttribute("PromptKind")
		if (kind == "StockBay" or kind == "Checkout") and not watched[instance] then
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

-- Declutter pass at 10 Hz (CM2-UVF2, CM2-UVF7): hides labels beyond their LabelRange (camera distance) or behind the camera, then hides a label whose screen box overlaps a better one. No Instances are created.
local passClock = 0
RunService.RenderStepped:Connect(function(dt: number)
	passClock += dt
	if passClock < LabelDeclutter.IntervalSeconds then
		return
	end
	passClock = 0
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local guis: { BillboardGui } = {}
	local candidates: { LabelDeclutter.Candidate } = {}
	local tracked = 0
	for gui in pairs(labelGuis) do
		if not gui:IsDescendantOf(workspace) then
			labelGuis[gui] = nil
			continue
		end
		tracked += 1
		local adornee = gui.Adornee
		local label = gui:FindFirstChild("Text")
		if adornee == nil or not adornee:IsA("BasePart") or label == nil or not label:IsA("TextLabel") then
			continue
		end
		local point = adornee.Position + gui.StudsOffsetWorldSpace
		local viewport = camera:WorldToViewportPoint(point)
		local rangeAttribute = gui:GetAttribute("LabelRange")
		local width, height = gui.Size.X.Offset, gui.Size.Y.Offset
		table.insert(guis, gui)
		table.insert(candidates, {
			box = { x = viewport.X - width / 2, y = viewport.Y - height / 2, w = width, h = height },
			priority = LabelDeclutter.priorityFor(
				label:GetAttribute("LabelKind"),
				label:GetAttribute("Reserved") == true
			),
			depth = viewport.Z,
			shown = gui.Enabled,
			distance = (point - camera.CFrame.Position).Magnitude,
			range = if type(rangeAttribute) == "number" then rangeAttribute else gui.MaxDistance,
		})
	end
	local result = LabelDeclutter.decide(candidates)
	local hidden, culled = 0, 0
	for index, gui in ipairs(guis) do
		local candidate = candidates[index]
		if not LabelDeclutter.inRange(candidate.distance, candidate.range, candidate.depth) then
			culled += 1
		elseif not result[index] then
			hidden += 1
		end
		if gui.Enabled ~= result[index] then
			gui.Enabled = result[index]
		end
	end
	script:SetAttribute("DeclutterTracked", tracked)
	script:SetAttribute("DeclutterHidden", hidden)
	script:SetAttribute("DeclutterCulled", culled)
end)

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
local function showToast(text: string)
	toast.Text = text
	toast.Visible = true
	local token = os.clock()
	shownAt = token
	task.delay(3, function()
		if shownAt == token then
			toast.Visible = false
		end
	end)
end

local notify = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent
notify.OnClientEvent:Connect(function(message)
	if type(message) ~= "table" or type(message.key) ~= "string" then
		return
	end
	local args = if type(message.args) == "table" then message.args else {}
	-- CM2-G15: a review's first argument is its star count, shown as stars.
	if Reviews.TextKeys[message.key] then
		args[1] = Reviews.starText(args[1])
	end
	showToast(UiKit.localizedFormat(message.key, table.unpack(args)))
end)

-- Lot sign likes (CM2-G15): the prompt sends Lot.Like; the server checks everything.
local businessAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction") :: RemoteFunction
local LIKE_ERROR_KEYS = {
	AlreadyLikedToday = "likeAlreadyToday",
	OwnLot = "likeOwnLot",
	OutOfReach = "outOfReach",
}
local likeInFlight = false
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
	if player ~= Players.LocalPlayer or prompt:GetAttribute("PromptKind") ~= "LikeLot" then
		return
	end
	local plotId = prompt:GetAttribute("PlotId")
	if type(plotId) ~= "string" or likeInFlight then
		return
	end
	likeInFlight = true
	local response = UiKit.request(businessAction, "Lot.Like", { plotId = plotId })
	likeInFlight = false
	if response.ok then
		showToast(UiKit.localized("likeSent"))
	else
		showToast(UiKit.localized(LIKE_ERROR_KEYS[response.errorCode] or "likeUnavailable"))
	end
end)
