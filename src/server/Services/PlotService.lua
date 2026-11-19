--!strict
-- Allocates personal plots without trusting any client-selected plot identifier.
local PlotService = {}
PlotService.__index = PlotService

function PlotService.new(plotIds)
	local self = setmetatable({}, PlotService)
	self._plots = {}
	self._byUserId = {}
	for _, plotId in ipairs(plotIds) do
		assert(type(plotId) == "string" and #plotId > 0, "invalid plot ID")
		assert(self._plots[plotId] == nil, "duplicate plot ID")
		self._plots[plotId] = false
	end
	return self
end

function PlotService:claim(userId: number)
	if type(userId) ~= "number" or userId < 1 or userId ~= math.floor(userId) then
		return nil, "InvalidUserId"
	end
	if self._byUserId[userId] then
		return self._byUserId[userId], nil
	end
	for plotId, ownerUserId in pairs(self._plots) do
		if ownerUserId == false then
			self._plots[plotId] = userId
			self._byUserId[userId] = plotId
			return plotId, nil
		end
	end
	return nil, "NoPlotsAvailable"
end

function PlotService:release(userId: number)
	local plotId = self._byUserId[userId]
	if not plotId then
		return false
	end
	self._plots[plotId] = false
	self._byUserId[userId] = nil
	return true
end

function PlotService:owns(userId: number, plotId: string): boolean
	return self._byUserId[userId] == plotId and self._plots[plotId] == userId
end

function PlotService:getPlotForUser(userId: number)
	return self._byUserId[userId]
end

return PlotService
