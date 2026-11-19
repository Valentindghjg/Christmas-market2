--!strict
-- Minimal mobile-friendly UI; it only sends validated requests and renders responses.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction")

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
local cash = label(hud, "Cash: loading…", UDim2.fromOffset(16, 12), UDim2.fromOffset(240, 26), 20)
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
label(panel, "Tree Supplier", UDim2.fromOffset(18, 14), UDim2.fromOffset(300, 28), 22)
local detail =
	label(panel, "Frasier Fir · Medium · $32 wholesale", UDim2.fromOffset(18, 50), UDim2.fromOffset(320, 24), 15)

local order = Instance.new("TextButton")
order.Name = "OrderFrasier"
order.BackgroundColor3 = Color3.fromRGB(201, 153, 53)
order.Text = "Order 1 tree"
order.TextColor3 = Color3.fromRGB(30, 48, 35)
order.Font = Enum.Font.GothamBold
order.TextSize = 17
order.Position = UDim2.fromOffset(18, 94)
order.Size = UDim2.fromOffset(324, 58)
order.Parent = panel
Instance.new("UICorner", order).CornerRadius = UDim.new(0, 10)

local function updateReady()
	local ready = player:GetAttribute("CompanyReady")
	status.Text = ready and ("Plot: " .. tostring(player:GetAttribute("PlotId")))
		or ("Unavailable: " .. tostring(player:GetAttribute("CompanyLoadError") or "Loading"))
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
player:GetAttributeChangedSignal("CompanyLoadError"):Connect(updateReady)
player:GetAttributeChangedSignal("PlotId"):Connect(updateReady)
updateReady()

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
		cash.Text = string.format("Cash: $%d · Rep: %d", response.data.cash, response.data.reputation)
		local plot = response.data.plot
		if plot then
			status.Text =
				string.format("Plot: %s · Parking: %d", tostring(player:GetAttribute("PlotId")), plot.parkingSpaces)
		end
	end
end

task.spawn(function()
	while gui.Parent do
		refreshSummary()
		task.wait(5)
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
		order.Text = "Order 1 tree"
	end
end)
