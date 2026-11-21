--!strict
-- Minimal mobile-friendly UI; it only sends validated requests and renders responses.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction") :: RemoteFunction
local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Localization"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
-- Display only; the server computes the real refund.
local FRASIER_MEDIUM_REFUND =
	math.floor((GameConfig.wholesaleFor("FrasierFir", "Medium") or 0) * GameConfig.Supplier.SellBackFraction + 0.5)
local locale = string.lower(string.sub(LocalizationService.RobloxLocaleId, 1, 2))
if locale ~= "de" and locale ~= "en" then
	locale = "en"
end
local function localized(key: string): string
	return Localization.get(locale, key)
end
local function localizedFormat(key: string, ...: any): string
	return Localization.format(locale, key, ...)
end

-- Server error codes that have a player-facing translation.
local ERROR_KEYS = {
	InsufficientFunds = "insufficientFunds",
	ConnectionError = "connectionError",
	NoFreeBay = "noFreeBay",
	StorageFull = "storageFull",
	SupplierOutOfStock = "supplierOutOfStock",
	NotEnoughTrees = "notEnoughTrees",
	OutOfReach = "outOfReach",
	HandsFull = "handsFull",
}
local function errorText(errorCode: unknown): string
	if errorCode == "BayCapacity" then
		return localizedFormat("errorStatus", localizedFormat("bayCapacity", GameConfig.Receiving.BayCapacity))
	end
	local key = type(errorCode) == "string" and ERROR_KEYS[errorCode]
	return localizedFormat("errorStatus", if key then localized(key) else tostring(errorCode))
end

-- InvokeServer can throw (server error, disconnect); the UI must stay usable.
local function invoke(action: string, payload: { [string]: any })
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

local function button(name: string, color: Color3, position: UDim2, size: UDim2, textSize: number): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.BackgroundColor3 = color
	value.TextColor3 = Color3.fromRGB(30, 48, 35)
	value.Font = Enum.Font.GothamBold
	value.TextSize = textSize
	value.Position = position
	value.Size = size
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
local cash = label(
	hud,
	localized("cash") .. ": " .. localized("loading"),
	UDim2.fromOffset(16, 12),
	UDim2.fromOffset(240, 26),
	20
)
local status = label(hud, "Christmas Market 2", UDim2.fromOffset(16, 44), UDim2.fromOffset(240, 22), 14)

local panel = Instance.new("Frame")
panel.Name = "SupplierPanel"
panel.BackgroundColor3 = Color3.fromRGB(38, 89, 63)
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.fromScale(0.5, 0.97)
panel.Size = UDim2.fromOffset(360, 280)
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
label(panel, localized("supplier"), UDim2.fromOffset(18, 14), UDim2.fromOffset(300, 28), 22)
local detail = label(panel, "Frasier Fir · Medium", UDim2.fromOffset(18, 50), UDim2.fromOffset(320, 24), 15)

local order =
	button("OrderFrasier", Color3.fromRGB(201, 153, 53), UDim2.fromOffset(18, 94), UDim2.fromOffset(324, 45), 17)
order.Text = localized("placeOrder")
order.Parent = panel
Instance.new("UICorner", order).CornerRadius = UDim.new(0, 10)

local unload =
	button("UnloadDelivery", Color3.fromRGB(114, 172, 113), UDim2.fromOffset(18, 143), UDim2.fromOffset(324, 20), 14)
unload.Text = localized("noDeliveryReady")
unload.Visible = false
unload.Parent = panel

local place =
	button("PlaceFrasier", Color3.fromRGB(237, 212, 142), UDim2.fromOffset(18, 168), UDim2.fromOffset(324, 20), 14)
place.Visible = false
place.Parent = panel

-- G4/G5/G1 status lines and sell-back.
local supplierLine = label(panel, "", UDim2.fromOffset(18, 192), UDim2.fromOffset(324, 18), 13)
local receivingLine = label(panel, "", UDim2.fromOffset(18, 210), UDim2.fromOffset(324, 18), 13)
local customerLine = label(panel, "", UDim2.fromOffset(18, 228), UDim2.fromOffset(324, 18), 13)
local sellBack =
	button("SellBackFrasier", Color3.fromRGB(214, 186, 120), UDim2.fromOffset(18, 250), UDim2.fromOffset(324, 22), 13)
sellBack.Visible = false
sellBack.Parent = panel

local deliveredOrderId: string? = nil
local storedFrasierMedium = 0
local placementCount = 0
-- One in-flight request per button: a double tap must not place two orders.
local busy = { order = false, unload = false, place = false, sellBack = false }

local function refreshSupplierQuote()
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local response = invoke("Supplier.RequestQuote", { speciesId = "FrasierFir", sizeId = "Medium" })
	if response.ok and response.data then
		detail.Text = localizedFormat("wholesaleQuote", "Frasier Fir", "Medium", response.data.unitCost)
	end
end

local function updateReady()
	local ready = player:GetAttribute("CompanyReady")
	status.Text = if ready
		then localizedFormat("plotStatus", tostring(player:GetAttribute("PlotId")))
		else localizedFormat(
			"unavailable",
			tostring(player:GetAttribute("CompanyLoadError") or localized("loading"))
		)
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
	local response = invoke("Company.GetSummary", {})
	if not (response.ok and response.data) then
		return
	end
	local data = response.data
	cash.Text =
		string.format("%s: $%d · %s: %d", localized("cash"), data.cash, localized("reputation"), data.reputation)
	if data.plot then
		status.Text =
			localizedFormat("plotParkingStatus", tostring(player:GetAttribute("PlotId")), data.plot.parkingSpaces)
	end
	-- The server lists ready deliveries first.
	deliveredOrderId = nil
	for _, delivery in ipairs(data.deliveries or {}) do
		if delivery.status == "Delivered" then
			deliveredOrderId = delivery.orderId
			break
		end
	end
	unload.Visible = deliveredOrderId ~= nil
	unload.Text = localized(if deliveredOrderId then "unloadDelivery" else "noDeliveryReady")
	storedFrasierMedium = data.stock and (data.stock["FrasierFir:Medium"] or 0) or 0
	placementCount = data.placementCount or 0
	place.Visible = storedFrasierMedium > 0
	place.Text = localizedFormat("placeTree", "Frasier Fir", storedFrasierMedium)
	local supplier = data.supplier
	if supplier and supplier.stock then
		supplierLine.Text =
			localizedFormat("supplierStock", supplier.stock["FrasierFir:Medium"] or 0, supplier.refreshIn or 0)
	end
	local receiving = data.receiving
	if receiving then
		receivingLine.Text = localizedFormat(
			"receivingStatus",
			receiving.baysUsed,
			receiving.bayCount,
			receiving.storageUsed,
			receiving.storageCapacity
		)
	end
	local customers = data.customers
	if customers then
		customerLine.Text = localizedFormat(
			"customerStatus",
			customers.activeCustomers,
			customers.parkingSpaces,
			customers.loadedOrders,
			customers.missedPickups
		)
	end
	sellBack.Visible = storedFrasierMedium + placementCount > 0
	sellBack.Text = localizedFormat("sellBack", FRASIER_MEDIUM_REFUND)
end

sellBack.Activated:Connect(function()
	if busy.sellBack then
		return
	end
	busy.sellBack = true
	local response = invoke("Supplier.SellBack", { speciesId = "FrasierFir", sizeId = "Medium", quantity = 1 })
	detail.Text = if response.ok
		then localizedFormat("soldBack", response.data.refund)
		else errorText(response.errorCode)
	refreshSummary()
	busy.sellBack = false
end)

task.spawn(function()
	while gui.Parent do
		refreshSummary()
		task.wait(5)
	end
end)

place.Activated:Connect(function()
	if busy.place or storedFrasierMedium < 1 then
		return
	end
	busy.place = true
	local slot = placementCount % 5
	local response = invoke("Inventory.Place", {
		speciesId = "FrasierFir",
		sizeId = "Medium",
		transform = { x = -20 + slot * 10, y = 0, z = 8, rotation = 0 },
	})
	detail.Text = if response.ok then localized("treePlaced") else errorText(response.errorCode)
	refreshSummary()
	busy.place = false
end)

unload.Activated:Connect(function()
	if busy.unload or not deliveredOrderId then
		return
	end
	busy.unload = true
	local response = invoke("Delivery.Unload", { orderId = deliveredOrderId })
	detail.Text = if response.ok then localized("treesUnloaded") else errorText(response.errorCode)
	refreshSummary()
	busy.unload = false
end)

order.Activated:Connect(function()
	if busy.order then
		return
	end
	busy.order = true
	order.AutoButtonColor = false
	order.Text = localized("ordering")
	local response = invoke("Supplier.PlaceOrder", { speciesId = "FrasierFir", sizeId = "Medium", quantity = 1 })
	if response.ok then
		cash.Text = localizedFormat("orderAccepted", response.data.cost)
		detail.Text = localized("truckOnTheWay")
		order.Text = localized("placeOrder")
		refreshSummary()
	else
		order.Text = localized("orderUnavailable")
		status.Text = errorText(response.errorCode)
		task.delay(2, function()
			order.Text = localized("placeOrder")
		end)
	end
	order.AutoButtonColor = true
	busy.order = false
end)
