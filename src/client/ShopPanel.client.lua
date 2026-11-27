--!strict
-- Robux shop panel (CM2-46b): seven categories, every product with name, description, price
-- and Buy, Owned or Coming soon. Buy only asks the server to open the Roblox prompt
-- (Shop.Prompt); the server owns prices, states and every grant. The client never calls
-- MarketplaceService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shopAction = remotes:WaitForChild("ShopAction") :: RemoteFunction
local businessAction = remotes:WaitForChild("BusinessAction") :: RemoteFunction

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat

local BUTTON_HEIGHT = UiTheme.MinTouch
local ROW_HEIGHT = 96
local PANEL = UiKit.Colors.Panel
local ROW = UiKit.Colors.Row
local GOLD = UiKit.Colors.Gold
local SAND = UiKit.Colors.Sand

local textLabel = UiKit.label
local textButton = UiKit.button

local ERROR_KEYS: { [string]: string } = {
	ComingSoon = "shopErrorComingSoon",
	AlreadyOwned = "shopErrorOwned",
	NoActiveSave = "shopErrorNoSave",
	BoostFull = "shopErrorBoostFull",
	RateLimited = "shopErrorBusy",
}

-- Layout ------------------------------------------------------------------------------------

local gui = UiKit.screenGui("ShopUI", 15)
local shopButton = UiKit.addRailButton("ShopButton", "shopButton", 20)

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui
UiKit.window(panel)
UiKit.padding(panel, 12)

local title = textLabel(panel, "Title", localized("shopTitle"), 22)
title.Size = UDim2.new(0.5, 0, 0, 30)

local boostLine = textLabel(panel, "BoostLine", "", UiTheme.TextSize.Small)
boostLine.Position = UDim2.new(0.5, 0, 0, 4)
boostLine.Size = UDim2.new(0.5, 0, 0, 22)
boostLine.TextXAlignment = Enum.TextXAlignment.Right
boostLine.TextColor3 = GOLD
boostLine.Visible = false

local categoryBar = Instance.new("Frame")
categoryBar.Name = "CategoryBar"
categoryBar.BackgroundTransparency = 1
categoryBar.BorderSizePixel = 0
categoryBar.ClipsDescendants = true
categoryBar.Position = UDim2.fromOffset(0, 38)
categoryBar.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
categoryBar.Parent = panel
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.Padding = UDim.new(0, UiTheme.ShopCategoryBar.gap)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent = categoryBar

local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.BorderSizePixel = 0
footer.Parent = panel

local productList = Instance.new("ScrollingFrame")
productList.Name = "ProductList"
productList.BackgroundTransparency = 1
productList.BorderSizePixel = 0
productList.CanvasSize = UDim2.new()
productList.AutomaticCanvasSize = Enum.AutomaticSize.Y
productList.ScrollingDirection = Enum.ScrollingDirection.Y
productList.ScrollBarThickness = 6
productList.Parent = panel
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = productList

local status = UiKit.listStatus(productList, "ShopStatus")

local closeButton = textButton(footer, "Close", localized("shopClose"), SAND)
closeButton.AnchorPoint = Vector2.new(0, 1)
closeButton.Position = UDim2.fromScale(0, 1)
closeButton.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)

UiKit.bindDialog(gui, { frame = panel, list = productList, footer = footer }, UiTheme.Dialogs.Shop)

local categoryButtons: { [string]: TextButton } = {}
local tabCount = #ShopConfig.Categories
local tabGap = UiTheme.ShopCategoryBar.gap
for index, id in ipairs(ShopConfig.Categories) do
	local button = textButton(categoryBar, "Category_" .. id, localized("shopCategory" .. id), SAND)
	button.LayoutOrder = index
	button.Size = UDim2.new(1 / tabCount, -math.ceil(tabGap * (tabCount - 1) / tabCount), 0, BUTTON_HEIGHT)
	button.TextScaled = true
	button.TextWrapped = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = UiTheme.ShopCategoryBar.maxText
	textLimit.MinTextSize = UiTheme.ShopCategoryBar.minText
	textLimit.Parent = button
	categoryButtons[id] = button
end

-- State -------------------------------------------------------------------------------------

local selected = "Starter"
local catalog: { any }? = nil
local boostLeft = 0
local buyInFlight = false
local openToken = 0

local function formatClock(seconds: number): string
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function updateBoostLabel()
	boostLine.Visible = boostLeft > 0
	if boostLeft > 0 then
		boostLine.Text = localizedFormat("shopBoostActive", formatClock(boostLeft))
	end
end

local function describe(entry: any, product: ShopConfig.Product): string
	local _, descKey = ShopConfig.textKeys(product)
	if descKey == "shopDescCash" then
		local grant = entry.grant
		local cash = if type(grant) == "table" and type(grant.cash) == "number" then grant.cash else 0
		return localizedFormat(descKey, UiTheme.formatMoney(cash))
	end
	return localized(descKey)
end

local function clearRows()
	for _, child in productList:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 8) == "Product_" then
			child:Destroy()
		end
	end
end

local buy: (key: string) -> ()

local function buildRow(index: number, entry: any, product: ShopConfig.Product)
	local row = Instance.new("Frame")
	row.Name = "Product_" .. product.key
	row.LayoutOrder = index
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	UiKit.card(row)
	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingTop = UDim.new(0, 6)
	rowPadding.PaddingBottom = UDim.new(0, 6)
	rowPadding.PaddingLeft = UDim.new(0, 8)
	rowPadding.PaddingRight = UDim.new(0, 8)
	rowPadding.Parent = row

	local nameKey = ShopConfig.textKeys(product)
	local nameLabel = textLabel(row, "Name", localized(nameKey), 18)
	nameLabel.Size = UDim2.new(1, -150, 0, 24)

	local description = textLabel(row, "Description", describe(entry, product), 13)
	description.Position = UDim2.fromOffset(0, 26)
	description.Size = UDim2.new(1, -150, 0, 34)
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextTruncate = Enum.TextTruncate.AtEnd

	local price = if type(entry.price) == "number" then entry.price else product.price
	local priceLabel = textLabel(row, "Price", localizedFormat("shopPrice", price), 15)
	priceLabel.Position = UDim2.new(0, 0, 1, -22)
	priceLabel.Size = UDim2.new(0.4, 0, 0, 22)

	local state = entry.state
	local textKey = if state == "Buy" then "shopBuy" elseif state == "Owned" then "shopOwned" else "shopComingSoon"
	local action = textButton(row, "Action", localized(textKey), if state == "Buy" then GOLD else SAND)
	action.AnchorPoint = Vector2.new(1, 0.5)
	action.Position = UDim2.fromScale(1, 0.5)
	action.Size = UDim2.fromOffset(140, BUTTON_HEIGHT)
	if state == "Buy" then
		UiKit.onActivated(action, function()
			buy(product.key)
		end)
	else
		action.Active = false
	end

	row.Parent = productList
end

local function render()
	clearRows()
	for _, id in ipairs(ShopConfig.Categories) do
		categoryButtons[id].BackgroundColor3 = if id == selected then GOLD else SAND
	end
	if catalog == nil then
		return
	end
	local index = 0
	for _, entry in ipairs(catalog) do
		if type(entry) == "table" and entry.category == selected then
			local product = ShopConfig.byKey(entry.key)
			if product ~= nil then
				index += 1
				buildRow(index, entry, product)
			end
		end
	end
end

-- Requests ----------------------------------------------------------------------------------

local function fetchCatalog()
	local response = UiKit.request(shopAction, "Shop.Catalog", {})
	if response.ok and type(response.data) == "table" and type(response.data.products) == "table" then
		catalog = response.data.products
		status.Text = ""
	else
		catalog = nil
		status.Text = localized("shopErrorUnavailable")
	end
	local summary = UiKit.request(businessAction, "Company.GetSummary", {})
	local seconds = 0
	if summary.ok and type(summary.data) == "table" and type(summary.data.shop) == "table" then
		local value = summary.data.shop.cashBoostSeconds
		if type(value) == "number" and value > 0 then
			seconds = math.floor(value)
		end
	end
	boostLeft = seconds
	updateBoostLabel()
	render()
end

buy = function(key: string)
	if buyInFlight then
		return
	end
	buyInFlight = true
	local response = UiKit.request(shopAction, "Shop.Prompt", { productKey = key })
	buyInFlight = false
	if response.ok then
		status.Text = localized("shopPromptOpen")
	else
		local code = response.errorCode
		local errorKey = if type(code) == "string" and ERROR_KEYS[code] ~= nil
			then ERROR_KEYS[code]
			else "shopErrorUnavailable"
		status.Text = localized(errorKey)
	end
end

-- Open and close ----------------------------------------------------------------------------

local close: () -> ()

local function startCountdown(token: number)
	task.spawn(function()
		while panel.Visible and openToken == token do
			task.wait(1)
			if panel.Visible and openToken == token and boostLeft > 0 then
				boostLeft -= 1
				updateBoostLabel()
			end
		end
	end)
end

local function open()
	UiKit.claimModal("Shop", close)
	openToken += 1
	panel.Visible = true
	selected = "Starter"
	catalog = nil
	boostLeft = 0
	updateBoostLabel()
	status.Text = localized("shopLoading")
	render()
	startCountdown(openToken)
	fetchCatalog()
end

close = function()
	UiKit.releaseModal("Shop")
	openToken += 1
	panel.Visible = false
end

for id, button in pairs(categoryButtons) do
	UiKit.onActivated(button, function()
		selected = id
		render()
	end)
end

UiKit.onActivated(closeButton, close)
UiKit.onActivated(shopButton, function()
	if panel.Visible then
		close()
	else
		open()
	end
end)

local function updateReady()
	local ready = player:GetAttribute("CompanyReady") == true
	shopButton.Visible = ready
	if not ready and panel.Visible then
		close()
	end
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
updateReady()

-- A purchase shows up as a new Robux total or a pass attribute: fetch the catalog again.
local function refetchIfOpen()
	if panel.Visible then
		fetchCatalog()
	end
end
player:GetAttributeChangedSignal("RobuxSpent"):Connect(refetchIfOpen)
for _, product in ipairs(ShopConfig.Products) do
	if product.kind == "Pass" then
		player:GetAttributeChangedSignal("Shop" .. product.key):Connect(refetchIfOpen)
	end
end
