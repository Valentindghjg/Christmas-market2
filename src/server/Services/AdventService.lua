--!strict
-- Advent calendar (CM2-A1, docs/plans/CM2-A1.md): the validated, rate-limited Advent.Open
-- action and the Advent* player attributes. Headless: every engine call comes in through
-- injected deps (main.server.lua wires Players).
--
-- Open order: validate -> rate limit -> in-flight guard -> active, available save -> the
-- profile UpdateAsync sets the door's bit (atomic once-per-player guard across saves and
-- servers) -> the save is still active -> the grant in the company critical section. A refused
-- grant clears exactly this bit; a failed revert only warns, so a door is lost at most once and
-- never paid twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))

local Config = GameConfig.Advent

local AdventService = {}
AdventService.__index = AdventService

-- deps: saveSlots, companies, clock(), setAttribute(userId, name, value).
function AdventService.new(deps)
	local self = setmetatable({}, AdventService)
	self._saveSlots = deps.saveSlots
	self._companies = deps.companies
	self._clock = deps.clock
	self._setAttribute = deps.setAttribute
	self._limiter = Protocol.newRateLimiter(Config.OpenLimit.limit, Config.OpenLimit.window)
	-- Users whose open is in flight on this server.
	self._busy = {}
	-- Studio test override of the calendar's time only (never the business clock).
	self._nowOverride = nil
	return self
end

local function failure(code: string)
	return { ok = false, errorCode = code }
end

function AdventService:_now(): number
	local override = self._nowOverride
	if override ~= nil then
		return override
	end
	return self._clock()
end

function AdventService:_open(userId: number, door: number)
	local companyId = self._saveSlots:activeCompanyId(userId)
	if companyId == nil or not self._companies:isAvailable(companyId) then
		return failure("CompanyUnavailable")
	end
	local year, openError = self._saveSlots:openAdventDoor(userId, self:_now(), door)
	if year == nil then
		return failure(openError or "ProfileUnavailable")
	end
	local reward = AdventCalendar.rewardFor(door)
	local extras = { boostSeconds = reward.boostSeconds, decorId = reward.decor }
	local granted, result = false, "CompanyUnavailable"
	if self._saveSlots:activeCompanyId(userId) == companyId then
		granted, result =
			self._companies:grantReward(companyId, userId, "AdventReward", reward.cash, reward.reputation, extras)
	end
	if not granted then
		if not self._saveSlots:revertAdventDoor(userId, year, door) then
			warn(
				string.format(
					"[ChristmasMarket2] advent reward lost for %d (door %d): %s",
					userId,
					door,
					tostring(result)
				)
			)
		end
		return failure(result)
	end
	return {
		ok = true,
		revision = result.revision,
		data = {
			door = door,
			cash = reward.cash,
			reputation = reward.reputation,
			boostSeconds = result.boostSeconds,
			decor = reward.decor,
		},
	}
end

function AdventService:handle(userId: number, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return failure(validationError :: string)
	end
	if request.action ~= Protocol.Actions.AdventOpen then
		return failure("UnknownAction")
	end
	if not Protocol.allowRequest(self._limiter, userId, request.action, self._clock()) then
		return failure("RateLimited")
	end
	if self._busy[userId] then
		return failure("ClaimBusy")
	end
	self._busy[userId] = true
	local called, response = pcall(self._open, self, userId, request.payload.door)
	self._busy[userId] = nil
	if not called then
		warn(string.format("[ChristmasMarket2] advent open failed for %d: %s", userId, tostring(response)))
		response = failure("InternalError")
	end
	self:refresh(userId)
	return response
end

-- Sets AdventPhase, AdventToday, AdventOpened and AdventClaimable for a user with an open
-- profile; does nothing otherwise.
function AdventService:refresh(userId: number)
	local open, advent = self._saveSlots:adventOf(userId)
	if not open then
		return
	end
	local view = AdventCalendar.view(advent, self:_now())
	self._setAttribute(userId, "AdventPhase", view.phase)
	self._setAttribute(userId, "AdventToday", view.today)
	self._setAttribute(userId, "AdventOpened", view.opened)
	self._setAttribute(userId, "AdventClaimable", view.claimable)
end

function AdventService:refreshAll(userIds: { number })
	for _, userId in ipairs(userIds) do
		self:refresh(userId)
	end
end

function AdventService:onPlayerJoined(userId: number)
	self:refresh(userId)
end

function AdventService:forgetUser(userId: number)
	Protocol.forgetUser(self._limiter, userId)
end

-- Studio test instrument only (StudioTestService): overrides the calendar's time; nil clears it.
function AdventService:setNowForTest(at: number?)
	self._nowOverride = at
end

return AdventService
