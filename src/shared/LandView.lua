--!strict
-- Pure text mapping for the Lot Manager's Land tab (CM2-G9b, docs/archive/plans/CM2-G9b.md). Turns the
-- server's `progression` summary (Progression.summary) into `{key, args}` lines; the tab only
-- localizes and shows them. No requirement is computed here.
local GameConfig = require(script.Parent.GameConfig)
local Localization = require(script.Parent.Localization)
local UiTheme = require(script.Parent.UiTheme)

local LandView = {}

export type Line = { key: string, args: { any }, met: boolean? }

LandView.ERROR_KEYS = {
	AlreadyOwned = "landErrorOwned",
	NotNextLevel = "landErrorOrder",
	PrerequisitesNotMet = "landErrorRequirements",
	InsufficientReputation = "landErrorReputation",
	InsufficientFunds = "insufficientFunds",
	RateLimited = "saveErrorRateLimited",
}

local function money(value: number): string
	return "$" .. UiTheme.formatMoney(value)
end

local function hasKey(key: string): boolean
	return Localization.Strings.en[key] ~= nil
end

function LandView.levelNameKey(id: string?): string
	if id == nil then
		return "landLevel_Starter"
	end
	return "landLevel_" .. id
end

function LandView.hqNameKey(id: string): string
	return "hq_" .. id
end

function LandView.rowLine(row: any): Line
	local id = tostring(row.id)
	local met = row.met == true
	local key = "landRow" .. id
	if not hasKey(key) then
		return { key = "landRowUnknown", args = { id }, met = met }
	end
	local args: { any }
	if id == "Cash" then
		args = { money(row.have), money(row.need) }
	elseif id == "LotManager" then
		args = {}
	else
		args = { row.have, row.need }
	end
	return { key = key, args = args, met = met }
end

function LandView.unlockLine(unlock: any): Line
	local id = tostring(unlock.id)
	local key = "landUnlock" .. id .. (if unlock.active == true then "" else "Soon")
	if not hasKey(key) then
		return { key = "landRowUnknown", args = { id } }
	end
	return { key = key, args = if type(unlock.value) == "number" then { unlock.value } else {} }
end

function LandView.statusLine(kind: string, section: any): Line
	if kind == "LotExpansion" then
		local level: number = section.level
		local id: string? = if level > 0 then GameConfig.Progression.LotExpansion.levels[level].id else nil
		return {
			key = "landLotStatus",
			args = { { nameKey = LandView.levelNameKey(id) }, level, section.maxLevel, section.storage },
		}
	elseif kind == "Parking" then
		return { key = "landParkingStatus", args = { section.tier, section.spaces } }
	end
	return {
		key = "landHqStatus",
		args = { section.level, section.maxLevel, { nameKey = LandView.hqNameKey(section.id) } },
	}
end

function LandView.nextLine(kind: string, offer: any?): Line
	if offer == nil then
		return { key = "landMaxed", args = {} }
	end
	if kind == "LotExpansion" then
		return {
			key = "landNextLot",
			args = { offer.target, { nameKey = LandView.levelNameKey(offer.id) }, money(offer.cashCost) },
		}
	elseif kind == "Parking" then
		local spaces = 0
		for _, unlock in ipairs(offer.unlocks) do
			if unlock.id == "ParkingSpaces" and type(unlock.value) == "number" then
				spaces = unlock.value
			end
		end
		return { key = "landNextParking", args = { offer.target, spaces, money(offer.cashCost) } }
	end
	return {
		key = "landNextHq",
		args = { { nameKey = LandView.hqNameKey(offer.id) }, money(offer.cashCost) },
	}
end

return LandView
