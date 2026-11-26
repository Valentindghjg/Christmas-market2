--!strict
-- Daily reward streak (CM2-G11, docs/plans/CM2-G11.md): the validated, rate-limited
-- Daily.Claim action and the Daily* player attributes. Headless: every engine call comes in
-- through injected deps (main.server.lua wires Players and the group check).
--
-- Claim order: validate -> rate limit -> in-flight guard -> active, available save -> group
-- check (may yield) -> the profile UpdateAsync marks the day (atomic once-per-day guard) ->
-- the save is still active -> the grant in the company critical section. A refused grant
-- reverts exactly this claim; a failed revert only warns, so a reward is lost at most once
-- and never paid twice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))

local Config = GameConfig.DailyRewards

local DailyRewardService = {}
DailyRewardService.__index = DailyRewardService

-- deps: saveSlots, companies, clock(), isInGroup(userId, groupId) (may yield or error),
-- setAttribute(userId, name, value).
function DailyRewardService.new(deps)
	local self = setmetatable({}, DailyRewardService)
	self._saveSlots = deps.saveSlots
	self._companies = deps.companies
	self._clock = deps.clock
	self._isInGroup = deps.isInGroup
	self._setAttribute = deps.setAttribute
	self._limiter = Protocol.newRateLimiter(Config.ClaimLimit.limit, Config.ClaimLimit.window)
	-- Users whose claim is in flight on this server.
	self._busy = {}
	-- Last known group membership per user (membership may be cached per server).
	self._member = {}
	-- Studio test override { groupId, member }; nil uses GameConfig and the group check.
	self._override = nil
	return self
end

local function failure(code: string)
	return { ok = false, errorCode = code }
end

-- The effective group ID and the membership known without a group call.
function DailyRewardService:_groupInfo(userId: number): (number, boolean)
	local override = self._override
	if override ~= nil then
		return override.groupId, override.member == true
	end
	return Config.GroupId, self._member[userId] == true
end

function DailyRewardService:_isMember(userId: number): boolean
	local override = self._override
	if override ~= nil then
		return override.groupId ~= 0 and override.member == true
	end
	local groupId = Config.GroupId
	if groupId == 0 then
		return false
	end
	local ok, result = pcall(self._isInGroup, userId, groupId)
	if ok then
		self._member[userId] = result == true
		return result == true
	end
	return self._member[userId] == true
end

function DailyRewardService:_claim(userId: number)
	local companyId = self._saveSlots:activeCompanyId(userId)
	if companyId == nil or not self._companies:isAvailable(companyId) then
		return failure("CompanyUnavailable")
	end
	local member = self:_isMember(userId)
	local today = DailyRewards.dayOf(self._clock())
	local index, previous, claimError = self._saveSlots:claimDaily(userId, today)
	if index == nil then
		return failure(claimError or "ProfileUnavailable")
	end
	local reward = DailyRewards.rewardFor(index, member)
	local granted, result = false, "CompanyUnavailable"
	if self._saveSlots:activeCompanyId(userId) == companyId then
		granted, result = self._companies:grantReward(companyId, userId, "DailyReward", reward.cash, reward.reputation)
	end
	if not granted then
		if not self._saveSlots:revertDaily(userId, today, index, previous) then
			warn(
				string.format(
					"[ChristmasMarket2] daily reward lost for %d (day %d): %s",
					userId,
					index,
					tostring(result)
				)
			)
		end
		return failure(result)
	end
	return {
		ok = true,
		revision = result.revision,
		data = { day = index, cash = reward.cash, reputation = reward.reputation, doubled = reward.doubled },
	}
end

function DailyRewardService:handle(userId: number, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return failure(validationError :: string)
	end
	if request.action ~= Protocol.Actions.DailyClaim then
		return failure("UnknownAction")
	end
	if not Protocol.allowRequest(self._limiter, userId, request.action, self._clock()) then
		return failure("RateLimited")
	end
	if self._busy[userId] then
		return failure("ClaimBusy")
	end
	self._busy[userId] = true
	local called, response = pcall(self._claim, self, userId)
	self._busy[userId] = nil
	if not called then
		warn(string.format("[ChristmasMarket2] daily claim failed for %d: %s", userId, tostring(response)))
		response = failure("InternalError")
	end
	self:refresh(userId)
	return response
end

-- Sets DailyNext, DailyClaimable, DailySecondsLeft and DailyGroup for a user with an open
-- profile; does nothing otherwise.
function DailyRewardService:refresh(userId: number)
	local open, daily = self._saveSlots:dailyOf(userId)
	if not open then
		return
	end
	local now = self._clock()
	local status = DailyRewards.status(daily, DailyRewards.dayOf(now))
	local groupId, member = self:_groupInfo(userId)
	self._setAttribute(userId, "DailyNext", status.nextIndex)
	self._setAttribute(userId, "DailyClaimable", status.claimable)
	self._setAttribute(userId, "DailySecondsLeft", DailyRewards.secondsLeft(now))
	self._setAttribute(userId, "DailyGroup", DailyRewards.groupState(groupId, member))
end

function DailyRewardService:refreshAll(userIds: { number })
	for _, userId in ipairs(userIds) do
		self:refresh(userId)
	end
end

function DailyRewardService:onPlayerJoined(userId: number)
	self:_isMember(userId)
	self:refresh(userId)
end

function DailyRewardService:forgetUser(userId: number)
	self._member[userId] = nil
	Protocol.forgetUser(self._limiter, userId)
end

-- Studio test instrument only (StudioTestService): overrides the group ID and membership;
-- both nil clears the override.
function DailyRewardService:setGroupForTest(groupId: number?, member: boolean?)
	if groupId == nil and member == nil then
		self._override = nil
		return
	end
	self._override = { groupId = groupId or Config.GroupId, member = member == true }
end

return DailyRewardService
