--!strict
-- Music volume rules (CM2-MUSIC, docs/plans/CM2-MUSIC.md): the optional profile field
-- `musicVolume` (nil = default, finite in [0, 1], two decimals). Pure; shared by
-- SaveProfile, SaveSlotService, PlayerSettingsService and Music.client.lua.
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.Music
local STEP = Config.VolumeStep

local MusicSettings = {}
MusicSettings.DEFAULT = Config.DefaultVolume

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Clamps to [0, 1] and rounds to two decimals; nil plus "InvalidVolume" for anything else.
function MusicSettings.normalize(raw: unknown): (number?, string?)
	if not isFiniteNumber(raw) then
		return nil, "InvalidVolume"
	end
	local value = math.clamp(raw :: number, 0, 1)
	return math.floor(value * 100 + 0.5) / 100, nil
end

-- nil (default) or a finite number in [0, 1].
function MusicSettings.isValid(value: unknown): boolean
	if value == nil then
		return true
	end
	return isFiniteNumber(value) and (value :: number) >= 0 and (value :: number) <= 1
end

function MusicSettings.volumeOf(profile): number
	if type(profile) == "table" and type(profile.musicVolume) == "number" then
		return profile.musicVolume
	end
	return MusicSettings.DEFAULT
end

-- One VolumeStep up (direction 1) or down (direction -1), clamped and rounded.
function MusicSettings.step(volume: number, direction: number): number
	local stepped = MusicSettings.normalize(math.floor(volume / STEP + direction + 0.5) * STEP)
	return stepped :: number
end

function MusicSettings.percent(volume: number): number
	return math.floor(volume * 100 + 0.5)
end

-- The Sound.SoundId of a GameConfig.Music.TrackIds entry (asset IDs stay out of client files).
function MusicSettings.soundId(id: number): string
	return "rbxassetid://" .. string.format("%d", id)
end

return MusicSettings
