--!strict
-- Seasonal event shop data (CM2-45, docs/plans/CM2-45.md; PRODUCT_SPEC "Monetization and
-- events", REFERENCE §7). Pure data plus one lookup; shared/EventCalendar.lua holds the logic.
-- Later events (CM2-45b/45c) only add entries to EventConfig.Events. Times are UTC seconds.
local EventConfig = {}

export type Decor = { id: string, count: number }
export type Item = { key: string, price: number, limit: number, decor: { Decor } }
export type Event = {
	id: string,
	startsAt: number,
	endsAt: number,
	titleKey: string,
	items: { Item },
	robuxItems: { string },
}

EventConfig.RefreshSeconds = 5 -- PROVISIONAL
EventConfig.MaxEvents = 64 -- save bounds
EventConfig.MaxItemsPerEvent = 16
EventConfig.MaxBuyCount = 99

EventConfig.Events = { -- sorted by startsAt, never overlapping
	{
		id = "Advent1",
		startsAt = 1795910400, -- 2026-11-29 00:00 UTC (OWNER DECIDED)
		endsAt = 1796515200, -- 2026-12-06 00:00 UTC (PROVISIONAL)
		titleKey = "eventTitleAdvent1",
		items = {
			{
				key = "CandlelightPack",
				price = 2000, -- PROVISIONAL price
				limit = 1, -- PROVISIONAL limit
				decor = { -- OBSERVED shape: 5 items x 3 (REFERENCE §7)
					{ id = "CandleArch", count = 3 },
					{ id = "CandleLanternPost", count = 3 },
					{ id = "CandleWreathStand", count = 3 },
					{ id = "CandleMiniFir", count = 3 },
					{ id = "CandleStarSled", count = 3 },
				},
			},
		},
		robuxItems = { "EventTreeCandlelight", "EventTreeStarlight", "EventTreeSnowberry" },
	},
} :: { Event }

-- Every event's decor ids, built once at load.
local decorIds: { [string]: boolean } = {}
for _, event in ipairs(EventConfig.Events) do
	for _, item in ipairs(event.items) do
		for _, decor in ipairs(item.decor) do
			decorIds[decor.id] = true
		end
	end
end

-- True for a decor id that any event item grants.
function EventConfig.isDecorItem(id: unknown): boolean
	return type(id) == "string" and decorIds[id] == true
end

return EventConfig
