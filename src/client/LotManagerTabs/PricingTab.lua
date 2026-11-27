--!strict
-- Pricing tab of the Lot Manager (CM2-G7): one card per species with the wholesale, the typical
-- price, the margin, a sentiment sentence and the Small/Medium/Large prices with profit, plus the
-- automatic pricing switch. Every number comes from the server summary's `pricing` table; the
-- tab only clamps a step target into the server bounds and sends it through the tab context.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PricingView = require(Shared:WaitForChild("PricingView"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
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

local PricingTab = {}

local SPECIES_ORDER = GameConfig.SpeciesOrder
local COLUMN_WIDTH = 324
local CARD_TOP = 212
local DEBOUNCE_SECONDS = 0.4
local STEP_BUTTONS = {
	{ name = "Minus5", delta = -5, x = 10 },
	{ name = "Minus1", delta = -1, x = 70 },
	{ name = "Plus1", delta = 1, x = 198 },
	{ name = "Plus5", delta = 5, x = 258 },
}

type Card = {
	frame: Frame,
	name: TextLabel,
	sentiment: TextLabel,
	wholesaleTypical: TextLabel,
	margin: TextLabel,
	sizes: TextLabel,
	price: TextLabel,
	stepButtons: { { button: TextButton, x: number } },
}

local function wrap(label: TextLabel)
	label.TextWrapped = true
	label.TextTruncate = Enum.TextTruncate.None
end

local function place(item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(w, h)
end

function PricingTab.create(page: ScrollingFrame, context: TabContext): TabHandle
	local colors = UiKit.Colors
	local localized = UiKit.localized
	local fmt = UiKit.localizedFormat

	local title = UiKit.label(page, "PricingTitle", localized("pricing"), 22)
	place(title, 0, 0, COLUMN_WIDTH, 28)
	local rule = UiKit.label(page, "PricingRule", PricingView.ruleText(fmt), 13)
	place(rule, 0, 32, COLUMN_WIDTH, 52)
	wrap(rule)
	local autoButton = UiKit.button(page, "AutoPricing", PricingView.autoText(false, fmt), colors.Sand, 15)
	place(autoButton, 0, 88, COLUMN_WIDTH, 44)
	local autoHint = UiKit.label(page, "AutoHint", localized("pricingAutoHint"), 12)
	place(autoHint, 0, 136, COLUMN_WIDTH, 48)
	wrap(autoHint)
	local status = UiKit.label(page, "PricingStatus", localized("loading"), 13)
	place(status, 0, 188, COLUMN_WIDTH, 18)

	-- Last result or error; "loading" shows only while there is no pricing data.
	local statusText = ""
	local lastPricing: any = nil
	local entries: { [string]: any } = {}
	local pending: { [string]: number } = {}
	local generation: { [string]: number } = {}
	local inFlight: { [string]: boolean } = {}
	local autoBusy = false
	local cards: { [string]: Card } = {}

	local function showStatus(text: string)
		statusText = text
		status.Text = text
	end

	local function showPrice(speciesId: string, fallback: string)
		local target = pending[speciesId]
		cards[speciesId].price.Text = if target ~= nil then fmt("pricingPrice", target) else fallback
	end

	local function send(speciesId: string)
		local displayName = GameConfig.Trees[speciesId].displayName
		while true do
			inFlight[speciesId] = true
			local sent = pending[speciesId]
			local response = context.request("Pricing.SetMediumPrice", { speciesId = speciesId, mediumPrice = sent })
			inFlight[speciesId] = false
			if response.ok then
				showStatus(fmt("pricingSaved", displayName, sent))
			else
				showStatus(PricingView.errorText(response.errorCode, fmt))
			end
			if pending[speciesId] == sent then
				pending[speciesId] = nil
				break
			end
			-- A newer target arrived while this request was in flight: send it at once.
		end
		context.refresh()
	end

	local function step(speciesId: string, delta: number)
		local entry = entries[speciesId]
		if entry == nil then
			return
		end
		local base = pending[speciesId] or entry.mediumPrice
		pending[speciesId] = PricingView.stepTarget(base, delta, entry.minPrice, entry.maxPrice)
		cards[speciesId].price.Text = fmt("pricingPrice", pending[speciesId])
		local current = (generation[speciesId] or 0) + 1
		generation[speciesId] = current
		-- Debounce: repeated taps send one request, so they stay under the rate limit.
		task.delay(DEBOUNCE_SECONDS, function()
			if generation[speciesId] == current and not inFlight[speciesId] and pending[speciesId] ~= nil then
				send(speciesId)
			end
		end)
	end

	for _, speciesId in ipairs(SPECIES_ORDER) do
		local frame = Instance.new("Frame")
		frame.Name = "Price_" .. speciesId
		frame.BackgroundColor3 = colors.Row
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Parent = page
		UiKit.card(frame)

		local nameLabel = UiKit.label(frame, "Name", "", 15)
		place(nameLabel, 10, 6, 304, 20)
		local sentiment = UiKit.label(frame, "Sentiment", "", 13)
		place(sentiment, 10, 28, 304, 18)
		local wholesaleTypical = UiKit.label(frame, "WholesaleTypical", "", 12)
		place(wholesaleTypical, 10, 48, 304, 30)
		wrap(wholesaleTypical)
		local margin = UiKit.label(frame, "Margin", "", 12)
		place(margin, 10, 80, 304, 18)
		local sizes = UiKit.label(frame, "Sizes", "", 12)
		place(sizes, 10, 98, 304, 28)
		wrap(sizes)
		local price = UiKit.label(frame, "Price", "", 17, true)
		place(price, 130, 128, 64, 44)
		price.TextXAlignment = Enum.TextXAlignment.Center

		local stepButtons: { { button: TextButton, x: number } } = {}
		for _, spec in ipairs(STEP_BUTTONS) do
			local stepButton = UiKit.button(frame, spec.name, fmt("pricingStep", spec.delta), colors.Sand, 17)
			place(stepButton, spec.x, 128, 56, 44)
			table.insert(stepButtons, { button = stepButton, x = spec.x })
			local delta = spec.delta
			UiKit.onActivated(stepButton, function()
				step(speciesId, delta)
			end)
		end

		cards[speciesId] = {
			frame = frame,
			name = nameLabel,
			sentiment = sentiment,
			wholesaleTypical = wholesaleTypical,
			margin = margin,
			sizes = sizes,
			price = price,
			stepButtons = stepButtons,
		}
	end

	-- CM2-UVF12: card boxes come from UiTheme.pricingCardLayout and follow the screen size.
	local function applyLayout(m: UiTheme.Metrics)
		local layout = UiTheme.pricingCardLayout(m)
		page.CanvasSize = UDim2.fromOffset(0, CARD_TOP + #SPECIES_ORDER * layout.pitch)
		for index, speciesId in ipairs(SPECIES_ORDER) do
			local card = cards[speciesId]
			place(card.frame, 0, CARD_TOP + (index - 1) * layout.pitch, COLUMN_WIDTH, layout.cardHeight)
			for _, part in ipairs({ "name", "sentiment", "wholesaleTypical", "margin", "sizes", "price" }) do
				local b = (layout :: any)[part] :: UiTheme.Box
				place((card :: any)[part], b.x, b.y, b.w, b.h)
			end
			for _, entry in ipairs(card.stepButtons) do
				place(entry.button, entry.x, layout.controlsY, 56, layout.controlsHeight)
			end
		end
	end
	local gui = page:FindFirstAncestorOfClass("ScreenGui")
	if gui then
		UiKit.onLayout(gui, applyLayout)
	else
		applyLayout(UiTheme.metrics(1920, 1080))
	end

	UiKit.onActivated(autoButton, function()
		local pricing = lastPricing
		if autoBusy or type(pricing) ~= "table" then
			return
		end
		autoBusy = true
		local response = context.request("Pricing.SetAuto", { enabled = not (pricing.automatic == true) })
		if response.ok then
			showStatus("")
		else
			showStatus(PricingView.errorText(response.errorCode, fmt))
		end
		context.refresh()
		autoBusy = false
	end)

	local function render(summary: any?)
		local pricing = summary and summary.pricing
		if type(pricing) ~= "table" then
			lastPricing = nil
			for speciesId, card in pairs(cards) do
				entries[speciesId] = nil
				card.frame.Visible = false
			end
			status.Text = localized("loading")
			autoButton.Active = false
			return
		end
		lastPricing = pricing
		status.Text = statusText
		autoButton.Active = true
		local byId: { [string]: any } = {}
		if type(pricing.species) == "table" then
			for _, entry in ipairs(pricing.species) do
				if type(entry) == "table" and type(entry.speciesId) == "string" then
					byId[entry.speciesId] = entry
				end
			end
		end
		for speciesId, card in pairs(cards) do
			local entry = byId[speciesId]
			local view = PricingView.card(entry, fmt)
			if view == nil then
				entries[speciesId] = nil
				card.frame.Visible = false
			else
				entries[speciesId] = entry
				card.frame.Visible = true
				card.name.Text = view.name
				card.sentiment.Text = view.sentiment
				card.wholesaleTypical.Text = view.wholesaleTypical
				card.margin.Text = view.margin
				card.sizes.Text = view.sizes
				showPrice(speciesId, view.price)
			end
		end
		autoButton.Text = PricingView.autoText(pricing.automatic, fmt)
		autoButton.BackgroundColor3 = if pricing.automatic == true then colors.Gold else colors.Sand
	end

	return { render = render }
end

return PricingTab
