--!strict
-- Guided tutorial progress (CM2-49, docs/plans/CM2-49.md). Pure logic over the company
-- record's `tutorial = { step, skipped }`; the server advances it on gameplay events and the
-- client only reads the `TutorialStep` attribute. PROVISIONAL: the reference tutorial is not
-- observed.
local Tutorial = {}

Tutorial.Steps = { "Order", "Stock", "Checkout", "Done" }
Tutorial.EventStep = { Ordered = "Order", Stocked = "Stock", Sold = "Checkout" }

local function stepIndex(step: any): number?
	for index, name in Tutorial.Steps do
		if name == step then
			return index
		end
	end
	return nil
end

function Tutorial.new(active: boolean): { step: string, skipped: boolean }
	return { step = if active then "Order" else "Done", skipped = false }
end

-- Valid: a known step, a boolean `skipped`, and `skipped` only on `Done`. Extra keys are ignored.
function Tutorial.isValid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	if stepIndex(value.step) == nil or type(value.skipped) ~= "boolean" then
		return false
	end
	if value.skipped == true and value.step ~= "Done" then
		return false
	end
	return true
end

-- An event completes its step and every earlier one; events for finished steps change nothing.
function Tutorial.advance(state: any, event: string): boolean
	if type(state) ~= "table" or not Tutorial.isValid(state.tutorial) then
		return false
	end
	local tutorial = state.tutorial
	if tutorial.step == "Done" then
		return false
	end
	local eventStep = Tutorial.EventStep[event]
	if eventStep == nil then
		return false
	end
	local current = stepIndex(tutorial.step) :: number
	local target = stepIndex(eventStep) :: number
	if current <= target then
		tutorial.step = Tutorial.Steps[target + 1]
		return true
	end
	return false
end

-- CM2-SALE1: on the Checkout step the next walking customer buys for sure (tutorial customer).
function Tutorial.guaranteesSale(state: any): boolean
	return type(state) == "table" and Tutorial.isValid(state.tutorial) and state.tutorial.step == "Checkout"
end

function Tutorial.skip(state: any): (boolean, any)
	if type(state) ~= "table" or not Tutorial.isValid(state.tutorial) then
		return false, "InvalidState"
	end
	if state.tutorial.step == "Done" then
		return false, "TutorialDone"
	end
	state.tutorial.step = "Done"
	state.tutorial.skipped = true
	return true, { step = "Done" }
end

-- The `TutorialStep` player attribute: the step, "Skipped" for a skipped tutorial, nil if invalid.
function Tutorial.attribute(state: any): string?
	if type(state) ~= "table" or not Tutorial.isValid(state.tutorial) then
		return nil
	end
	if state.tutorial.step == "Done" and state.tutorial.skipped == true then
		return "Skipped"
	end
	return state.tutorial.step
end

return Tutorial
