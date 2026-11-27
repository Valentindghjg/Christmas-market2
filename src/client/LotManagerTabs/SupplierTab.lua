--!strict
-- Supplier tab of the Lot Manager (CM2-SUP, docs/plans/CM2-SUP.md): a buy view with one row per
-- species and size, a cart ("Your order") placed as one atomic server order, a one-click
-- recommended order, and a sell-back view per species and size. Deliveries land in receiving
-- bays by themselves and are stocked at the bay (CM2-G14, StockingMode.client.lua).
-- Every request goes through the tab context (BusinessAction); the server owns costs and
-- results. MAX and the cart math here are convenience only; the server re-checks everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Inventory = require(Shared:WaitForChild("Inventory"))
local SupplierCart = require(Shared:WaitForChild("SupplierCart"))
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
type Row = {
	key: string,
	speciesId: string,
	sizeId: string,
	frame: Frame,
	name: TextLabel,
	info: TextLabel,
	qty: TextLabel,
	minus: TextButton,
	plus: TextButton,
	max: TextButton,
	sell: TextButton,
}

local SupplierTab = {}

local SIZE_KEYS = { Small = "sizeSmall", Medium = "sizeMedium", Large = "sizeLarge" }
local DISABLED_TRANSPARENCY = 0.45
local CART_PREVIEW_LINES = 3

local function speciesName(speciesId: string): string
	local tree = GameConfig.Trees[speciesId]
	return if tree then tree.displayName else speciesId
end

local function sizeName(sizeId: string): string
	local key = SIZE_KEYS[sizeId]
	return if key then UiKit.localized(key) else sizeId
end

local function number(value: unknown): number
	return if type(value) == "number" and value == value then value else 0
end

local function sellBackPercent(): number
	return math.floor(GameConfig.Supplier.SellBackFraction * 100)
end

-- Server error codes that have a player-facing translation.
local ERROR_KEYS = {
	InsufficientFunds = "insufficientFunds",
	ConnectionError = "connectionError",
	StorageFull = "storageFull",
	SupplierOutOfStock = "supplierOutOfStock",
	NotEnoughTrees = "notEnoughTrees",
	OutOfReach = "outOfReach",
	HandsFull = "handsFull",
	-- The cart codes (SupplierCart.normalize) and the open-order limit.
	InvalidCart = "orderUnavailable",
	UnexpectedField = "orderUnavailable",
	InvalidItem = "orderUnavailable",
	InvalidQuantity = "orderUnavailable",
	DuplicateLine = "orderUnavailable",
	TooManyOpenOrders = "orderUnavailable",
}

function SupplierTab.create(page: ScrollingFrame, context: TabContext): TabHandle
	local colors = UiKit.Colors
	local localized = UiKit.localized
	local localizedFormat = UiKit.localizedFormat

	local mode = "Buy"
	local cart: { [string]: number } = {}
	local sellQty: { [string]: number } = {}
	local lastSummary: any = nil
	-- One in-flight request per action: a double tap must not place two orders.
	local busy = { order = false, sell = false }
	local refreshDeadline: number? = nil
	local statusText = ""
	local metrics: UiTheme.Metrics = UiTheme.metrics(1920, 1080)
	local enabledState: { [TextButton]: boolean } = {}

	local function setEnabled(button: TextButton, enabled: boolean)
		enabledState[button] = enabled
		button.AutoButtonColor = enabled
		button.TextTransparency = if enabled then 0 else DISABLED_TRANSPARENCY
	end
	local function isEnabled(button: TextButton): boolean
		return enabledState[button] == true
	end

	local function modeButton(name: string, text: string): (TextButton, UIStroke)
		local button = UiKit.button(page, name, text, colors.Sand, 13)
		-- The outline marks the active view, so it is not shown by colour alone.
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Selected"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 3
		stroke.Color = colors.Cream
		stroke.Parent = button
		return button, stroke
	end
	local modeBuy, modeBuyStroke = modeButton("ModeBuy", localized("supplierModeBuy"))
	local modeSell, modeSellStroke = modeButton("ModeSell", localizedFormat("supplierModeSell", sellBackPercent()))
	local refreshLabel = UiKit.label(page, "RefreshLabel", "", 13)
	refreshLabel.TextXAlignment = Enum.TextXAlignment.Right

	local orderButton = UiKit.button(page, "OrderTrees", localized("placeOrder"), colors.Gold, 15)
	local clearButton = UiKit.button(page, "ClearCart", localized("clearCart"), colors.Sand, 13)
	local recommendButton = UiKit.button(page, "AddRecommended", localized("loading"), colors.Sand, 13)
	local status = UiKit.label(page, "SupplierStatus", localized("loading"), 13)
	local cartInfo = UiKit.label(page, "CartInfo", "", 13)
	local cartLines = UiKit.label(page, "CartLines", "", 13)
	local sellHint = UiKit.label(page, "SellHint", localizedFormat("sellBackHint", sellBackPercent()), 13)
	for _, wrapped in ipairs({ cartInfo, cartLines, sellHint }) do
		wrapped.TextWrapped = true
		wrapped.TextTruncate = Enum.TextTruncate.None
	end

	local rows: { Row } = {}
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local frame = Instance.new("Frame")
			frame.Name = "Row_" .. speciesId .. "_" .. sizeId
			frame.BackgroundTransparency = 1
			frame.BorderSizePixel = 0
			frame.Parent = page
			local qty = UiKit.label(frame, "Qty", "0", 15)
			qty.TextXAlignment = Enum.TextXAlignment.Center
			local row: Row = {
				key = Inventory.key(speciesId, sizeId),
				speciesId = speciesId,
				sizeId = sizeId,
				frame = frame,
				name = UiKit.label(
					frame,
					"Name",
					localizedFormat("supplierRowName", speciesName(speciesId), sizeName(sizeId)),
					13
				),
				info = UiKit.label(frame, "Info", "", 12),
				qty = qty,
				minus = UiKit.button(frame, "Minus", "−", colors.Sand, 17),
				plus = UiKit.button(frame, "Plus", "+", colors.Sand, 17),
				max = UiKit.button(frame, "Max", localized("maxButton"), colors.Sand, 13),
				sell = UiKit.button(frame, "Sell", "", colors.Gold, 12),
			}
			table.insert(rows, row)
		end
	end

	-- CM2-G14: deliveries land in a bay by themselves; stocking happens at the bay.
	local stockingHint = UiKit.label(page, "StockingHint", localized("supplierStockingHint"), 13)
	stockingHint.TextWrapped = true
	stockingHint.TextTruncate = Enum.TextTruncate.None
	local customerLine = UiKit.label(page, "CustomerLine", "", 13)

	local function place(item: GuiObject, placed: UiTheme.Box)
		item.Position = UDim2.fromOffset(placed.x, placed.y)
		item.Size = UDim2.fromOffset(placed.w, placed.h)
	end

	local function summaryPart(name: string): any
		return if type(lastSummary) == "table" then lastSummary[name] else nil
	end

	local function limits(): SupplierCart.Limits
		local supplier = summaryPart("supplier")
		local receiving = summaryPart("receiving")
		local stock = if type(supplier) == "table" and type(supplier.stock) == "table" then supplier.stock else {}
		local freeBays, storageFree = 0, 0
		if type(receiving) == "table" then
			freeBays = number(receiving.bayCount) - number(receiving.baysUsed)
			storageFree = number(receiving.storageCapacity) - number(receiving.storageUsed)
		end
		return {
			cash = number(summaryPart("cash")),
			freeBays = math.max(0, freeBays),
			storageFree = math.max(0, storageFree),
			stock = stock,
		}
	end

	local function errorText(errorCode: unknown): string
		if errorCode == "NoFreeBay" then
			local receiving = summaryPart("receiving")
			local full = type(receiving) == "table" and number(receiving.baysUsed) >= number(receiving.bayCount)
			local text = if full
				then localized("noFreeBay")
				else localizedFormat("notEnoughBays", GameConfig.Receiving.BayCapacity)
			return localizedFormat("errorStatus", text)
		end
		local key = type(errorCode) == "string" and ERROR_KEYS[errorCode]
		return localizedFormat("errorStatus", if key then localized(key) else tostring(errorCode))
	end

	local function sellBound(key: string): number
		local supplier = summaryPart("supplier")
		local sellable = if type(supplier) == "table" and type(supplier.sellable) == "table"
			then supplier.sellable
			else {}
		return math.min(math.max(0, math.floor(number(sellable[key]))), GameConfig.MaxOrderQuantity)
	end

	local function setCartCount()
		page:SetAttribute("CartCount", SupplierCart.total(SupplierCart.fromCounts(cart)))
	end

	local function formatSeconds(seconds: number): (number, number)
		local whole = math.max(0, math.floor(seconds))
		return whole // 60, whole % 60
	end

	local function updateRefreshLabel()
		if refreshDeadline == nil then
			refreshLabel.Text = ""
			return
		end
		local minutes, seconds = formatSeconds(math.ceil((refreshDeadline :: number) - os.clock()))
		refreshLabel.Text = localizedFormat("supplierRefresh", minutes, seconds)
	end

	local function renderCart()
		local lines = SupplierCart.fromCounts(cart)
		if #lines == 0 then
			cartLines.Text = localized("cartEmpty")
		else
			local items = {}
			for index = 1, math.min(CART_PREVIEW_LINES, #lines) do
				local line = lines[index]
				table.insert(
					items,
					localizedFormat("cartLineItem", line.quantity, speciesName(line.speciesId), sizeName(line.sizeId))
				)
			end
			local text = table.concat(items, ", ")
			local rest = #lines - CART_PREVIEW_LINES
			cartLines.Text = if rest > 0
				then localizedFormat("cartLinesMore", text, rest)
				else localizedFormat("cartLines", text)
		end
		local receiving = summaryPart("receiving")
		local supplier = summaryPart("supplier")
		local current = limits()
		local free, capacity = SupplierCart.deliveryArea(cart, current.freeBays)
		local baysUsed = if type(receiving) == "table" then number(receiving.baysUsed) else 0
		local bayCount = if type(receiving) == "table"
			then number(receiving.bayCount)
			else GameConfig.Receiving.BayCount
		local delivery = if type(supplier) == "table" and type(supplier.deliverySeconds) == "number"
			then supplier.deliverySeconds
			else GameConfig.DeliverySeconds
		local minutes, seconds = formatSeconds(delivery)
		cartInfo.Text = localizedFormat(
			"cartInfo",
			SupplierCart.total(lines),
			SupplierCart.cost(lines),
			free,
			capacity,
			baysUsed + SupplierCart.baysNeeded(lines),
			bayCount,
			minutes,
			seconds
		)
	end

	local function renderRecommend()
		local supplier = summaryPart("supplier")
		local recommended = if type(supplier) == "table" then supplier.recommended else nil
		if type(recommended) ~= "table" then
			recommendButton.Text = localized("loading")
			setEnabled(recommendButton, false)
			return
		end
		if number(recommended.quantity) > 0 then
			recommendButton.Text = localizedFormat("addRecommended", number(recommended.cost))
			setEnabled(recommendButton, true)
		else
			recommendButton.Text = if recommended.reason == "OutOfStock"
				then localized("recommendNothing")
				else errorText(recommended.reason)
			setEnabled(recommendButton, false)
		end
	end

	local function renderBuyRow(row: Row)
		local supplier = summaryPart("supplier")
		local wholesale = if type(supplier) == "table" and type(supplier.wholesale) == "table"
			then supplier.wholesale
			else {}
		local stock = if type(supplier) == "table" and type(supplier.stock) == "table" then supplier.stock else {}
		local demand = if type(supplier) == "table" and type(supplier.demand) == "table" then supplier.demand else {}
		local infoKey = if demand[row.key] == "High"
			then "supplierBuyRowInfoHigh"
			elseif demand[row.key] == "Low" then "supplierBuyRowInfoLow"
			else "supplierBuyRowInfo"
		local info = localizedFormat(infoKey, number(wholesale[row.key]), number(stock[row.key]))
		row.info.Text = info
		local count = cart[row.key] or 0
		row.qty.Text = tostring(count)
		local canAdd = lastSummary ~= nil and SupplierCart.maxAdd(cart, row.speciesId, row.sizeId, limits()) >= 1
		setEnabled(row.minus, count > 0)
		setEnabled(row.plus, canAdd)
		row.max.Text = localized("maxButton")
		setEnabled(row.max, canAdd)
		row.sell.Visible = false
	end

	local function renderSellRow(row: Row)
		local supplier = summaryPart("supplier")
		local sellable = if type(supplier) == "table" and type(supplier.sellable) == "table"
			then supplier.sellable
			else {}
		local refunds = if type(supplier) == "table" and type(supplier.refunds) == "table" then supplier.refunds else {}
		local bound = sellBound(row.key)
		local qty = SupplierCart.applySellQty(sellQty, row.key, bound, row.qty)
		local refund = number(refunds[row.key])
		row.info.Text = localizedFormat("supplierSellRowInfo", number(sellable[row.key]), refund)
		setEnabled(row.minus, qty > 0)
		setEnabled(row.plus, qty < bound)
		row.max.Text = localized("sellAll")
		setEnabled(row.max, bound > 0)
		row.sell.Text = localizedFormat("sellRowButton", refund * qty)
		row.sell.Visible = true
		setEnabled(row.sell, qty > 0 and not busy.sell)
	end

	local function setStatus(text: string)
		statusText = text
		status.Text = text
	end

	local function renderView()
		local buy = mode == "Buy"
		modeBuy.BackgroundColor3 = if buy then colors.Gold else colors.Sand
		modeBuyStroke.Enabled = buy
		modeSell.BackgroundColor3 = if buy then colors.Sand else colors.Gold
		modeSellStroke.Enabled = not buy
		orderButton.Visible = buy
		clearButton.Visible = buy
		recommendButton.Visible = buy
		cartInfo.Visible = buy
		cartLines.Visible = buy
		sellHint.Visible = not buy

		local layout = UiTheme.supplierPanelLayout(metrics, page.AbsoluteSize.X)
		local rowLayout = UiTheme.supplierRowLayout(page.AbsoluteSize.X, not buy)
		local rowsTop = if buy then layout.rowsTopBuy else layout.rowsTopSell
		local shownRows = 0
		for _, row in ipairs(rows) do
			local visible = buy or sellBound(row.key) > 0
			row.frame.Visible = visible
			if not visible then
				SupplierCart.applySellQty(sellQty, row.key, 0, row.qty)
			end
			if visible then
				row.frame.Position = UDim2.fromOffset(0, rowsTop + shownRows * layout.rowPitch)
				row.frame.Size = UDim2.fromOffset(layout.width, layout.rowHeight)
				place(row.name, { x = rowLayout.text.x, y = 0, w = rowLayout.text.w, h = 22 })
				place(row.info, { x = rowLayout.text.x, y = 22, w = rowLayout.text.w, h = 22 })
				place(row.minus, rowLayout.minus)
				place(row.qty, rowLayout.qty)
				place(row.plus, rowLayout.plus)
				place(row.max, rowLayout.max)
				if rowLayout.sell then
					place(row.sell, rowLayout.sell)
				end
				row.name.TextSize = layout.textSize
				row.info.TextSize = layout.textSize
				if buy then
					renderBuyRow(row)
				else
					renderSellRow(row)
				end
				shownRows += 1
			end
		end
		local footerTop = rowsTop + shownRows * layout.rowPitch
		place(stockingHint, { x = 0, y = footerTop, w = layout.width, h = 36 })
		place(customerLine, { x = 0, y = footerTop + 38, w = layout.width, h = 18 })
		page.CanvasSize = UDim2.fromOffset(0, rowsTop + shownRows * layout.rowPitch + 70)

		if buy then
			renderCart()
			renderRecommend()
			if statusText == localized("sellNothing") then
				setStatus("")
			end
		elseif lastSummary ~= nil and shownRows == 0 then
			setStatus(localized("sellNothing"))
		elseif statusText == localized("sellNothing") then
			setStatus("")
		end

		local customers = summaryPart("customers")
		if type(customers) == "table" then
			customerLine.Text = localizedFormat(
				"customerStatus",
				number(customers.activeCustomers),
				number(customers.parkingSpaces),
				number(customers.loadedOrders),
				number(customers.missedPickups)
			)
		end
	end

	-- Boxes come from UiTheme.supplierPanelLayout and follow the screen size.
	local function applyLayout(m: UiTheme.Metrics)
		metrics = m
		local layout = UiTheme.supplierPanelLayout(m, page.AbsoluteSize.X)
		place(modeBuy, layout.modeBuy)
		place(modeSell, layout.modeSell)
		place(refreshLabel, layout.refresh)
		place(orderButton, layout.placeOrder)
		place(clearButton, layout.clear)
		place(recommendButton, layout.recommend)
		place(sellHint, layout.sellHint)
		place(status, layout.status)
		place(cartInfo, layout.cartInfo)
		place(cartLines, layout.cartLines)
		for _, item in ipairs({ refreshLabel, status, cartInfo, cartLines, sellHint, stockingHint, customerLine }) do
			item.TextSize = layout.textSize
		end
		renderView()
	end
	local gui = page:FindFirstAncestorOfClass("ScreenGui")
	if gui then
		UiKit.onLayout(gui, applyLayout)
		page:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			applyLayout(UiTheme.metrics(gui.AbsoluteSize.X, gui.AbsoluteSize.Y))
		end)
	else
		applyLayout(metrics)
	end

	local function changeCart(key: string, delta: number)
		local value = (cart[key] or 0) + delta
		cart[key] = if value > 0 then value else nil
		setCartCount()
		renderView()
	end

	local function setMode(nextMode: string)
		if mode ~= nextMode then
			mode = nextMode
			setStatus("")
			renderView()
		end
	end
	modeBuy.Activated:Connect(function()
		setMode("Buy")
	end)
	modeSell.Activated:Connect(function()
		setMode("Sell")
	end)

	clearButton.Activated:Connect(function()
		cart = {}
		setCartCount()
		renderView()
	end)

	recommendButton.Activated:Connect(function()
		if not isEnabled(recommendButton) then
			return
		end
		local supplier = summaryPart("supplier")
		local recommended = if type(supplier) == "table" then supplier.recommended else nil
		if type(recommended) ~= "table" or type(recommended.lines) ~= "table" then
			return
		end
		local nextCart: { [string]: number } = {}
		for _, line in ipairs(recommended.lines) do
			if
				type(line) == "table"
				and GameConfig.Trees[line.speciesId]
				and GameConfig.isValidSize(line.sizeId)
				and number(line.quantity) > 0
			then
				nextCart[Inventory.key(line.speciesId, line.sizeId)] = math.floor(number(line.quantity))
			end
		end
		cart = nextCart
		setCartCount()
		renderView()
	end)

	for _, row in ipairs(rows) do
		row.minus.Activated:Connect(function()
			if not isEnabled(row.minus) then
				return
			end
			if mode == "Buy" then
				changeCart(row.key, -1)
			else
				local qty = sellQty[row.key] or 0
				sellQty[row.key] = if qty > 1 then qty - 1 else nil
				renderView()
			end
		end)
		row.plus.Activated:Connect(function()
			if not isEnabled(row.plus) then
				return
			end
			if mode == "Buy" then
				if SupplierCart.maxAdd(cart, row.speciesId, row.sizeId, limits()) >= 1 then
					changeCart(row.key, 1)
				end
			else
				local qty = sellQty[row.key] or 0
				if qty < sellBound(row.key) then
					sellQty[row.key] = qty + 1
				end
				renderView()
			end
		end)
		row.max.Activated:Connect(function()
			if not isEnabled(row.max) then
				return
			end
			if mode == "Buy" then
				local amount = SupplierCart.maxAdd(cart, row.speciesId, row.sizeId, limits())
				if amount >= 1 then
					changeCart(row.key, amount)
				end
			else
				local bound = sellBound(row.key)
				sellQty[row.key] = if bound > 0 then bound else nil
				renderView()
			end
		end)
		row.sell.Activated:Connect(function()
			if mode ~= "Sell" or busy.sell or not isEnabled(row.sell) then
				return
			end
			local quantity = sellQty[row.key] or 0
			if quantity <= 0 then
				return
			end
			busy.sell = true
			renderView()
			local response = context.request(
				"Supplier.SellBack",
				{ speciesId = row.speciesId, sizeId = row.sizeId, quantity = quantity }
			)
			busy.sell = false
			if response.ok then
				sellQty[row.key] = nil
				setStatus("")
				context.refresh()
			else
				setStatus(errorText(response.errorCode))
			end
			renderView()
		end)
	end

	orderButton.Activated:Connect(function()
		if busy.order then
			return
		end
		local lines = SupplierCart.fromCounts(cart)
		if #lines == 0 then
			setStatus(localized("cartNeedsTrees"))
			return
		end
		busy.order = true
		orderButton.AutoButtonColor = false
		orderButton.Text = localized("ordering")
		local response = context.request("Supplier.PlaceOrder", { lines = lines })
		if response.ok then
			cart = {}
			setCartCount()
			setStatus("")
			context.refresh()
		else
			setStatus(errorText(response.errorCode))
		end
		orderButton.Text = localized("placeOrder")
		orderButton.AutoButtonColor = true
		busy.order = false
		renderView()
	end)

	-- The refresh countdown ticks once a second while the page exists.
	task.spawn(function()
		while page.Parent do
			updateRefreshLabel()
			task.wait(1)
		end
	end)

	local function render(summary: any?)
		if summary == nil then
			-- No data: a switched save starts from its own summary, never the previous one.
			lastSummary = nil
			mode = "Buy"
			cart = {}
			sellQty = {}
			busy.order = false
			busy.sell = false
			refreshDeadline = nil
			setCartCount()
			setStatus(localized("loading"))
			updateRefreshLabel()
			renderView()
			return
		end
		if lastSummary == nil and statusText == localized("loading") then
			setStatus("")
		end
		lastSummary = summary
		local supplier = summaryPart("supplier")
		refreshDeadline = if type(supplier) == "table" and type(supplier.refreshIn) == "number"
			then os.clock() + supplier.refreshIn
			else nil
		updateRefreshLabel()
		renderView()
	end

	setCartCount()
	return { render = render }
end

return SupplierTab
