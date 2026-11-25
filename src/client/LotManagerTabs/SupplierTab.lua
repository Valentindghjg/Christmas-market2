--!strict
-- Supplier tab of the Lot Manager (CM2-40): order and sell back trees. Deliveries land in a
-- receiving bay by themselves and are stocked at the bay (CM2-G14, StockingMode.client.lua).
-- Every request goes through the tab context (BusinessAction) and the server owns costs and results.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit") :: ModuleScript)
local UiTheme = require(Shared:WaitForChild("UiTheme"))

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

	local order = UiKit.button(page, "OrderTrees", localized("placeOrder"), colors.Gold, 17)

	-- CM2-G14: deliveries land in a bay by themselves; stocking happens at the bay.
	local stockingHint = UiKit.label(page, "StockingHint", localized("supplierStockingHint"), 13)
	stockingHint.TextWrapped = true
	stockingHint.TextTruncate = Enum.TextTruncate.None

	-- G4/G5/G1 status lines and sell-back.
	local supplierLine = UiKit.label(page, "SupplierLine", "", 13)
	local receivingLine = UiKit.label(page, "ReceivingLine", "", 13)
	local customerLine = UiKit.label(page, "CustomerLine", "", 13)
	local sellBack = UiKit.button(page, "SellBackTree", "", SELL_BACK_SAND, 13)
	sellBack.Visible = false

	-- CM2-UVF11: boxes come from UiTheme.supplierLayout and follow the screen size.
	local function place(item: GuiObject, placed: UiTheme.Box)
		item.Position = UDim2.fromOffset(placed.x, placed.y)
		item.Size = UDim2.fromOffset(placed.w, placed.h)
	end
	local function applyLayout(m: UiTheme.Metrics)
		local layout = UiTheme.supplierLayout(m, page.AbsoluteSize.X)
		page.CanvasSize = UDim2.fromOffset(0, layout.canvasHeight)
		place(detail, layout.detail)
		detail.TextWrapped = layout.twoColumns
		detail.TextTruncate = if layout.twoColumns then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
		place(order, layout.order)
		place(stockingHint, layout.stockingHint)
		place(supplierLine, layout.supplierLine)
		place(receivingLine, layout.receivingLine)
		place(customerLine, layout.customerLine)
		place(sellBack, layout.sellBack)
	end
	local gui = page:FindFirstAncestorOfClass("ScreenGui")
	if gui then
		UiKit.onLayout(gui, applyLayout)
		page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			applyLayout(UiTheme.metrics(gui.AbsoluteSize.X, gui.AbsoluteSize.Y))
		end)
	else
		applyLayout(UiTheme.metrics(1920, 1080))
	end

	local storedSelectedMedium = 0
	local lastSummary: any = nil
	local placementCount = 0
	-- One in-flight request per button: a double tap must not place two orders.
	local busy = { order = false, sellBack = false }

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
		storedSelectedMedium = data.stock and (data.stock[mediumKey()] or 0) or 0
		placementCount = data.placementCount or 0
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
			storedSelectedMedium = 0
			placementCount = 0
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
