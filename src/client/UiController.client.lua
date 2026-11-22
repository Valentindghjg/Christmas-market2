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
-- Supplier rows follow the OBSERVED order; prices shown come from the server summary.
local SPECIES_ORDER = GameConfig.SpeciesOrder
local function speciesName(speciesId: string): string
	local tree = GameConfig.Trees[speciesId]
	return if tree then tree.displayName else speciesId
end
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
panel.Size = UDim2.fromOffset(360, 388)
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
label(panel, localized("supplier"), UDim2.fromOffset(18, 14), UDim2.fromOffset(300, 28), 22)
label(panel, localized("supplierPriceLegend"), UDim2.fromOffset(18, 44), UDim2.fromOffset(324, 16), 12)

local selectedSpecies = SPECIES_ORDER[1]
local speciesButtons: { [string]: TextButton } = {}
local speciesStrokes: { [string]: UIStroke } = {}
for index, speciesId in ipairs(SPECIES_ORDER) do
	local column = (index - 1) % 2
	local row = (index - 1) // 2
	local choice = button(
		"Species_" .. speciesId,
		Color3.fromRGB(237, 212, 142),
		UDim2.fromOffset(18 + column * 164, 62 + row * 48),
		UDim2.fromOffset(160, 44),
		13
	)
	choice.Text = speciesName(speciesId)
	choice.TextWrapped = true
	choice.Parent = panel
	Instance.new("UICorner", choice).CornerRadius = UDim.new(0, 8)
	-- The outline marks the selection, so it is not shown by colour alone.
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Selected"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 244, 217)
	stroke.Parent = choice
	speciesButtons[speciesId] = choice
	speciesStrokes[speciesId] = stroke
end
local function updateSelection()
	for speciesId, choice in pairs(speciesButtons) do
		local selected = speciesId == selectedSpecies
		choice.BackgroundColor3 = if selected then Color3.fromRGB(201, 153, 53) else Color3.fromRGB(237, 212, 142)
		speciesStrokes[speciesId].Enabled = selected
	end
end
updateSelection()

local detail = label(panel, localized("loading"), UDim2.fromOffset(18, 158), UDim2.fromOffset(324, 24), 15)

local order =
	button("OrderTrees", Color3.fromRGB(201, 153, 53), UDim2.fromOffset(18, 202), UDim2.fromOffset(324, 45), 17)
order.Text = localized("placeOrder")
order.Parent = panel
Instance.new("UICorner", order).CornerRadius = UDim.new(0, 10)

local unload =
	button("UnloadDelivery", Color3.fromRGB(114, 172, 113), UDim2.fromOffset(18, 251), UDim2.fromOffset(324, 20), 14)
unload.Text = localized("noDeliveryReady")
unload.Visible = false
unload.Parent = panel

local place =
	button("PlaceTree", Color3.fromRGB(237, 212, 142), UDim2.fromOffset(18, 276), UDim2.fromOffset(324, 20), 14)
place.Visible = false
place.Parent = panel

-- G4/G5/G1 status lines and sell-back.
local supplierLine = label(panel, "", UDim2.fromOffset(18, 300), UDim2.fromOffset(324, 18), 13)
local receivingLine = label(panel, "", UDim2.fromOffset(18, 318), UDim2.fromOffset(324, 18), 13)
local customerLine = label(panel, "", UDim2.fromOffset(18, 336), UDim2.fromOffset(324, 18), 13)
local sellBack =
	button("SellBackTree", Color3.fromRGB(214, 186, 120), UDim2.fromOffset(18, 358), UDim2.fromOffset(324, 22), 13)
sellBack.Visible = false
sellBack.Parent = panel

local deliveredOrderId: string? = nil
local storedSelectedMedium = 0
local lastSummary: any = nil
local placementCount = 0
-- One in-flight request per button: a double tap must not place two orders.
local busy = { order = false, unload = false, place = false, sellBack = false }

-- CM2-R3: the HUD says which save runs, why it stopped, or that one must be chosen.
local function updateReady()
	local ready = player:GetAttribute("CompanyReady") == true
	local errorCode = player:GetAttribute("CompanyError")
	if ready then
		status.Text = localizedFormat(
			"hudSaveStatus",
			tostring(player:GetAttribute("ActiveSaveName") or ""),
			tostring(player:GetAttribute("PlotId"))
		)
	elseif errorCode ~= nil then
		status.Text = localized(Localization.saveErrorKey(errorCode))
	elseif player:GetAttribute("ActiveSaveId") == nil then
		status.Text = localized("hudChooseSave")
	else
		status.Text = localized("saveLoading")
	end
	-- The supplier panel only works on a running save.
	panel.Visible = ready
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
player:GetAttributeChangedSignal("CompanyError"):Connect(updateReady)
player:GetAttributeChangedSignal("ActiveSaveId"):Connect(updateReady)
player:GetAttributeChangedSignal("ActiveSaveName"):Connect(updateReady)
player:GetAttributeChangedSignal("PlotId"):Connect(updateReady)
updateReady()

local function mediumKey(): string
	return selectedSpecies .. ":Medium"
end

local function serverWholesale(key: string): number?
	local supplier = lastSummary and lastSummary.supplier
	local prices = supplier and supplier.wholesale
	local value = prices and prices[key]
	return if type(value) == "number" then value else nil
end

local function showSelectedQuote()
	local unitCost = serverWholesale(mediumKey())
	detail.Text = if unitCost
		then localizedFormat("wholesaleQuote", speciesName(selectedSpecies), localized("sizeMedium"), unitCost)
		else localized("loading")
end

local function renderSummary(data: any)
	cash.Text =
		string.format("%s: $%d · %s: %d", localized("cash"), data.cash, localized("reputation"), data.reputation)
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
	storedSelectedMedium = data.stock and (data.stock[mediumKey()] or 0) or 0
	placementCount = data.placementCount or 0
	place.Visible = storedSelectedMedium > 0
	place.Text = localizedFormat("placeTree", speciesName(selectedSpecies), storedSelectedMedium)
	local supplier = data.supplier
	if supplier and supplier.stock then
		supplierLine.Text = localizedFormat("supplierStock", supplier.stock[mediumKey()] or 0, supplier.refreshIn or 0)
	end
	if supplier and supplier.wholesale then
		local prices = supplier.wholesale
		for speciesId, choice in pairs(speciesButtons) do
			choice.Text = localizedFormat(
				"supplierSpeciesRow",
				speciesName(speciesId),
				prices[speciesId .. ":Small"] or 0,
				prices[speciesId .. ":Medium"] or 0,
				prices[speciesId .. ":Large"] or 0
			)
		end
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
	local refund =
		math.floor((serverWholesale(mediumKey()) or 0) * ((supplier and supplier.sellBackFraction) or 0) + 0.5)
	sellBack.Visible = storedSelectedMedium + placementCount > 0
	sellBack.Text = localizedFormat("sellBack", refund)
end

local function refreshSummary()
	if player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local response = invoke("Company.GetSummary", {})
	if not (response.ok and response.data) then
		return
	end
	local first = lastSummary == nil
	lastSummary = response.data
	renderSummary(response.data)
	if first then
		showSelectedQuote()
	end
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(refreshSummary)
-- A switched save starts from its own summary, never the previous save's figures.
player:GetAttributeChangedSignal("ActiveSaveId"):Connect(function()
	lastSummary = nil
	refreshSummary()
end)

for speciesId, choice in pairs(speciesButtons) do
	choice.Activated:Connect(function()
		selectedSpecies = speciesId
		updateSelection()
		showSelectedQuote()
		if lastSummary then
			renderSummary(lastSummary)
		end
	end)
end

sellBack.Activated:Connect(function()
	if busy.sellBack then
		return
	end
	busy.sellBack = true
	local speciesId = selectedSpecies
	local response = invoke("Supplier.SellBack", { speciesId = speciesId, sizeId = "Medium", quantity = 1 })
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
	if busy.place or storedSelectedMedium < 1 then
		return
	end
	busy.place = true
	local speciesId = selectedSpecies
	-- Two rows of four east of the sales stand: clear of the stand, checkout, pickup row and parking.
	local slot = placementCount % 8
	local response = invoke("Inventory.Place", {
		speciesId = speciesId,
		sizeId = "Medium",
		transform = { x = 14 + (slot % 4) * 7, y = 0, z = -3 + (slot // 4) * 8, rotation = 0 },
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
	local speciesId = selectedSpecies
	local response = invoke("Supplier.PlaceOrder", { speciesId = speciesId, sizeId = "Medium", quantity = 1 })
	if response.ok then
		cash.Text = localizedFormat("orderAccepted", response.data.cost)
		detail.Text = localized("truckOnTheWay")
		order.Text = localized("placeOrder")
		refreshSummary()
	else
		order.Text = localized("orderUnavailable")
		detail.Text = errorText(response.errorCode)
		task.delay(2, function()
			order.Text = localized("placeOrder")
		end)
	end
	order.AutoButtonColor = true
	busy.order = false
end)
