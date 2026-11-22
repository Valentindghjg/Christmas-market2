--!strict
-- Pure priority and overlap resolution for world billboards (CM2-UVF2). The client builds one
-- Candidate per label; `decide` hides labels that are out of range or behind the camera, then
-- resolves overlaps: every label whose screen box overlaps a better one is hidden (CM2-UVF7).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local LabelDeclutter = {}

export type Entry = { box: UiTheme.Box, priority: number, depth: number, shown: boolean }
export type Candidate = {
	box: UiTheme.Box,
	priority: number,
	depth: number,
	shown: boolean,
	distance: number,
	range: number,
}

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

function LabelDeclutter.inRange(distance: number, range: number, depth: number): boolean
	return depth > 0 and distance <= range
end

function LabelDeclutter.decide(candidates: { Candidate }): { boolean }
	local entries: { Entry } = {}
	local origin: { number } = {}
	for index, candidate in ipairs(candidates) do
		if LabelDeclutter.inRange(candidate.distance, candidate.range, candidate.depth) then
			table.insert(entries, {
				box = candidate.box,
				priority = candidate.priority,
				depth = candidate.depth,
				shown = candidate.shown,
			})
			table.insert(origin, index)
		end
	end
	local resolved = LabelDeclutter.resolve(entries)
	local result: { boolean } = {}
	for index = 1, #candidates do
		result[index] = false
	end
	for position, index in ipairs(origin) do
		result[index] = resolved[position]
	end
	return result
end

return LabelDeclutter
