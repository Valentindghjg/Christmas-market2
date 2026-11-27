--!strict
-- Guided tutorial of the company service (CM2-49, docs/plans/CM2-49.md): a mixin that
-- CompanyStateService installs. The progress lives in the company record (shared/Tutorial.lua)
-- and only server events and the validated Tutorial.Skip action change it. Trusted server code
-- (main.server.lua) mirrors it into the `TutorialStep` player attribute through the handler.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tutorial = require(Shared:WaitForChild("Tutorial"))

local CompanyTutorial = {}

function CompanyTutorial.install(CompanyStateService)
	function CompanyStateService:setTutorialChangedHandler(handler: (companyId: string, value: string?) -> ())
		self._tutorialChanged = handler
	end

	function CompanyStateService:_notifyTutorial(companyId: string, session)
		local handler = self._tutorialChanged
		if handler and self._sessions[companyId] == session then
			local ok, err = pcall(handler, companyId, Tutorial.attribute(session.state))
			if not ok then
				warn(string.format("[ChristmasMarket2] tutorial notify failed for %s: %s", companyId, tostring(err)))
			end
		end
	end

	-- _withSession: notifies once the section changed the attribute value captured before it.
	function CompanyStateService:_syncTutorial(companyId: string, session, before: string?)
		if Tutorial.attribute(session.state) ~= before then
			self:_notifyTutorial(companyId, session)
		end
	end

	-- Tutorial.Skip inside _dispatch (any member; idempotency and limits come from handle).
	function CompanyStateService:_skipTutorial(state): (boolean, any)
		return Tutorial.skip(state)
	end

	-- The save's `TutorialStep` attribute value; nil without a session.
	function CompanyStateService:tutorialAttribute(companyId: string): string?
		local session = self._sessions[companyId]
		if not session then
			return nil
		end
		return Tutorial.attribute(session.state)
	end

	-- Studio test instrument only (StudioTestService): sets the step, not skipped.
	function CompanyStateService:setTutorialForTest(companyId: string, step: string): boolean
		if table.find(Tutorial.Steps, step) == nil then
			return false
		end
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			state.tutorial = { step = step, skipped = false }
			state.revision += 1
			session.dirty = true
			return true
		end)
		return entered
	end

	-- Studio test instrument only (CM2-TUTHOOK): puts the save back on the first step, the state
	-- a new save with the tutorial offered starts in. Returns that step, nil without a session.
	function CompanyStateService:resetTutorialForTest(companyId: string): string?
		local first = Tutorial.new(true).step
		if self:setTutorialForTest(companyId, first) then
			return first
		end
		return nil
	end
end

return CompanyTutorial
