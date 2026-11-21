--!strict
-- Deterministic per-tree height inside the size class range, derived from a stable ID.
-- Deriving instead of storing keeps old saves valid and the value identical after rejoin.
local GameConfig = require(script.Parent.GameConfig)

local TreeHeight = {}

-- 31-bit string hash (djb2 variant); stable across servers and sessions.
local function hash(text: string): number
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % 2147483647
	end
	return value
end

-- Returns the height in tenths of a foot, or nil for an unknown size.
function TreeHeight.tenthsFor(treeId: string, sizeId: string): number?
	local range = GameConfig.TreeHeightTenths[sizeId]
	if type(treeId) ~= "string" or not range then
		return nil
	end
	local span = range.max - range.min + 1
	return range.min + hash(treeId) % span
end

function TreeHeight.feetText(tenths: number): string
	return string.format("%d.%d", tenths // 10, tenths % 10)
end

return TreeHeight
