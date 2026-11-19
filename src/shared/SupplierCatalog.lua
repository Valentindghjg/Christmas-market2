--!strict
-- Read-only, server-derived supplier data. Clients may request it but never provide prices.
local GameConfig = require(script.Parent.GameConfig)

local SupplierCatalog = {}

function SupplierCatalog.quote(speciesId: string, sizeId: string)
	if not GameConfig.Trees[speciesId] or not GameConfig.isValidSize(sizeId) then
		return nil
	end
	local unitCost = GameConfig.wholesaleFor(speciesId, sizeId)
	if not unitCost then
		return nil
	end
	return {
		speciesId = speciesId,
		sizeId = sizeId,
		unitCost = unitCost,
		maxQuantity = GameConfig.MaxOrderQuantity,
	}
end

function SupplierCatalog.list()
	local quotes = {}
	for speciesId in pairs(GameConfig.Trees) do
		for _, sizeId in ipairs({ "Small", "Medium", "Large" }) do
			table.insert(quotes, SupplierCatalog.quote(speciesId, sizeId))
		end
	end
	return quotes
end

return SupplierCatalog
