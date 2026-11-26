--!strict
-- Allocates plots to holders (company IDs, CM2-S1) without trusting any client-selected
-- plot identifier. Plots are claimed in the configured order.
local PlotService = {}
PlotService.__index = PlotService

function PlotService.new(plotIds)
	local self = setmetatable({}, PlotService)
	self._plots = {}
	self._order = {}
	self._byHolder = {}
	for _, plotId in ipairs(plotIds) do
		assert(type(plotId) == "string" and #plotId > 0, "invalid plot ID")
		assert(self._plots[plotId] == nil, "duplicate plot ID")
		self._plots[plotId] = false
		table.insert(self._order, plotId)
	end
	return self
end

local function isHolder(holderId: unknown): boolean
	return type(holderId) == "string" and #holderId > 0
end

-- An existing claim keeps its plot; otherwise the preferred plot when free, else the first free one.
function PlotService:claim(holderId: string, preferredPlotId: string?): (string?, string?)
	if not isHolder(holderId) then
		return nil, "InvalidHolder"
	end
	local existing = self._byHolder[holderId]
	if existing then
		return existing, nil
	end
	local chosen = nil
	if type(preferredPlotId) == "string" and self._plots[preferredPlotId] == false then
		chosen = preferredPlotId
	else
		for _, plotId in ipairs(self._order) do
			if self._plots[plotId] == false then
				chosen = plotId
				break
			end
		end
	end
	if chosen == nil then
		return nil, "NoPlotsAvailable"
	end
	self._plots[chosen] = holderId
	self._byHolder[holderId] = chosen
	return chosen, nil
end

-- CM2-PP: claims exactly the requested plot. The client-chosen id is only honoured when free; an
-- existing claim of the holder keeps its plot and the requested id is ignored.
function PlotService:claimExact(holderId: string, plotId: string): (string?, string?)
	if not isHolder(holderId) then
		return nil, "InvalidHolder"
	end
	local existing = self._byHolder[holderId]
	if existing then
		return existing, nil
	end
	if not self:has(plotId) then
		return nil, "UnknownPlot"
	end
	if self._plots[plotId] ~= false then
		return nil, "PlotTaken"
	end
	self._plots[plotId] = holderId
	self._byHolder[holderId] = plotId
	return plotId, nil
end

function PlotService:release(holderId: string): boolean
	local plotId = self._byHolder[holderId]
	if not plotId then
		return false
	end
	self._plots[plotId] = false
	self._byHolder[holderId] = nil
	return true
end

function PlotService:owns(holderId: string, plotId: string): boolean
	return self._byHolder[holderId] == plotId and self._plots[plotId] == holderId
end

function PlotService:getPlot(holderId: string): string?
	return self._byHolder[holderId]
end

-- The holder (company ID) that claimed this plot; nil for a free, unknown or non-string plot.
function PlotService:holderOf(plotId: unknown): string?
	if type(plotId) ~= "string" then
		return nil
	end
	local holder = self._plots[plotId]
	if type(holder) == "string" then
		return holder
	end
	return nil
end

-- CM2-PP: true for a plot id this service manages.
function PlotService:has(plotId: unknown): boolean
	return type(plotId) == "string" and self._plots[plotId] ~= nil
end

-- CM2-PP: the configured plot ids in claim order (a copy).
function PlotService:plotIds(): { string }
	return table.clone(self._order)
end

function PlotService:freeCount(): number
	local count = 0
	for _, plotId in ipairs(self._order) do
		if self._plots[plotId] == false then
			count += 1
		end
	end
	return count
end

return PlotService
