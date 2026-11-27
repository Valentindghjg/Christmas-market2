--!strict
-- Event shop of the company service (CM2-45, docs/plans/CM2-45.md): a mixin that
-- CompanyStateService installs. Event.Buy runs inside _dispatch (idempotency and limits come
-- from handle); price, limit and decor come only from shared/EventConfig.lua, and the count
-- per save lives in `eventPurchases` (schema 23). The event clock is the business clock unless
-- a Studio test overrides it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local EventCalendar = require(Shared:WaitForChild("EventCalendar"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local CompanyEvents = {}

local function boughtOf(state, eventId: string, itemKey: string): number
	local items = state.eventPurchases[eventId]
	return if type(items) == "table" and type(items[itemKey]) == "number" then items[itemKey] else 0
end

-- One validated Event.Buy {eventId, itemKey} at `now`. Every check runs before the first change.
function CompanyEvents.buy(state, payload, now: number): (boolean, any)
	local event = EventCalendar.active(now)
	if event == nil or payload.eventId ~= event.id then
		return false, "EventClosed"
	end
	local item = EventCalendar.item(event, payload.itemKey)
	if item == nil then
		return false, "InvalidItem"
	end
	local bought = boughtOf(state, event.id, item.key)
	if bought >= item.limit then
		return false, "PurchaseLimit"
	end
	local price = item.price
	if state.cash < price then
		return false, "InsufficientFunds"
	end
	state.cash -= price
	state.spent += price
	BusinessState.record(state, "EventPurchase", -price)
	local decor = {}
	for _, entry in ipairs(item.decor) do
		local count = math.min((state.decorInventory[entry.id] or 0) + entry.count, GameConfig.Advent.DecorMaxCount)
		state.decorInventory[entry.id] = count
		decor[entry.id] = count
	end
	local items = state.eventPurchases[event.id]
	if type(items) ~= "table" then
		items = {}
		state.eventPurchases[event.id] = items
	end
	items[item.key] = bought + 1
	return true, { eventId = event.id, itemKey = item.key, price = price, bought = bought + 1, decor = decor }
end

-- The open event for Company.GetSummary: cash items in config order, then the Robux items
-- (never prompted while not ready). nil without an open event.
function CompanyEvents.summary(state, now: number): any?
	local event = EventCalendar.active(now)
	if event == nil then
		return nil
	end
	local view = EventCalendar.view(now)
	local items = {}
	for _, item in ipairs(event.items) do
		table.insert(items, {
			key = item.key,
			kind = "Cash",
			price = item.price,
			limit = item.limit,
			bought = boughtOf(state, event.id, item.key),
		})
	end
	for _, key in ipairs(event.robuxItems) do
		local entry = ShopConfig.byKey(key)
		if entry ~= nil then
			table.insert(items, {
				key = key,
				kind = "Robux",
				price = entry.price,
				ready = entry.ready and entry.id > 0,
			})
		end
	end
	return { id = view.id, titleKey = view.titleKey, endsIn = view.endsIn, items = items }
end

function CompanyEvents.install(CompanyStateService)
	-- The event clock: the Studio override, else the business clock.
	function CompanyStateService:eventNow(): number
		return self._eventNowOverride or self._clock()
	end

	function CompanyStateService:eventView(): EventCalendar.View
		return EventCalendar.view(self:eventNow())
	end

	-- Studio test instrument only (StudioTestService eventNow): moves the event clock alone;
	-- nil restores the business clock.
	function CompanyStateService:setEventNowForTest(at: number?)
		self._eventNowOverride = at
	end

	-- Studio test instrument only (StudioTestService eventReset): forgets the save's event
	-- purchases; the decor stays. false without a healthy session.
	function CompanyStateService:clearEventPurchasesForTest(companyId: string): boolean
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			state.eventPurchases = {}
			state.revision += 1
			session.dirty = true
			return true
		end)
		return entered
	end
end

return CompanyEvents
