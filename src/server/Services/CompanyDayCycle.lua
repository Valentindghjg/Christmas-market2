--!strict
-- Day/night clock of the company service (CM2-G12a, docs/archive/plans/CM2-G12a.md): a mixin that
-- CompanyStateService installs. Each save keeps its own `dayCycle` (shared/DayCycle.lua,
-- schema 20). It runs only while the save's session is healthy and not unloading, so there is
-- no offline progress. A day rollover marks the session dirty without a revision; trusted
-- server code (main.server.lua) mirrors the clock into player attributes through the handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))

local CompanyDayCycle = {}

function CompanyDayCycle.install(CompanyStateService)
	function CompanyStateService:setDayChangedHandler(handler: (companyId: string) -> ())
		self._dayChanged = handler
	end

	function CompanyStateService:_notifyDay(companyId: string, session)
		local handler = self._dayChanged
		if handler and self._sessions[companyId] == session then
			local ok, err = pcall(handler, companyId)
			if not ok then
				warn(string.format("[ChristmasMarket2] day notify failed for %s: %s", companyId, tostring(err)))
			end
		end
	end

	-- Advances the clock of every healthy, loaded session. Returns (true, rolled, 0) for the
	-- server loop, where rolled counts the companies that started a new day.
	function CompanyStateService:tickDayAll(seconds: number): (boolean, number, number)
		local rolled = {}
		for _, companyId in ipairs(self:_companyIds()) do
			local session = self._sessions[companyId]
			if session and session.healthy and not session.unloading then
				local entered, added = self:_withSession(companyId, session, function(state)
					local days = DayCycle.advance(state.dayCycle, seconds)
					if days > 0 then
						session.dirty = true
					end
					return days
				end)
				if entered and added > 0 then
					table.insert(rolled, { companyId = companyId, session = session })
				end
			end
		end
		for _, entry in ipairs(rolled) do
			self:_notifyDay(entry.companyId, entry.session)
		end
		return true, #rolled, 0
	end

	-- Read-only view of an available session's clock; nil otherwise.
	function CompanyStateService:dayView(
		companyId: string
	): { day: number, elapsed: number, night: boolean, arrivalRate: number }?
		if not self:isAvailable(companyId) then
			return nil
		end
		local cycle = self._sessions[companyId].state.dayCycle
		return {
			day = cycle.day,
			elapsed = cycle.elapsed,
			night = DayCycle.isNight(cycle.elapsed),
			arrivalRate = DayCycle.arrivalRate(cycle.elapsed),
		}
	end

	-- Customer arrival rate of an available session (night 0.5); 1 otherwise.
	function CompanyStateService:arrivalRate(companyId: string): number
		if not self:isAvailable(companyId) then
			return 1
		end
		return DayCycle.arrivalRate(self._sessions[companyId].state.dayCycle.elapsed)
	end

	-- Studio test instrument only (StudioTestService): sets the day (kept when nil) and elapsed.
	function CompanyStateService:setDayForTest(companyId: string, day: number?, elapsed: number): boolean
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		if
			day ~= nil
			and (type(day) ~= "number" or day ~= day or day == math.huge or day ~= math.floor(day) or day < 1)
		then
			return false
		end
		if type(elapsed) ~= "number" or not (elapsed >= 0 and elapsed < DayCycle.length()) then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			state.dayCycle = { day = day or state.dayCycle.day, elapsed = elapsed }
			session.dirty = true
			return true
		end)
		if entered then
			self:_notifyDay(companyId, session)
		end
		return entered
	end
end

return CompanyDayCycle
