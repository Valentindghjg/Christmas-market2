--!strict
-- Walking customer NPCs (CM2-N1, docs/plans/CM2-N1.md): the director. Every customer is a
-- visit record driven by a small state machine. It requires only GameConfig and NpcPath and
-- calls no game service itself: the company service (transactions), the plot lookup, the
-- world adapter (avatar, car, tree) and the clock are injected, so it runs headless.
--
-- Money and stock change only in the company service's npc* methods (server-trusted, inside
-- the company's critical section); no client input reaches this module. A visit that loses
-- its session (unload, reload, save switch) or its plot is hard-removed without any
-- transaction; its reservation and claim are swept or cleared on reload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NpcPath = require(Shared:WaitForChild("NpcPath"))

local Npc = GameConfig.Customers.Npc

-- Float slack for timers driven by fractional tick clocks.
local EPSILON = 1e-6
local HISTORY_LIMIT = 20
local QUEUE_TAIL = 4

local CustomerNpcService = {}
CustomerNpcService.__index = CustomerNpcService

-- Every state has a positive timeout. onTimeout holds the success exit (Amendment 1, row 5),
-- except Queued and CheckingOut, whose timeout is the walk-out (CM2-N2); the other exits
-- (failed pick, failed settle, give-up, order gone, the served checkout) live in code.
CustomerNpcService.Fsm = {
	Arriving = { timeout = Npc.CarArriveSeconds, onTimeout = "WalkingIn" },
	WalkingIn = { timeout = Npc.LegTimeoutSeconds, onTimeout = "Browsing" },
	Browsing = { timeout = Npc.BrowseSeconds, onTimeout = "WalkingToTree" },
	WalkingToTree = { timeout = Npc.LegTimeoutSeconds, onTimeout = "PickingUp" },
	PickingUp = { timeout = Npc.PickUpSeconds, onTimeout = "WalkingToQueue" },
	WalkingToQueue = { timeout = Npc.LegTimeoutSeconds, onTimeout = "Queued" },
	Queued = { timeout = Npc.QueuePatienceSeconds, onTimeout = "WalkingOut" },
	CheckingOut = { timeout = Npc.QueuePatienceSeconds, onTimeout = "WalkingOut" },
	WalkingToCar = { timeout = Npc.LegTimeoutSeconds, onTimeout = "WaitingAtCar" },
	WaitingAtCar = {
		timeout = GameConfig.Customers.PickupPatienceSeconds + Npc.WaitAtCarExtraSeconds,
		onTimeout = "Departing",
	},
	WalkingOut = { timeout = Npc.LegTimeoutSeconds, onTimeout = "Departing" },
	Departing = { timeout = Npc.DepartSeconds, onTimeout = "Done" },
	LoadLoop = { timeout = Npc.LoadSeconds, onTimeout = "Departing" },
}
local Fsm = CustomerNpcService.Fsm

-- One route leg each; reaching its end and the leg timeout (with a snap) share the exit.
local LEG_STATES = {
	WalkingIn = true,
	WalkingToTree = true,
	WalkingToQueue = true,
	WalkingToCar = true,
	WalkingOut = true,
}

-- giveUpForTest works from WalkingIn up to CheckingOut.
local GIVE_UP_STATES = {
	WalkingIn = true,
	Browsing = true,
	WalkingToTree = true,
	PickingUp = true,
	WalkingToQueue = true,
	Queued = true,
	CheckingOut = true,
}

type Point = NpcPath.Point

local function validPoint(value: any): Point?
	if type(value) == "table" and type(value.x) == "number" and type(value.z) == "number" then
		return { x = value.x, z = value.z }
	end
	return nil
end

local function elapsed(now: number, since: number, seconds: number): boolean
	return now - since >= seconds - EPSILON
end

-- deps = {companies, plotOf(companyId) -> plotId?, world, now() -> seconds}
-- options = {maxPerServer?, maxPerPlot?, maxVisitSeconds?}
function CustomerNpcService.new(deps, options)
	local self = setmetatable({}, CustomerNpcService)
	local opts = if type(options) == "table" then options else {}
	self._companies = deps.companies
	self._plotOf = deps.plotOf
	self._worldAdapter = deps.world
	self._now = deps.now
	self._maxPerServer = if type(opts.maxPerServer) == "number" then opts.maxPerServer else Npc.MaxPerServer
	self._maxPerPlot = if type(opts.maxPerPlot) == "number" then opts.maxPerPlot else Npc.MaxPerPlot
	self._maxVisitSeconds = if type(opts.maxVisitSeconds) == "number" then opts.maxVisitSeconds else Npc.MaxVisitSeconds
	self._visits = {}
	self._queues = {}
	self._seq = 0
	self._stopped = false
	self._warned = {}
	self._loadSnaps = 0
	self._customerSnaps = 0
	self._snapLog = {}
	self._arrivalOverrides = {}
	return self
end

-- Every world call goes through here: an error warns once per method and counts as nil.
function CustomerNpcService:_call(method: string, ...): any
	local world = self._worldAdapter
	local fn = if type(world) == "table" then world[method] else nil
	local ok, result
	if type(fn) == "function" then
		ok, result = pcall(fn, world, ...)
	else
		ok, result = false, "missing method"
	end
	if not ok then
		if not self._warned[method] then
			self._warned[method] = true
			warn(string.format("[ChristmasMarket2] NpcWorldFailed %s: %s", method, tostring(result)))
		end
		return nil
	end
	return result
end

function CustomerNpcService:_position(visit): Point?
	return validPoint(self:_call("position", visit.id))
end

-- Live visits in spawn order.
function CustomerNpcService:_ordered()
	local list = {}
	for _, visit in pairs(self._visits) do
		table.insert(list, visit)
	end
	table.sort(list, function(a, b)
		return a.seq < b.seq
	end)
	return list
end

-- Queue -------------------------------------------------------------------------------------

function CustomerNpcService:_joinQueue(visit)
	local queue = self._queues[visit.plotId]
	if queue == nil then
		queue = {}
		self._queues[visit.plotId] = queue
	end
	if table.find(queue, visit.id) == nil then
		table.insert(queue, visit.id)
	end
end

function CustomerNpcService:_leaveQueue(visit)
	local queue = self._queues[visit.plotId]
	if queue == nil then
		return
	end
	local index = table.find(queue, visit.id)
	if index ~= nil then
		table.remove(queue, index)
	end
	if #queue == 0 then
		self._queues[visit.plotId] = nil
	end
end

function CustomerNpcService:_queueIndex(visit): number
	local queue = self._queues[visit.plotId]
	return if queue then table.find(queue, visit.id) or 1 else 1
end

-- Movement ----------------------------------------------------------------------------------

-- Routes from the avatar's position (or its last goal) to `to` and issues the first MoveTo.
function CustomerNpcService:_startRoute(visit, to: Point, now: number)
	local from = self:_position(visit) or visit.goal
	visit.waypoints = NpcPath.route(from, to, visit.level)
	visit.waypointIndex = 1
	visit.legStartedAt = now
	visit.lastPos = nil
	visit.goal = visit.waypoints[#visit.waypoints] or to
	local first = visit.waypoints[1]
	if first ~= nil then
		self:_call("moveTo", visit.id, first)
	end
	visit.issuedAt = now
end

-- Stays at the current point: the leg is done at once.
function CustomerNpcService:_stay(visit, now: number)
	visit.waypoints = {}
	visit.waypointIndex = 1
	visit.legStartedAt = now
	visit.issuedAt = now
	visit.lastPos = nil
end

-- Advances the waypoint and re-issues MoveTo after ReissueSeconds; returns true once the
-- route is done. The last waypoint counts as reached within ArriveRadius; an intermediate
-- corner within CornerRadius, or within ArriveRadius once the avatar has stopped (moved
-- < STOPPED_STUDS since the previous call), so routes do not cut the obstacle corners.
local STOPPED_STUDS = 0.05

function CustomerNpcService:_advance(visit, now: number): boolean
	local target = visit.waypoints[visit.waypointIndex]
	if target == nil then
		return true
	end
	local position = self:_position(visit)
	local radius = Npc.ArriveRadius
	if visit.waypointIndex < #visit.waypoints then
		local stopped = position ~= nil
			and visit.lastPos ~= nil
			and NpcPath.distance(position, visit.lastPos) < STOPPED_STUDS
		radius = if stopped then Npc.ArriveRadius else Npc.CornerRadius
	end
	local done = false
	if position ~= nil and NpcPath.distance(position, target) <= radius then
		visit.waypointIndex += 1
		local nextPoint = visit.waypoints[visit.waypointIndex]
		if nextPoint == nil then
			done = true
		else
			self:_call("moveTo", visit.id, nextPoint)
			visit.issuedAt = now
		end
	elseif elapsed(now, visit.issuedAt, Npc.ReissueSeconds) then
		self:_call("moveTo", visit.id, target)
		visit.issuedAt = now
	end
	visit.lastPos = position
	return done
end

-- A stuck leg ends at its last point. The snap log keeps the last SNAP_LOG_LIMIT snaps.
local SNAP_LOG_LIMIT = 20

function CustomerNpcService:_snap(visit)
	local position = self:_position(visit)
	table.insert(self._snapLog, {
		visitId = visit.id,
		state = visit.state,
		x = if position then position.x else nil,
		z = if position then position.z else nil,
		goalX = visit.goal.x,
		goalZ = visit.goal.z,
	})
	while #self._snapLog > SNAP_LOG_LIMIT do
		table.remove(self._snapLog, 1)
	end
	self:_call("snapTo", visit.id, visit.goal)
	visit.snaps += 1
	if visit.loadTest then
		self._loadSnaps += 1
	else
		self._customerSnaps += 1
	end
	visit.waypointIndex = #visit.waypoints + 1
end

-- Transactions ------------------------------------------------------------------------------

-- Puts the tree down, releases an unsold reservation once and leaves the queue.
function CustomerNpcService:_releaseIfHeld(visit)
	local wasCarrying = visit.carrying
	visit.carrying = false
	self:_call("dropTree", visit.id)
	local notified = false
	if visit.reserved and not visit.sold and visit.placementId ~= nil then
		visit.reserved = false
		notified = self._companies:npcCancel(visit.companyId, visit.id, visit.placementId, visit.walkedOut)
	end
	if wasCarrying and not notified then
		-- The hidden tree shows again even when no cancel re-synced the displayed trees.
		self._companies:refreshPlacements(visit.companyId)
	end
	self:_leaveQueue(visit)
end

-- No transaction: avatar, car and queue place go, the runtime claim is dropped. A
-- reservation stays until npcSweep or the reload clear. Load visits: despawn and delete.
function CustomerNpcService:_hardRemove(visit)
	if visit.state == "CheckingOut" then
		self:_call("showCheckout", visit.plotId, nil)
	end
	self:_call("despawn", visit.id)
	if not visit.loadTest then
		self:_call("destroyCar", visit.plotId, visit.id)
		self:_leaveQueue(visit)
		self._companies:npcDepart(visit.companyId, visit.id)
	end
	if self._visits[visit.id] == visit then
		self._visits[visit.id] = nil
	end
end

function CustomerNpcService:_finish(visit)
	self:_leaveQueue(visit)
	if not visit.loadTest then
		self._companies:npcDepart(visit.companyId, visit.id)
	end
	if self._visits[visit.id] == visit then
		self._visits[visit.id] = nil
	end
end

function CustomerNpcService:_decide(visit)
	local ok, result = self._companies:npcDecide(visit.companyId, visit.id, visit.customerNumber :: number, visit.roll)
	if ok and type(result) == "table" then
		visit.placementId = result.placementId
		visit.sizeId = result.sizeId
		visit.speciesId = result.speciesId
		visit.salePrice = result.salePrice
		visit.treeX = result.x
		visit.treeZ = result.z
		visit.reserved = true
		self:_enter(visit, "WalkingToTree")
	else
		self:_enter(visit, "WalkingOut")
	end
end

function CustomerNpcService:_settle(visit): (boolean, any)
	local ok, result = self._companies:npcSettle(visit.companyId, visit.id, visit.placementId :: string, function(sale)
		if sale.order then
			self:_call("adoptCar", visit.plotId, visit.id, sale.order.orderNumber)
			visit.orderNumber = sale.order.orderNumber
		end
	end)
	if ok then
		visit.sold = true
		if visit.orderNumber ~= nil then
			self:_enter(visit, "WalkingToCar")
		else
			self:_enter(visit, "WalkingOut")
		end
	else
		-- npcSettle already counted the abandonment; no npcCancel (Amendment 1, row 9).
		visit.reserved = false
		self:_enter(visit, "WalkingOut")
	end
	return ok, result
end

-- Serves the customer at the counter once (CM2-N2): `settling` blocks re-entry while
-- npcSettle runs; a raised error warns and returns InternalError.
function CustomerNpcService:_serve(visit): (boolean, any)
	visit.settling = true
	local called, ok, result = pcall(self._settle, self, visit)
	visit.settling = false
	if not called then
		warn(string.format("[ChristmasMarket2] NpcCheckoutFailed %s: %s", visit.id, tostring(ok)))
		return false, "InternalError"
	end
	return ok, result
end

-- Queue patience runs from entering Queued and covers Queued and CheckingOut (CM2-N2).
function CustomerNpcService:_patienceOut(visit, now: number): boolean
	return elapsed(now, visit.queuedAt or visit.enteredAt, Npc.QueuePatienceSeconds)
end

-- The customer's patience ran out: it walks out and counts as walked out (CM2-N2).
function CustomerNpcService:_walkOut(visit)
	visit.walkedOut = true
	self:_enter(visit, "WalkingOut")
end

-- The customer visit at the counter of this plot (state CheckingOut), or nil.
function CustomerNpcService:_atCounter(plotId: string)
	for _, visit in ipairs(self:_ordered()) do
		if not visit.loadTest and visit.plotId == plotId and visit.state == "CheckingOut" then
			return visit
		end
	end
	return nil
end

-- States ------------------------------------------------------------------------------------

local function loadTarget(visit, leg: number): Point
	if leg == 1 then
		return NpcPath.aisle(visit.space)
	elseif leg == 2 then
		return NpcPath.queueSlot(QUEUE_TAIL)
	end
	return NpcPath.door(visit.space)
end

local ENTRY = {}

function ENTRY.Arriving(self, visit, _now: number)
	self:_call("spawnCar", visit.plotId, visit.id, visit.space, visit.seq)
end

function ENTRY.WalkingIn(self, visit, now: number)
	local door = NpcPath.door(visit.space)
	visit.goal = door
	if not self:_call("spawnAvatar", visit.plotId, visit.id, visit.seq, door) then
		self:_enter(visit, "Departing")
		return
	end
	self:_startRoute(visit, NpcPath.aisle(visit.space), now)
end

function ENTRY.WalkingToTree(self, visit, now: number)
	local spot = NpcPath.approach({ x = visit.treeX, z = visit.treeZ, sizeId = visit.sizeId }, visit.level)
	if spot ~= nil then
		self:_startRoute(visit, spot, now)
	else
		self:_stay(visit, now)
	end
end

function ENTRY.PickingUp(self, visit, _now: number)
	visit.carrying = true
	self:_call("holdTree", visit.id, visit.sizeId)
	self._companies:refreshPlacements(visit.companyId)
end

function ENTRY.WalkingToQueue(self, visit, now: number)
	self:_joinQueue(visit)
	local index = self:_queueIndex(visit)
	visit.queueSlot = index
	self:_startRoute(visit, NpcPath.queueSlot(index), now)
end

function ENTRY.Queued(_self, visit, now: number)
	visit.queuedAt = now
end

-- The customer stands upright facing the staff side; the counter prompt shows its tree.
function ENTRY.CheckingOut(self, visit, _now: number)
	self:_call("face", visit.id, NpcPath.staffPoint())
	self:_call("showCheckout", visit.plotId, {
		placementId = visit.placementId,
		speciesId = visit.speciesId,
		sizeId = visit.sizeId,
		price = visit.salePrice,
	})
end

function ENTRY.WalkingToCar(self, visit, now: number)
	self:_leaveQueue(visit)
	visit.carrying = false
	self:_call("dropTree", visit.id)
	self:_call("say", visit.id)
	self:_startRoute(visit, NpcPath.door(visit.space), now)
end

function ENTRY.WalkingOut(self, visit, now: number)
	self:_releaseIfHeld(visit)
	self:_startRoute(visit, NpcPath.door(visit.space), now)
end

function ENTRY.Departing(self, visit, _now: number)
	self:_leaveQueue(visit)
	self:_call("despawn", visit.id)
	if not visit.loadTest and visit.orderNumber == nil then
		self:_call("dismissCar", visit.plotId, visit.id)
	end
end

function ENTRY.LoadLoop(self, visit, now: number)
	local door = NpcPath.door(visit.space)
	visit.goal = door
	if not self:_call("spawnAvatar", visit.plotId, visit.id, visit.seq, door) then
		self:_enter(visit, "Departing")
		return
	end
	visit.loadLeg = 1
	self:_startRoute(visit, loadTarget(visit, 1), now)
end

function CustomerNpcService:_enter(visit, state: string)
	if visit.state == "CheckingOut" and state ~= "CheckingOut" then
		self:_call("showCheckout", visit.plotId, nil)
	end
	if state == "Done" then
		self:_finish(visit)
		return
	end
	local now = self._now()
	visit.state = state
	visit.enteredAt = now
	table.insert(visit.history, state)
	while #visit.history > HISTORY_LIMIT do
		table.remove(visit.history, 1)
	end
	local entry = ENTRY[state]
	if entry then
		entry(self, visit, now)
	end
end

local STEP = {}

local function timedOut(visit, now: number): boolean
	return elapsed(now, visit.enteredAt, Fsm[visit.state].timeout)
end

function STEP.Arriving(self, visit, now: number)
	if timedOut(visit, now) then
		self:_enter(visit, Fsm.Arriving.onTimeout)
	end
end

local function stepLeg(self, visit, now: number)
	local exit = Fsm[visit.state].onTimeout
	if self:_advance(visit, now) then
		self:_enter(visit, exit)
	elseif timedOut(visit, now) then
		self:_snap(visit)
		self:_enter(visit, exit)
	end
end

for state in pairs(LEG_STATES) do
	STEP[state] = stepLeg
end

function STEP.Browsing(self, visit, now: number)
	if timedOut(visit, now) then
		self:_decide(visit)
	end
end

function STEP.PickingUp(self, visit, now: number)
	if timedOut(visit, now) then
		self:_enter(visit, Fsm.PickingUp.onTimeout)
	end
end

function STEP.Queued(self, visit, now: number)
	local index = self:_queueIndex(visit)
	if index ~= visit.queueSlot then
		visit.queueSlot = index
		self:_startRoute(visit, NpcPath.queueSlot(index), now)
	end
	local arrived = self:_advance(visit, now)
	if arrived and index == 1 then
		self:_enter(visit, "CheckingOut")
	elseif self:_patienceOut(visit, now) then
		self:_walkOut(visit)
	end
end

-- The counter waits for the player's prompt (checkout) or a hired Cashier; without a
-- Cashier the customer walks out once its patience ran out.
function STEP.CheckingOut(self, visit, now: number)
	if visit.settling then
		return
	end
	if self._companies:hasCashier(visit.companyId) then
		if elapsed(now, visit.enteredAt, Npc.CashierCheckoutSeconds) then
			self:_serve(visit)
		end
	elseif self:_patienceOut(visit, now) then
		self:_walkOut(visit)
	end
end

function STEP.WaitingAtCar(self, visit, now: number)
	if timedOut(visit, now) then
		self:_enter(visit, Fsm.WaitingAtCar.onTimeout)
	end
end

function STEP.Departing(self, visit, now: number)
	if timedOut(visit, now) then
		self:_enter(visit, Fsm.Departing.onTimeout)
	end
end

function STEP.LoadLoop(self, visit, now: number)
	if elapsed(now, visit.enteredAt, visit.loadSeconds) then
		self:_enter(visit, Fsm.LoadLoop.onTimeout)
		return
	end
	local done = self:_advance(visit, now)
	if not done and elapsed(now, visit.legStartedAt, Npc.LegTimeoutSeconds) then
		self:_snap(visit)
		done = true
	end
	if done then
		visit.loadLeg = (visit.loadLeg % 3) + 1
		self:_startRoute(visit, loadTarget(visit, visit.loadLeg), now)
	end
end

function CustomerNpcService:_step(visit, now: number)
	if visit.settling then
		return
	end
	if not visit.loadTest then
		-- 1. A lost session (unload, reload, save switch) or plot: hard remove.
		if
			self._companies:sessionToken(visit.companyId) ~= visit.token
			or self._plotOf(visit.companyId) ~= visit.plotId
		then
			self:_hardRemove(visit)
			return
		end
		-- 2. A lost avatar or an over-long visit gives up.
		if visit.state ~= "Arriving" and visit.state ~= "Departing" then
			if self:_position(visit) == nil or now - visit.startedAt > self._maxVisitSeconds then
				self:_releaseIfHeld(visit)
				self:_enter(visit, "Departing")
				return
			end
		end
	end
	-- 3. The state's movement or timer.
	local step = STEP[visit.state]
	if step then
		step(self, visit, now)
	end
end

-- Visits ------------------------------------------------------------------------------------

local function newVisit(id: string, seq: number, plotId: string, space: number, now: number)
	local door = NpcPath.door(space)
	return {
		id = id,
		seq = seq,
		loadTest = false,
		companyId = nil :: string?,
		plotId = plotId,
		token = nil :: number?,
		space = space,
		customerNumber = nil :: number?,
		level = 0,
		roll = nil :: number?,
		state = "",
		enteredAt = now,
		startedAt = now,
		history = {},
		snaps = 0,
		waypoints = {},
		waypointIndex = 1,
		issuedAt = now,
		legStartedAt = now,
		lastPos = nil :: Point?,
		goal = door,
		loadLeg = 1,
		loadSeconds = Npc.LoadSeconds,
		queueSlot = nil :: number?,
		placementId = nil :: string?,
		sizeId = nil :: string?,
		speciesId = nil :: string?,
		salePrice = nil :: number?,
		treeX = nil :: number?,
		treeZ = nil :: number?,
		reserved = false,
		sold = false,
		carrying = false,
		orderNumber = nil :: number?,
		queuedAt = nil :: number?,
		settling = false,
		walkedOut = false,
	}
end

function CustomerNpcService:_hasRoom(plotId: string): boolean
	return self:countOnPlot(plotId) < self._maxPerPlot and self:count() < self._maxPerServer
end

-- One car arrives: the company claims a parking space (or refuses). Returns ok, visitId | code.
function CustomerNpcService:_arrive(companyId: string, plotId: string, forcedNumber: number?, roll: number?)
	self._seq += 1
	local seq = self._seq
	local visitId = "visit:" .. seq
	local ok, info = self._companies:npcArrive(companyId, visitId, forcedNumber)
	if not ok then
		return false, info
	end
	local visit = newVisit(visitId, seq, plotId, info.space, self._now())
	visit.companyId = companyId
	visit.token = info.token
	visit.customerNumber = info.customerNumber
	visit.level = if type(info.lotExpansion) == "number" then info.lotExpansion else 0
	visit.roll = roll
	self._visits[visitId] = visit
	self:_enter(visit, "Arriving")
	return true, visitId
end

-- Per live company with a plot: sweep orphaned reservations and claims, then (unless paused
-- or stopped) one arrival if the budget allows. Returns the number of new visits.
function CustomerNpcService:arrivalPass(paused: boolean?): number
	if self._stopped then
		return 0
	end
	local spawned = 0
	for _, companyId in ipairs(self._companies:liveCompanyIds()) do
		local plotId = self._plotOf(companyId)
		if plotId ~= nil then
			local live = {}
			for _, visit in pairs(self._visits) do
				if visit.companyId == companyId and not visit.loadTest then
					live[visit.id] = true
				end
			end
			self._companies:npcSweep(companyId, live)
			if not paused and self:_hasRoom(plotId) then
				-- A test override forces the next arrival's profile (roll 0); it is cleared
				-- only once an arrival succeeded.
				local override = self._arrivalOverrides[companyId]
				if override ~= nil then
					if self:_arrive(companyId, plotId, override, 0) then
						self._arrivalOverrides[companyId] = nil
						spawned += 1
					end
				elseif self:_arrive(companyId, plotId, nil, nil) then
					spawned += 1
				end
			end
		end
	end
	return spawned
end

function CustomerNpcService:tick()
	if self._stopped then
		return
	end
	local now = self._now()
	for _, visit in ipairs(self:_ordered()) do
		if self._visits[visit.id] == visit then
			self:_step(visit, now)
		end
	end
end

-- Visits waiting for an order that is gone (loaded or expired) leave.
function CustomerNpcService:onOrdersChanged(companyId: string, summary)
	local open = {}
	local orders = if type(summary) == "table" and type(summary.orders) == "table" then summary.orders else {}
	for _, order in ipairs(orders) do
		if type(order) == "table" and type(order.orderNumber) == "number" then
			open[order.orderNumber] = true
		end
	end
	for _, visit in ipairs(self:_ordered()) do
		if
			self._visits[visit.id] == visit
			and visit.companyId == companyId
			and (visit.state == "WalkingToCar" or visit.state == "WaitingAtCar")
			and (visit.orderNumber == nil or not open[visit.orderNumber])
		then
			self:_enter(visit, "Departing")
		end
	end
end

-- Hard-removes every visit on the plot (the plot is released).
function CustomerNpcService:clearPlot(plotId: string)
	for _, visit in ipairs(self:_ordered()) do
		if visit.plotId == plotId then
			self:_hardRemove(visit)
		end
	end
end

-- Hard-removes everything; later passes do nothing.
function CustomerNpcService:shutdown()
	self._stopped = true
	for _, visit in ipairs(self:_ordered()) do
		self:_hardRemove(visit)
	end
end

-- Placements a walking customer carries (their displayed tree is hidden).
function CustomerNpcService:carriedPlacements(companyId: string): { [string]: boolean }
	local carried = {}
	for _, visit in pairs(self._visits) do
		if visit.companyId == companyId and visit.carrying and visit.placementId ~= nil then
			carried[visit.placementId] = true
		end
	end
	return carried
end

function CustomerNpcService:count(): number
	local count = 0
	for _ in pairs(self._visits) do
		count += 1
	end
	return count
end

function CustomerNpcService:countOnPlot(plotId: string): number
	local count = 0
	for _, visit in pairs(self._visits) do
		if visit.plotId == plotId then
			count += 1
		end
	end
	return count
end

-- Visit IDs in join order; index 1 stands at the counter (CM2-N2 serves it).
function CustomerNpcService:queue(plotId: string): { string }
	local queue = self._queues[plotId]
	return if queue then table.clone(queue) else {}
end

-- A player at the counter serves the customer there (CM2-N2). Server-trusted callers only;
-- main.server validates the player first. Returns true plus the sale, or false plus a code.
function CustomerNpcService:checkout(companyId: string, plotId: string): (boolean, any)
	if self._stopped then
		return false, "NoCustomer"
	end
	if type(companyId) ~= "string" or type(plotId) ~= "string" or self._plotOf(companyId) ~= plotId then
		return false, "Forbidden"
	end
	local visit = self:_atCounter(plotId)
	if visit == nil then
		return false, "NoCustomer"
	end
	if visit.companyId ~= companyId then
		return false, "Forbidden"
	end
	if visit.settling then
		return false, "CheckoutBusy"
	end
	return self:_serve(visit)
end

function CustomerNpcService:snapshot()
	local visits = {}
	for _, visit in ipairs(self:_ordered()) do
		table.insert(visits, {
			visitId = visit.id,
			plotId = visit.plotId,
			state = visit.state,
			history = table.clone(visit.history),
			snaps = visit.snaps,
			space = visit.space,
			placementId = visit.placementId,
			speciesId = visit.speciesId,
			salePrice = visit.salePrice,
			orderNumber = visit.orderNumber,
			carrying = visit.carrying,
			loadTest = visit.loadTest,
			customerNumber = visit.customerNumber,
		})
	end
	local snapLog = {}
	for _, entry in ipairs(self._snapLog) do
		table.insert(snapLog, table.clone(entry))
	end
	return {
		count = #visits,
		visits = visits,
		loadSnaps = self._loadSnaps,
		customerSnaps = self._customerSnaps,
		snapLog = snapLog,
	}
end

-- Studio test instruments only (StudioTestService); never called by gameplay code.

-- One forced customer (roll 0) with the given profile number.
function CustomerNpcService:spawnForTest(companyId: string, profile: number): (boolean, string)
	if self._stopped then
		return false, "NpcBudget"
	end
	local plotId = self._plotOf(companyId)
	if plotId == nil then
		return false, "CompanyUnavailable"
	end
	if not self:_hasRoom(plotId) then
		return false, "NpcBudget"
	end
	return self:_arrive(companyId, plotId, profile, 0)
end

-- The customer gives up and walks out (WalkingIn up to CheckingOut).
function CustomerNpcService:giveUpForTest(visitId: string): boolean
	local visit = self._visits[visitId]
	if visit == nil or visit.loadTest or not GIVE_UP_STATES[visit.state] then
		return false
	end
	self:_enter(visit, "WalkingOut")
	return true
end

-- The company's next live arrival (arrivalPass) gets this profile number and roll 0; the
-- override is cleared only when that arrival succeeds.
function CustomerNpcService:setArrivalOverrideForTest(companyId: string, profile: number)
	self._arrivalOverrides[companyId] = profile
end

-- Hard-removes the company's customer visits at once (nil: every visit, load visits
-- included) and clears the arrival override(s); then sweeps the company's orphaned
-- reservations and claims and re-syncs its displayed trees. Returns the number removed.
function CustomerNpcService:resetForTest(companyId: string?): number
	local removed = 0
	for _, visit in ipairs(self:_ordered()) do
		if companyId == nil or (visit.companyId == companyId and not visit.loadTest) then
			self:_hardRemove(visit)
			removed += 1
		end
	end
	local companyIds: { string }
	if companyId ~= nil then
		self._arrivalOverrides[companyId] = nil
		companyIds = { companyId }
	else
		self._arrivalOverrides = {}
		companyIds = self._companies:liveCompanyIds()
	end
	for _, id in ipairs(companyIds) do
		local live = {}
		for _, visit in pairs(self._visits) do
			if visit.companyId == id and not visit.loadTest then
				live[visit.id] = true
			end
		end
		self._companies:npcSweep(id, live)
		self._companies:refreshPlacements(id)
	end
	return removed
end

-- Load-test NPCs: no car, no claim, no company call. The i-th uses space ((i - 1) % 4) + 1
-- and loops door -> aisle -> queue tail -> door for `seconds` (default Npc.LoadSeconds).
function CustomerNpcService:spawnLoad(plotId: string, count: number, seconds: number?): number
	if self._stopped or type(count) ~= "number" then
		return 0
	end
	local room = math.min(self._maxPerPlot - self:countOnPlot(plotId), self._maxPerServer - self:count())
	local spawned = math.max(0, math.min(math.floor(count), room))
	for index = 1, spawned do
		self._seq += 1
		local seq = self._seq
		local visit = newVisit("load:" .. seq, seq, plotId, ((index - 1) % 4) + 1, self._now())
		visit.loadTest = true
		visit.loadSeconds = if type(seconds) == "number" then seconds else Npc.LoadSeconds
		self._visits[visit.id] = visit
		self:_enter(visit, "LoadLoop")
	end
	return spawned
end

-- Hard-removes every remaining load visit; returns the number removed.
function CustomerNpcService:clearLoad(): number
	local removed = 0
	for _, visit in ipairs(self:_ordered()) do
		if visit.loadTest then
			self:_hardRemove(visit)
			removed += 1
		end
	end
	return removed
end

return CustomerNpcService
