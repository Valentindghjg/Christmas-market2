--!strict
-- Player settings (CM2-MUSIC, docs/plans/CM2-MUSIC.md): the validated, rate-limited
-- Settings.SetMusicVolume action and the MusicVolume player attribute. The volume lives in the
-- player profile (`musicVolume`, nil = default, no SaveProfile.VERSION bump). Headless: every
-- engine call comes in through injected deps (main.server.lua wires Players).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MusicSettings = require(Shared:WaitForChild("MusicSettings"))
local Protocol = require(Shared:WaitForChild("Protocol"))

local Config = GameConfig.Music

local PlayerSettingsService = {}
PlayerSettingsService.__index = PlayerSettingsService

-- deps: saveSlots, clock(), setAttribute(userId, name, value).
function PlayerSettingsService.new(deps)
	local self = setmetatable({}, PlayerSettingsService)
	self._saveSlots = deps.saveSlots
	self._clock = deps.clock
	self._setAttribute = deps.setAttribute
	self._limiter = Protocol.newRateLimiter(Config.SetLimit.limit, Config.SetLimit.window)
	-- Users whose change is in flight on this server.
	self._busy = {}
	return self
end

local function failure(code: string)
	return { ok = false, errorCode = code }
end

function PlayerSettingsService:handle(userId: number, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return failure(validationError :: string)
	end
	if request.action ~= Protocol.Actions.SettingsSetMusicVolume then
		return failure("UnknownAction")
	end
	if not Protocol.allowRequest(self._limiter, userId, request.action, self._clock()) then
		return failure("RateLimited")
	end
	if self._busy[userId] then
		return failure("SettingBusy")
	end
	self._busy[userId] = true
	local volume = MusicSettings.normalize(request.payload.volume) :: number
	local called, stored, setError = pcall(self._saveSlots.setMusicVolume, self._saveSlots, userId, volume)
	self._busy[userId] = nil
	if not called then
		warn(string.format("[ChristmasMarket2] music volume failed for %d: %s", userId, tostring(stored)))
		return failure("InternalError")
	end
	if stored == nil then
		return failure(setError or "ProfileUnavailable")
	end
	self._setAttribute(userId, "MusicVolume", stored)
	return { ok = true, data = { musicVolume = stored } }
end

-- Sets MusicVolume for a user with an open profile; does nothing otherwise.
function PlayerSettingsService:refresh(userId: number)
	local open, volume = self._saveSlots:musicVolumeOf(userId)
	if not open then
		return
	end
	self._setAttribute(userId, "MusicVolume", volume)
end

function PlayerSettingsService:onPlayerJoined(userId: number)
	self:refresh(userId)
end

function PlayerSettingsService:forgetUser(userId: number)
	Protocol.forgetUser(self._limiter, userId)
	self._busy[userId] = nil
end

return PlayerSettingsService
