--!strict
-- Save picker request gate and list refresh (CM2-SP1): one request at a time, a refresh asked for during a request runs after it, a busy list is retried, and a busy or list error status is cleared by the next successful list. Pure; the picker injects remote calls and timers.

local SaveListSync = {}
SaveListSync.RetrySeconds = 1 -- PROVISIONAL (CM2-SP1 D4)
SaveListSync.RetryLimit = 10 -- PROVISIONAL (CM2-SP1 D4)
SaveListSync.ListAction = "Save.List"
SaveListSync.BusyCode = "SaveActionBusy"

export type Deps = {
	invoke: (action: string, payload: { [string]: any }) -> any, -- yields; the response table
	defer: (callback: () -> ()) -> (),
	delay: (seconds: number, callback: () -> ()) -> (),
	isOpen: () -> boolean,
	render: (saves: { any }?) -> (), -- nil redraws the last list
	getStatus: () -> string,
	setStatus: (text: string) -> (),
	errorText: (errorCode: unknown) -> string,
	onBusyAnswer: (count: number) -> (),
}

export type Sync = {
	request: (action: string, payload: { [string]: any }) -> any, -- nil while another is in flight
	inFlight: () -> boolean,
	refresh: () -> (),
	showTransient: (errorCode: unknown) -> (),
	busyAnswers: () -> number,
}

function SaveListSync.new(deps: Deps): Sync
	local inFlight = false
	-- A refresh was asked for while a request was in flight; it runs after that request.
	local pending = false
	-- Each refresh chain gets a new generation; a retry of an older chain does nothing.
	local generation = 0
	-- The status text this module set last; a successful list clears it only if it still shows.
	local transientText: string? = nil
	local busyCount = 0

	local attempt: (number) -> ()
	local refresh: () -> ()

	local function request(action: string, payload: { [string]: any }): any
		if inFlight then
			return nil
		end
		inFlight = true
		local called, response = pcall(deps.invoke, action, payload)
		inFlight = false
		if not called or type(response) ~= "table" then
			response = { ok = false, errorCode = "ConnectionError" }
		end
		if pending then
			pending = false
			deps.defer(refresh)
		end
		return response
	end

	local function showTransient(code: unknown)
		local text = deps.errorText(code)
		deps.setStatus(text)
		transientText = text
	end

	attempt = function(retriesLeft: number)
		if not deps.isOpen() then
			return
		end
		if inFlight then
			pending = true
			return
		end
		generation += 1
		local mine = generation
		-- Never nil here: nothing yields between the check above and this call.
		local response = request(SaveListSync.ListAction, {})
		if response.ok == true and type(response.data) == "table" then
			if transientText ~= nil and deps.getStatus() == transientText then
				deps.setStatus("")
			end
			transientText = nil
			deps.render(if type(response.data.saves) == "table" then response.data.saves else {})
			return
		end
		showTransient(response.errorCode)
		deps.render(nil)
		if response.errorCode == SaveListSync.BusyCode then
			busyCount += 1
			deps.onBusyAnswer(busyCount)
			if retriesLeft > 0 then
				deps.delay(SaveListSync.RetrySeconds, function()
					if mine == generation then
						attempt(retriesLeft - 1)
					end
				end)
			end
		end
	end

	refresh = function()
		attempt(SaveListSync.RetryLimit)
	end

	return {
		request = request,
		inFlight = function()
			return inFlight
		end,
		refresh = refresh,
		showTransient = showTransient,
		busyAnswers = function()
			return busyCount
		end,
	}
end

return SaveListSync
