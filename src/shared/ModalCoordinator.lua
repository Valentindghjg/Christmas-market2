--!strict
-- Modal coordinator (CM2-40, CM2-UVF1): one claimed dialog at a time; the save picker is the base
-- layer, closed by any claim except the ids in OverBase.
local ModalCoordinator = {}

export type Coordinator = {
	claim: (id: string, close: () -> ()) -> (),
	release: (id: string) -> (),
	closeAll: () -> (),
	setBase: (close: (() -> ())?) -> (),
	-- CM2-49: the id of a claimed modal (any holder) and whether a base layer is open.
	held: () -> string?,
	hasBase: () -> boolean,
	-- CM2-G11: listener called after every change; returns its remover.
	onChange: (listener: () -> ()) -> () -> (),
}

-- Modal ids that open over the base layer without closing it. PROVISIONAL (CM2-S3 design).
ModalCoordinator.OverBase = table.freeze({ Finder = true }) :: { [string]: boolean }

function ModalCoordinator.new(): Coordinator
	local holders: { [string]: () -> () } = {}
	local base: (() -> ())? = nil
	local listeners: { () -> () } = {}

	local function notify()
		for _, listener in ipairs(table.clone(listeners)) do
			listener()
		end
	end

	-- All state changes happen before any close callback runs.
	local function claim(id: string, close: () -> ())
		local toClose: { () -> () } = {}
		for otherId, otherClose in pairs(holders) do
			if otherId ~= id then
				table.insert(toClose, otherClose)
				holders[otherId] = nil
			end
		end
		holders[id] = close
		if not ModalCoordinator.OverBase[id] and base ~= nil then
			table.insert(toClose, base)
			base = nil
		end
		for _, callback in ipairs(toClose) do
			callback()
		end
		notify()
	end

	local function release(id: string)
		holders[id] = nil
		notify()
	end

	local function closeAll()
		local toClose: { () -> () } = {}
		for id, close in pairs(holders) do
			table.insert(toClose, close)
			holders[id] = nil
		end
		for _, callback in ipairs(toClose) do
			callback()
		end
		notify()
	end

	local function setBase(close: (() -> ())?)
		base = close
		notify()
	end

	local function held(): string?
		return (next(holders))
	end

	local function hasBase(): boolean
		return base ~= nil
	end

	local function onChange(listener: () -> ()): () -> ()
		table.insert(listeners, listener)
		return function()
			local index = table.find(listeners, listener)
			if index then
				table.remove(listeners, index)
			end
		end
	end

	return {
		claim = claim,
		release = release,
		closeAll = closeAll,
		setBase = setBase,
		held = held,
		hasBase = hasBase,
		onChange = onChange,
	}
end

return ModalCoordinator
