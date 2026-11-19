--!strict
-- Minimal mobile-friendly UI; it only sends validated requests and renders responses.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction")
local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local locale = string.lower(string.sub(LocalizationService.RobloxLocaleId, 1, 2))
if locale ~= "de" and locale ~= "en" then
	locale = "en"
end
local function localized(key: string): string
	return Localization.get(locale, key)
end

local gui = Instance.new("ScreenGui")
gui.Name = "ChristmasMarketUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Text = text
	value.TextColor3 = Color3.fromRGB(255, 244, 217)
	value.Font = Enum.Font.GothamBold
	value.TextSize = textSize
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Position = position
	value.Size = size
	value.Parent = parent
	return value
end

local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.BackgroundColor3 = Color3.fromRGB(20, 68, 48)
hud.BorderSizePixel = 0
hud.Position = UDim2.fromScale(0.02, 0.02)
hud.Size = UDim2.fromOffset(270, 84)
hud.Parent = gui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 12)
local cash = label(hud, localized("cash") .. ": loading…", UDim2.fromOffset(16, 12), UDim2.fromOffset(240, 26), 20)
local status = label(hud, "Christmas Market 2", UDim2.fromOffset(16, 44), UDim2.fromOffset(240, 22), 14)

local panel = Instance.new("Frame")
panel.Name = "SupplierPanel"
panel.BackgroundColor3 = Color3.fromRGB(38, 89, 63)
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.fromScale(0.5, 0.97)
panel.Size = UDim2.fromOffset(360, 176)
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
label(panel, localized("supplier"), UDim2.fromOffset(18, 14), UDim2.fromOffset(300, 28), 22)
local detail =
	label(panel, "Frasier Fir · Medium · $32 wholesale", UDim2.fromOffset(18, 50), UDim2.fromOffset(320, 24), 15)

local order = Instance.new("TextButton")
order.Name = "OrderFrasier"
order.BackgroundColor3 = Color3.fromRGB(201, 153, 53)
order.Text = localized("placeOrder")
order.TextColor3 = Color3.fromRGB(30, 48, 35)
order.Font = Enum.Font.GothamBold
order.TextSize = 17
order.Position = UDim2.fromOffset(18, 94)
order.Size = UDim2.fromOffset(324, 58)
order.Parent = panel
Instance.new("UICorner", order).CornerRadius = UDim.new(0, 10)

local unload = Instance.new("TextButton")
unload.Name = "UnloadDelivery"
unload.BackgroundColor3 = Color3.fromRGB(114, 172, 113)
unload.Text = "No delivery ready"
unload.TextColor3 = Color3.fromRGB(20, 48, 35)
unload.Font = Enum.Font.GothamBold
unload.TextSize = 14
unload.Position = UDim2.fromOffset(18, 152)
unload.Size = UDim2.fromOffset(324, 20)
unload.Visible = false
unload.Parent = panel
local deliveredOrderId: string? = nil

local function refreshSupplierQuote()
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local response = remote:InvokeServer({
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = "Supplier.RequestQuote",
		payload = { speciesId = "FrasierFir", sizeId = "Medium" },
	})
	if response.ok and response.data then
		detail.Text = string.format("Frasier Fir · Medium · $%d wholesale", response.data.unitCost)
	end
end

local function updateReady()
	local ready = player:GetAttribute("CompanyReady")
	status.Text = ready and ("Plot: " .. tostring(player:GetAttribute("PlotId")))
		or ("Unavailable: " .. tostring(player:GetAttribute("CompanyLoadError") or "Loading"))
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
player:GetAttributeChangedSignal("CompanyLoadError"):Connect(updateReady)
player:GetAttributeChangedSignal("PlotId"):Connect(updateReady)
updateReady()

player:GetAttributeChangedSignal("CompanyReady"):Connect(refreshSupplierQuote)
task.spawn(refreshSupplierQuote)

local function refreshSummary()
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local response = remote:InvokeServer({
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = "Company.GetSummary",
		payload = {},
	})
	if response.ok and response.data then
		cash.Text = string.format(
			"%s: $%d · %s: %d",
			localized("cash"),
			response.data.cash,
			localized("reputation"),
			response.data.reputation
		)
		local plot = response.data.plot
		if plot then
			status.Text =
				string.format("Plot: %s · Parking: %d", tostring(player:GetAttribute("PlotId")), plot.parkingSpaces)
		end
		deliveredOrderId = nil
		for _, delivery in ipairs(response.data.deliveries or {}) do
			if delivery.status == "Delivered" then
				deliveredOrderId = delivery.orderId
				break
			end
		end
		unload.Visible = deliveredOrderId ~= nil
		unload.Text = deliveredOrderId and "Unload delivered trees" or "No delivery ready"
	end
end

task.spawn(function()
	while gui.Parent do
		refreshSummary()
		task.wait(5)
	end
end)

unload.Activated:Connect(function()
	if not deliveredOrderId then
		return
	end
	local response = remote:InvokeServer({
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = "Delivery.Unload",
		payload = { orderId = deliveredOrderId },
	})
	if response.ok then
		detail.Text = "Trees unloaded into storage"
		refreshSummary()
	end
end)

order.Activated:Connect(function()
	order.Active = false
	order.Text = "Ordering…"
	local response = remote:InvokeServer({
		version = 1,
		requestId = HttpService:GenerateGUID(false),
		action = "Supplier.PlaceOrder",
		payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 1 },
	})
	if response.ok then
		cash.Text = "Order accepted: $" .. tostring(response.data.cost)
		detail.Text = "Truck is on the way"
		refreshSummary()
	else
		order.Text = "Order unavailable"
		status.Text = "Error: " .. tostring(response.errorCode)
	end
	order.Active = true
	if response.ok then
		order.Text = localized("placeOrder")
	end
end)
