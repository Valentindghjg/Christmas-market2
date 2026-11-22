--!strict
-- Pure player-profile schema (CM2-S1): the saves a player can choose from. The profile is
-- lock-free; SaveSlotService applies every change as one UpdateAsync transform.
local GameConfig = require(script.Parent.GameConfig)

local SaveProfile = {}
SaveProfile.VERSION = 1

local SAVES = GameConfig.Saves
local ROLES = { Owner = true, Member = true }
local SIZES = { Solo = true, Duo = true, Trio = true, Quad = true }
local LEGACY_STATES = { Pending = true, Done = true, None = true }

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function isTimestamp(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 0
end

function SaveProfile.new(userId: number, now: number)
	return {
		profileVersion = SaveProfile.VERSION,
		userId = userId,
		createdAt = now,
		updatedAt = now,
		saves = {},
		nextSaveNumber = 1,
		lastSaveId = nil,
		legacyState = "Pending",
		legacySaveId = nil,
		recentCreates = {},
	}
end

SaveProfile.KEY_MAX_LENGTH = 50 -- Roblox DataStore key limit (KeyNameLimit)
SaveProfile.SAVE_ID_MAX_LENGTH = 36

-- Decimal text of a user ID. Luau `tostring` writes 19-digit numbers in exponent form, so
-- every key or ID that contains a user ID uses this instead.
function SaveProfile.userIdText(userId: number): string
	return string.format("%d", userId)
end

-- `<ownerUserId>_<16 lowercase hex>` from GUID chars 17-32; at most 36 chars, so
-- `company:save:<saveId>` stays within the 50-char key limit for a 19-digit user ID.
function SaveProfile.newSaveId(userId: number, guid: string): string
	local hex = string.lower((string.gsub(guid, "-", "")))
	return SaveProfile.userIdText(userId) .. "_" .. string.sub(hex, 17, 32)
end

-- `<ownerUserId>_<16 lowercase hex>`: 1-19 digits, at most 36 bytes.
function SaveProfile.isSaveId(value: unknown): boolean
	if type(value) ~= "string" or #value > SaveProfile.SAVE_ID_MAX_LENGTH then
		return false
	end
	local digits, hex = string.match(value, "^(%d+)_(%x+)$")
	return digits ~= nil
		and hex ~= nil
		and #digits >= 1
		and #digits <= 19
		and #hex == 16
		and string.find(hex, "%u") == nil
end

-- Returns the trimmed name with single spaces, or nil plus "NameInvalid".
function SaveProfile.normalizeName(raw: unknown): (string?, string?)
	if type(raw) ~= "string" or #raw > SAVES.NamePayloadMaxBytes or utf8.len(raw) == nil then
		return nil, "NameInvalid"
	end
	if string.find(raw, "%c") or string.find(raw, "#", 1, true) then
		return nil, "NameInvalid"
	end
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	local collapsed = string.gsub(trimmed, "%s+", " ")
	local length = utf8.len(collapsed)
	if length == nil or length < 1 or length > SAVES.NameMaxLength then
		return nil, "NameInvalid"
	end
	return collapsed, nil
end

-- The typed confirmation matches the save name, ignoring case and extra spaces.
function SaveProfile.confirmMatches(name: unknown, typed: unknown): boolean
	local normalized = SaveProfile.normalizeName(typed)
	return normalized ~= nil and type(name) == "string" and string.lower(normalized) == string.lower(name)
end

function SaveProfile.find(profile, saveId: unknown)
	if type(profile) ~= "table" or type(profile.saves) ~= "table" then
		return nil, nil
	end
	for index, entry in ipairs(profile.saves) do
		if entry.saveId == saveId then
			return entry, index
		end
	end
	return nil, nil
end

-- Case-insensitive; exceptSaveId skips the save that is being renamed.
function SaveProfile.nameTaken(profile, name: string, exceptSaveId: string?): boolean
	local lowered = string.lower(name)
	for _, entry in ipairs(profile.saves) do
		if entry.saveId ~= exceptSaveId and type(entry.name) == "string" and string.lower(entry.name) == lowered then
			return true
		end
	end
	return false
end

local function validEntry(entry): boolean
	return type(entry) == "table"
		and SaveProfile.isSaveId(entry.saveId)
		and type(entry.name) == "string"
		and SaveProfile.normalizeName(entry.name) == entry.name
		and ROLES[entry.role] == true
		and SIZES[entry.size] == true
		and isTimestamp(entry.createdAt)
		and isTimestamp(entry.lastPlayedAt)
end

local function isArray(value): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for _ in pairs(value) do
		count += 1
	end
	return count == #value
end

function SaveProfile.validate(profile): boolean
	if type(profile) ~= "table" or profile.profileVersion ~= SaveProfile.VERSION then
		return false
	end
	if not isFiniteInteger(profile.userId) or profile.userId < 0 then
		return false
	end
	if not isTimestamp(profile.createdAt) or not isTimestamp(profile.updatedAt) then
		return false
	end
	if not isArray(profile.saves) or #profile.saves > SAVES.MaxSavesPerPlayer then
		return false
	end
	local seen = {}
	for _, entry in ipairs(profile.saves) do
		if not validEntry(entry) or seen[entry.saveId] then
			return false
		end
		seen[entry.saveId] = true
	end
	if not isFiniteInteger(profile.nextSaveNumber) or profile.nextSaveNumber < 1 then
		return false
	end
	if profile.lastSaveId ~= nil and not SaveProfile.isSaveId(profile.lastSaveId) then
		return false
	end
	if not LEGACY_STATES[profile.legacyState] then
		return false
	end
	if profile.legacySaveId ~= nil and not SaveProfile.isSaveId(profile.legacySaveId) then
		return false
	end
	if not isArray(profile.recentCreates) or #profile.recentCreates > SAVES.RecentCreates then
		return false
	end
	for _, created in ipairs(profile.recentCreates) do
		if
			type(created) ~= "table"
			or type(created.requestId) ~= "string"
			or not SaveProfile.isSaveId(created.saveId)
		then
			return false
		end
	end
	return true
end

-- Entries for the save picker: last played first, then newest, then by ID.
function SaveProfile.listView(profile, activeSaveId: string?)
	local view = {}
	for _, entry in ipairs(profile.saves) do
		table.insert(view, {
			saveId = entry.saveId,
			name = entry.name,
			role = entry.role,
			size = entry.size,
			createdAt = entry.createdAt,
			lastPlayedAt = entry.lastPlayedAt,
			active = entry.saveId == activeSaveId,
			lastPlayed = profile.lastSaveId ~= nil and entry.saveId == profile.lastSaveId,
		})
	end
	table.sort(view, function(a, b)
		if a.lastPlayedAt ~= b.lastPlayedAt then
			return a.lastPlayedAt > b.lastPlayedAt
		end
		if a.createdAt ~= b.createdAt then
			return a.createdAt > b.createdAt
		end
		return a.saveId < b.saveId
	end)
	return view
end

return SaveProfile
