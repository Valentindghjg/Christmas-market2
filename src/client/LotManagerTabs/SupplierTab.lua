--!strict
-- Supplier tab of the Lot Manager (CM2-40): order trees, unload deliveries, place and sell back
-- trees. Moved from UiController unchanged in behaviour; every request goes through the tab
-- context (BusinessAction) and the server owns costs and results.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit") :: ModuleScript)

type TabContext = {
	request: (action: string, payload: { [string]: any }) -> any,
	refresh: () -> (),
	summary: () -> any?,
}
type TabHandle = {
	render: (summary: any?) -> (),
	shown: ((visible: boolean) -> ())?,
}

local SupplierTab = {}

-- Supplier rows follow the OBSERVED order; prices shown come from the server summary.
local SPECIES_ORDER = GameConfig.SpeciesOrder
local UNLOAD_GREEN = Color3.fromRGB(114, 172, 113)
local SELL_BACK_SAND = Color3.fromRGB(214, 186, 120)

local function speciesName(speciesId: string): string
	local tree = GameConfig.Trees[speciesId]
	return if tree then tree.displayName else speciesId
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
		return UiKit.localizedFormat(
			"errorStatus",
			UiKit.localizedFormat("bayCapacity", GameConfig.Receiving.BayCapacity)
		)
	end
	local key = type(errorCode) == "string" and ERROR_KEYS[errorCode]
	return UiKit.localizedFormat("errorStatus", if key then UiKit.localized(key) else tostring(errorCode))
end

function SupplierTab.create(page: ScrollingFrame, context: TabContext): TabHandle
	local colors = UiKit.Colors
	local localized = UiKit.localized
	local localizedFormat = UiKit.localizedFormat

	page.CanvasSize = UDim2.fromOffset(0, 450)

	local titleLabel = UiKit.label(page, "SupplierTitle", localized("supplier"), 22)
	titleLabel.Position = UDim2.fromOffset(0, 0)
	titleLabel.Size = UDim2.fromOffset(324, 28)
	local legend = UiKit.label(page, "SupplierLegend", localized("supplierPriceLegend"), 12)
	legend.Position = UDim2.fromOffset(0, 32)
	legend.Size = UDim2.fromOffset(324, 16)

	local selectedSpecies = SPECIES_ORDER[1]
	local speciesButtons: { [string]: TextButton } = {}
	local speciesStrokes: { [string]: UIStroke } = {}
	for index, speciesId in ipairs(SPECIES_ORDER) do
		local column = (index - 1) % 2
		local row = (index - 1) // 2
		local choice = UiKit.button(page, "Species_" .. speciesId, speciesName(speciesId), colors.Sand, 13)
		choice.Position = UDim2.fromOffset(column * 164, 54 + row * 48)
		choice.Size = UDim2.fromOffset(160, 44)
		-- The outline marks the selection, so it is not shown by colour alone.
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Selected"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = colors.Cream
		stroke.Parent = choice
		speciesButtons[speciesId] = choice
		speciesStrokes[speciesId] = stroke
	end
	local function updateSelection()
		for speciesId, choice in pairs(speciesButtons) do
			local selected = speciesId == selectedSpecies
			choice.BackgroundColor3 = if selected then colors.Gold else colors.Sand
			speciesStrokes[speciesId].Enabled = selected
		end
	end
	updateSelection()

	local detail = UiKit.label(page, "SupplierDetail", localized("loading"), 15)
	detail.Position = UDim2.fromOffset(0, 152)
	detail.Size = UDim2.fromOffset(324, 24)

	local order = UiKit.button(page, "OrderTrees", localized("placeOrder"), colors.Gold, 17)
	order.Position = UDim2.fromOffset(0, 182)
	order.Size = UDim2.fromOffset(324, 44)

	local unload = UiKit.button(page, "UnloadDelivery", localized("noDeliveryReady"), UNLOAD_GREEN, 14)
	unload.Position = UDim2.fromOffset(0, 234)
	unload.Size = UDim2.fromOffset(324, 44)
	unload.Visible = false

	local place = UiKit.button(page, "PlaceTree", "", colors.Sand, 14)
	place.Position = UDim2.fromOffset(0, 286)
	place.Size = UDim2.fromOffset(324, 44)
	place.Visible = false

	-- G4/G5/G1 status lines and sell-back.
	local supplierLine = UiKit.label(page, "SupplierLine", "", 13)
	supplierLine.Position = UDim2.fromOffset(0, 338)
	supplierLine.Size = UDim2.fromOffset(324, 18)
	local receivingLine = UiKit.label(page, "ReceivingLine", "", 13)
	receivingLine.Position = UDim2.fromOffset(0, 356)
	receivingLine.Size = UDim2.fromOffset(324, 18)
	local customerLine = UiKit.label(page, "CustomerLine", "", 13)
	customerLine.Position = UDim2.fromOffset(0, 374)
	customerLine.Size = UDim2.fromOffset(324, 18)
	local sellBack = UiKit.button(page, "SellBackTree", "", SELL_BACK_SAND, 13)
	sellBack.Position = UDim2.fromOffset(0, 398)
	sellBack.Size = UDim2.fromOffset(324, 44)
	sellBack.Visible = false

	local deliveredOrderId: string? = nil
	local storedSelectedMedium = 0
	local lastSummary: any = nil
	local placementCount = 0
	-- One in-flight request per button: a double tap must not place two orders.
	local busy = { order = false, unload = false, place = false, sellBack = false }

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
			supplierLine.Text =
				localizedFormat("supplierStock", supplier.stock[mediumKey()] or 0, supplier.refreshIn or 0)
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
		local response =
			context.request("Supplier.SellBack", { speciesId = speciesId, sizeId = "Medium", quantity = 1 })
		detail.Text = if response.ok
			then localizedFormat("soldBack", response.data.refund)
			else errorText(response.errorCode)
		context.refresh()
		busy.sellBack = false
	end)

	place.Activated:Connect(function()
		if busy.place or storedSelectedMedium < 1 then
			return
		end
		busy.place = true
		local speciesId = selectedSpecies
		-- Two rows of four east of the sales stand: clear of the stand, checkout, pickup row and parking.
		local slot = placementCount % 8
		local response = context.request("Inventory.Place", {
			speciesId = speciesId,
			sizeId = "Medium",
			transform = { x = 14 + (slot % 4) * 7, y = 0, z = -3 + (slot // 4) * 8, rotation = 0 },
		})
		detail.Text = if response.ok then localized("treePlaced") else errorText(response.errorCode)
		context.refresh()
		busy.place = false
	end)

	unload.Activated:Connect(function()
		if busy.unload or not deliveredOrderId then
			return
		end
		busy.unload = true
		local response = context.request("Delivery.Unload", { orderId = deliveredOrderId })
		detail.Text = if response.ok then localized("treesUnloaded") else errorText(response.errorCode)
		context.refresh()
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
		local response =
			context.request("Supplier.PlaceOrder", { speciesId = speciesId, sizeId = "Medium", quantity = 1 })
		if response.ok then
			detail.Text = localizedFormat("orderAcceptedTruck", response.data.cost)
			order.Text = localized("placeOrder")
			context.refresh()
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

	local function render(summary: any?)
		if summary == nil then
			-- No data: a switched save starts from its own summary, never the previous one.
			lastSummary = nil
			deliveredOrderId = nil
			storedSelectedMedium = 0
			placementCount = 0
			unload.Visible = false
			place.Visible = false
			sellBack.Visible = false
			detail.Text = localized("loading")
			return
		end
		local first = lastSummary == nil
		lastSummary = summary
		renderSummary(summary)
		if first then
			showSelectedQuote()
		end
	end

	return { render = render }
end

return SupplierTab
