--!strict
-- Pure helpers shared by SaveSlotService and its parts (CM2-RF).
-- Moved unchanged from SaveSlotService.lua.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))

local SaveSlotShared = {}

local function companyIdOf(saveId: string): string
	return "save:" .. saveId
end

local function saveIdOf(companyId: string?): string?
	if type(companyId) ~= "string" then
		return nil
	end
	return string.match(companyId, "^save:(.+)$")
end

local function failure(errorCode: string?)
	return { ok = false, errorCode = errorCode or "InternalError" }
end

local function newEntry(saveId: string, name: string, now: number, size: string?)
	return {
		saveId = saveId,
		name = name,
		role = "Owner",
		size = size or "Solo",
		createdAt = now,
		lastPlayedAt = 0,
	}
end
local function sortedKeys(map): { number }
	local keys = {}
	for key in pairs(map) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end
local function callHandler(handler, label: string, ...)
	if handler then
		local ok, err = pcall(handler, ...)
		if not ok then
			warn(string.format("[ChristmasMarket2] %s handler errored: %s", label, tostring(err)))
		end
	end
end
-- Every transform after the profile exists starts from a valid stored profile.
local function storedProfile(stored)
	if stored == nil then
		return nil, "ProfileUnavailable"
	end
	if not SaveProfile.validate(stored) then
		return nil, "ProfileCorrupt"
	end
	return stored, nil
end
SaveSlotShared.companyIdOf = companyIdOf
SaveSlotShared.saveIdOf = saveIdOf
SaveSlotShared.failure = failure
SaveSlotShared.newEntry = newEntry
SaveSlotShared.sortedKeys = sortedKeys
SaveSlotShared.callHandler = callHandler
SaveSlotShared.storedProfile = storedProfile

return SaveSlotShared
