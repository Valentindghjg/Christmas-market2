--!strict
-- Modal coordinator (CM2-40, CM2-UVF1): one claimed dialog at a time; the save picker is the base
-- layer, closed by any claim except the ids in OverBase.
local ModalCoordinator = {}

export type Coordinator = {
	claim: (id: string, close: () -> ()) -> (),
	release: (id: string) -> (),
	closeAll: () -> (),
	setBase: (close: (() -> ())?) -> (),
}

-- Modal ids that open over the base layer without closing it. PROVISIONAL (CM2-S3 design).
ModalCoordinator.OverBase = table.freeze({ Finder = true }) :: { [string]: boolean }

function ModalCoordinator.new(): Coordinator
	local holders: { [string]: () -> () } = {}
	local base: (() -> ())? = nil

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
	end

	local function release(id: string)
		holders[id] = nil
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
	end

	local function setBase(close: (() -> ())?)
		base = close
	end

	return { claim = claim, release = release, closeAll = closeAll, setBase = setBase }
end

return ModalCoordinator
