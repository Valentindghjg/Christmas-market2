--!strict
-- Pure priority and overlap resolution for world billboards (CM2-UVF2). The client builds one
-- Entry per label in range and hides every label whose screen box overlaps a better one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local LabelDeclutter = {}

export type Entry = { box: UiTheme.Box, priority: number, depth: number, shown: boolean }

LabelDeclutter.IntervalSeconds = 0.1
LabelDeclutter.ShownBias = 2
LabelDeclutter.Priority = table.freeze({
	NpcThanks = 6,
	PickupOrder = 5,
	CarNumber = 5,
	BayArriving = 4,
	BayContents = 3,
	Reserved = 2,
	BayFree = 1,
	DisplayTree = 1,
})

function LabelDeclutter.priorityFor(kind: unknown, reserved: boolean): number
	if kind == "DisplayTree" and reserved then
		return LabelDeclutter.Priority.Reserved
	end
	if type(kind) == "string" then
		local priority = (LabelDeclutter.Priority :: { [string]: number })[kind]
		if priority then
			return priority
		end
	end
	return 0
end

function LabelDeclutter.resolve(entries: { Entry }): { boolean }
	local order = {}
	for index = 1, #entries do
		order[index] = index
	end
	local function effectiveDepth(entry: Entry): number
		return entry.depth - (if entry.shown then LabelDeclutter.ShownBias else 0)
	end
	table.sort(order, function(a: number, b: number): boolean
		local first, second = entries[a], entries[b]
		if first.priority ~= second.priority then
			return first.priority > second.priority
		end
		local depthA, depthB = effectiveDepth(first), effectiveDepth(second)
		if depthA ~= depthB then
			return depthA < depthB
		end
		return a < b
	end)
	local result = {}
	for index = 1, #entries do
		result[index] = false
	end
	local accepted: { UiTheme.Box } = {}
	for _, index in ipairs(order) do
		local box = entries[index].box
		local free = true
		for _, other in ipairs(accepted) do
			if UiTheme.overlaps(box, other) then
				free = false
				break
			end
		end
		if free then
			table.insert(accepted, box)
			result[index] = true
		end
	end
	return result
end

return LabelDeclutter
