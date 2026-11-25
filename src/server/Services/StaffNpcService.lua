--!strict
-- Visible staff at work (CM2-25/26, docs/archive/plans/CM2-25-26a.md): the director. A hired Cashier
-- walks to the counter and serves the queue; a hired Lot Worker loads customer cars and
-- restocks sold spots from the bays. Both get gently tired, rest at the break area and go back
-- to work. It requires only GameConfig, NpcPath and Staff and calls no game service itself:
-- the company service (transactions), the plot lookup, the world adapter (avatar, carried
-- tree) and the clock are injected, so it runs headless like CustomerNpcService.
--
-- Orders and stock change only in the company service's staff* methods (server-trusted,
-- inside the company's critical section); no client input reaches this module. A record that
-- loses its session (unload, reload, save switch), its plot or its hire is removed; a claimed
-- order is released (a harmless no-op on a reloaded session, which clears carried orders).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NpcPath = require(Shared:WaitForChild("NpcPath"))
local Staff = require(Shared:WaitForChild("Staff"))

local Config = GameConfig.Staff
local Npc = GameConfig.Customers.Npc

-- Float slack for timers driven by fractional tick clocks.
local EPSILON = 1e-6
-- An intermediate corner counts as reached within ArriveRadius once the avatar has stopped.
local STOPPED_STUDS = 0.05
-- The Lot Worker at its post faces the lot.
local LOT_WORKER_FACING = { x = 0, z = 5 }

local StaffNpcService = {}
StaffNpcService.__index = StaffNpcService

type Point = NpcPath.Point
type FsmEntry = { timeout: number?, leg: boolean }

-- Leg states end on arrival or after their timeout (with a snap to the goal). OnDuty and Idle
-- are stationary and leave only by their conditions; Resting ends rested or after
-- RestMaxSeconds; LoadLoop (load staff only) ends after its own seconds.
StaffNpcService.Fsm = {
	WalkingToPost = { timeout = Npc.LegTimeoutSeconds, leg = true },
	OnDuty = { timeout = nil, leg = false },
	Idle = { timeout = nil, leg = false },
	WalkingToPickup = { timeout = Npc.LegTimeoutSeconds, leg = true },
	CarryingToCar = { timeout = Npc.LegTimeoutSeconds, leg = true },
	WalkingToBay = { timeout = Npc.LegTimeoutSeconds, leg = true },
	CarryingToSpot = { timeout = Npc.LegTimeoutSeconds, leg = true },
	WalkingToBreak = { timeout = Npc.LegTimeoutSeconds, leg = true },
	Resting = { timeout = Config.RestMaxSeconds, leg = false },
	LoadLoop = { timeout = Npc.LoadSeconds, leg = false },
} :: { [string]: FsmEntry }
local Fsm = StaffNpcService.Fsm

-- The Employees tab's status of each state (CM2-25/26 part b); load-test states have none.
local UI_STATUS: { [string]: string } = {
	OnDuty = "Working",
	Idle = "Working",
	WalkingToPickup = "Working",
	CarryingToCar = "Working",
	WalkingToBay = "Working",
	CarryingToSpot = "Working",
	WalkingToPost = "OnTheWay",
	WalkingToBreak = "Resting",
	Resting = "Resting",
}

local function validPoint(value: any): Point?
	if type(value) == "table" and type(value.x) == "number" and type(value.z) == "number" then
		return { x = value.x, z = value.z }
	end
	return nil
end

local function elapsed(now: number, since: number, seconds: number): boolean
	return now - since >= seconds - EPSILON
end

local function postOf(role: string): Point
	if role == "Cashier" then
		return NpcPath.staffPoint()
	end
	return { x = Config.LotWorkerPost.x, z = Config.LotWorkerPost.z }
end

local function postFacing(role: string): Point
	if role == "Cashier" then
		return NpcPath.queueSlot(1)
	end
	return LOT_WORKER_FACING
end

local function areaCentre(area): Point
	return { x = area.x, z = area.z }
end

-- Identifies a break-area spot; a changed key means the area was moved.
local function breakKey(area): string
	return tostring(area.x) .. ":" .. tostring(area.z) .. ":" .. tostring(area.rotation)
end

-- The break area every load-test record uses: candidate 1, rotation 0.
local function loadArea()
	local first = Config.BreakArea.Candidates[1]
	return { x = first.x, z = first.z, rotation = 0 }
end

-- deps = {companies, plotOf(companyId) -> plotId?, world, now() -> seconds}
-- options = {maxPerServer?}
function StaffNpcService.new(deps, options)
	local self = setmetatable({}, StaffNpcService)
	local opts = if type(options) == "table" then options else {}
	self._companies = deps.companies
	self._plotOf = deps.plotOf
	self._worldAdapter = deps.world
	self._now = deps.now
	self._maxPerServer = if type(opts.maxPerServer) == "number" then opts.maxPerServer else Config.MaxPerServer
	self._records = {}
	self._retryAt = {}
	self._seq = 0
	self._stopped = false
	self._warned = {}
	self._snaps = 0
	self._loadSnaps = 0
	self._energySavedAt = nil :: number?
	return self
end

-- Every world call goes through here: an error warns once per method and counts as nil.
function StaffNpcService:_call(method: string, ...): any
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
			warn(string.format("[ChristmasMarket2] StaffWorldFailed %s: %s", method, tostring(result)))
		end
		return nil
	end
	return result
end

function StaffNpcService:_position(record): Point?
	return validPoint(self:_call("position", record.id))
end

-- Live records sorted by staff ID.
function StaffNpcService:_ordered()
	local list = {}
	for _, record in pairs(self._records) do
		table.insert(list, record)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

-- Movement (same algorithm as CustomerNpcService) ---------------------------------------------

-- Routes from the avatar's position (or its last goal) to `to` and issues the first MoveTo.
-- A standing avatar is unanchored first.
function StaffNpcService:_startRoute(record, to: Point, now: number)
	self:_call("setAnchored", record.id, false)
	local from = self:_position(record) or record.goal
	record.waypoints = NpcPath.route(from, to, record.level)
	record.waypointIndex = 1
	record.legStartedAt = now
	record.lastPos = nil
	record.goal = record.waypoints[#record.waypoints] or to
	local first = record.waypoints[1]
	if first ~= nil then
		self:_call("moveTo", record.id, first)
	end
	record.issuedAt = now
end

-- Advances the waypoint and re-issues MoveTo after ReissueSeconds; true once the route is done.
function StaffNpcService:_advance(record, now: number): boolean
	local target = record.waypoints[record.waypointIndex]
	if target == nil then
		return true
	end
	local position = self:_position(record)
	local radius = Npc.ArriveRadius
	if record.waypointIndex < #record.waypoints then
		local stopped = position ~= nil
			and record.lastPos ~= nil
			and NpcPath.distance(position, record.lastPos) < STOPPED_STUDS
		radius = if stopped then Npc.ArriveRadius else Npc.CornerRadius
	end
	local done = false
	if position ~= nil and NpcPath.distance(position, target) <= radius then
		record.waypointIndex += 1
		local nextPoint = record.waypoints[record.waypointIndex]
		if nextPoint == nil then
			done = true
		else
			self:_call("moveTo", record.id, nextPoint)
			record.issuedAt = now
		end
	elseif elapsed(now, record.issuedAt, Npc.ReissueSeconds) then
		self:_call("moveTo", record.id, target)
		record.issuedAt = now
	end
	record.lastPos = position
	return done
end

-- A stuck leg ends at its goal.
function StaffNpcService:_snap(record)
	self:_call("snapTo", record.id, record.goal)
	record.snaps += 1
	if record.loadTest then
		self._loadSnaps += 1
	else
		self._snaps += 1
	end
	record.waypointIndex = #record.waypoints + 1
end

-- The leg is done: arrived, or timed out and snapped to the goal.
function StaffNpcService:_legDone(record, now: number): boolean
	if self:_advance(record, now) then
		return true
	end
	if elapsed(now, record.legStartedAt, Npc.LegTimeoutSeconds) then
		self:_snap(record)
		return true
	end
	return false
end

-- States ---------------------------------------------------------------------------------------

function StaffNpcService:_enter(record, state: string, now: number)
	record.state = state
	record.enteredAt = now
	self:_call("setState", record.id, state)
end

-- Enters a leg state and starts walking to `to`.
function StaffNpcService:_walk(record, state: string, to: Point, now: number)
	self:_enter(record, state, now)
	self:_startRoute(record, to, now)
end

-- Enters a stationary state: snaps to the exact point, faces its target and anchors.
function StaffNpcService:_stand(record, state: string, at: Point, faceTo: Point, now: number)
	self:_enter(record, state, now)
	record.waypoints = {}
	record.waypointIndex = 1
	record.goal = { x = at.x, z = at.z }
	self:_call("snapTo", record.id, at)
	self:_call("face", record.id, faceTo)
	self:_call("setAnchored", record.id, true)
end

function StaffNpcService:_toPost(record, now: number)
	self:_walk(record, "WalkingToPost", postOf(record.role), now)
end

function StaffNpcService:_toBreak(record, now: number)
	self:_walk(record, "WalkingToBreak", Staff.restPoint(record.area, record.role), now)
end

-- The Lot Worker's next job from where it stands: tired -> break; else the oldest uncarried
-- order; else a sold spot to restock. False when there is nothing to do.
function StaffNpcService:_nextJob(record, now: number): boolean
	if Staff.isTired(record.energy) then
		self:_toBreak(record, now)
		return true
	end
	local order = self._companies:staffPeekOrder(record.companyId)
	if type(order) == "table" then
		record.job = {
			kind = "Load",
			orderNumber = order.orderNumber,
			space = order.parkingSpace,
			sizeId = order.sizeId,
			claimed = false,
		}
		self:_walk(record, "WalkingToPickup", Staff.pickupApproach(order.parkingSpace), now)
		return true
	end
	local spot = self._companies:staffPeekRestock(record.companyId)
	if type(spot) == "table" then
		record.job = { kind = "Restock", spot = spot }
		self:_walk(record, "WalkingToBay", Staff.bayApproach(spot.bay), now)
		return true
	end
	return false
end

-- A job ended: the carried tree goes, then break, the next job or the post.
function StaffNpcService:_afterJob(record, now: number)
	self:_call("dropTree", record.id)
	record.job = nil
	if Staff.isTired(record.energy) then
		self:_toBreak(record, now)
	elseif not self:_nextJob(record, now) then
		self:_toPost(record, now)
	end
end

local STEP = {}

function STEP.WalkingToPost(self, record, now: number)
	if Staff.isTired(record.energy) then
		self:_toBreak(record, now)
		return
	end
	if self:_legDone(record, now) then
		local state = if record.role == "Cashier" then "OnDuty" else "Idle"
		self:_stand(record, state, postOf(record.role), postFacing(record.role), now)
	end
end

-- The Cashier leaves its post as soon as it is tired.
function STEP.OnDuty(self, record, now: number)
	if Staff.isTired(record.energy) then
		self:_toBreak(record, now)
	end
end

function STEP.Idle(self, record, now: number)
	self:_nextJob(record, now)
end

-- The claim happens at the pickup tree; a refused claim (taken, gone) ends the job.
function STEP.WalkingToPickup(self, record, now: number)
	if not self:_legDone(record, now) then
		return
	end
	local job = record.job
	local ok = self._companies:staffClaimOrder(record.companyId, job.orderNumber)
	if ok then
		job.claimed = true
		self:_call("holdTree", record.id, job.sizeId)
		self:_walk(record, "CarryingToCar", NpcPath.door(job.space), now)
	else
		self:_afterJob(record, now)
	end
end

function STEP.CarryingToCar(self, record, now: number)
	if not self:_legDone(record, now) then
		return
	end
	local job = record.job
	self._companies:staffLoadOrder(record.companyId, job.orderNumber)
	job.claimed = false
	self:_afterJob(record, now)
end

-- The tree from the bay is only a visual until it is placed (the bay count drops there).
function STEP.WalkingToBay(self, record, now: number)
	if not self:_legDone(record, now) then
		return
	end
	local spot = record.job.spot
	self:_call("holdTree", record.id, spot.sizeId)
	local approach = NpcPath.approach(spot, record.level) or { x = spot.x, z = spot.z }
	self:_walk(record, "CarryingToSpot", approach, now)
end

function STEP.CarryingToSpot(self, record, now: number)
	if not self:_legDone(record, now) then
		return
	end
	self._companies:staffRestock(record.companyId, record.job.spot)
	self:_afterJob(record, now)
end

function STEP.WalkingToBreak(self, record, now: number)
	if self:_legDone(record, now) then
		self:_stand(record, "Resting", Staff.restPoint(record.area, record.role), areaCentre(record.area), now)
	end
end

function STEP.Resting(self, record, now: number)
	if Staff.isRested(record.energy) or elapsed(now, record.enteredAt, Fsm.Resting.timeout :: number) then
		self:_toPost(record, now)
	end
end

-- Load staff walk post <-> rest point of candidate 1 until their seconds are over.
function STEP.LoadLoop(self, record, now: number)
	if elapsed(now, record.enteredAt, record.loadSeconds) then
		self:_remove(record)
		return
	end
	if self:_legDone(record, now) then
		record.loadLeg = if record.loadLeg == 1 then 2 else 1
		local target = if record.loadLeg == 1 then postOf(record.role) else Staff.restPoint(record.area, record.role)
		self:_startRoute(record, target, now)
	end
end

function StaffNpcService:_step(record, now: number)
	local dt = math.clamp(now - record.lastTickAt, 0, 1)
	record.lastTickAt = now
	record.energy = Staff.stepEnergy(record.energy, dt, record.state == "Resting")
	-- A lost avatar is removed (a claimed order is released) and respawns next tick.
	if self:_position(record) == nil then
		self:_remove(record)
		return
	end
	local step = STEP[record.state]
	if step then
		step(self, record, now)
	end
	-- The Employees tab follows the record (runtime only, never saved).
	local status = UI_STATUS[record.state]
	if not record.loadTest and status ~= nil and self._records[record.id] == record then
		self._companies:noteStaff(record.companyId, record.role, status, math.floor(record.energy))
	end
end

-- A moved break area: staff walking to or resting at the old spot walk to the new seat.
function StaffNpcService:_followArea(record, area, now: number)
	record.area = area
	local key = breakKey(area)
	if key == record.breakKey then
		return
	end
	record.breakKey = key
	if record.state == "WalkingToBreak" or record.state == "Resting" then
		self:_toBreak(record, now)
	end
end

-- Records -------------------------------------------------------------------------------------

local function newRecord(id: string, plotId: string, role: string, area, at: Point, energy: number, now: number)
	return {
		id = id,
		companyId = nil :: string?,
		plotId = plotId,
		role = role,
		token = nil :: number?,
		loadTest = false,
		loadSeconds = Npc.LoadSeconds,
		loadLeg = 1,
		state = "",
		enteredAt = now,
		lastTickAt = now,
		energy = energy,
		level = 0,
		area = area,
		breakKey = breakKey(area),
		waypoints = {} :: { Point },
		waypointIndex = 1,
		issuedAt = now,
		legStartedAt = now,
		lastPos = nil :: Point?,
		goal = { x = at.x, z = at.z },
		snaps = 0,
		job = nil :: any,
	}
end

-- Despawns the avatar; a claimed order is released and the live status cleared.
function StaffNpcService:_remove(record)
	self:_call("despawn", record.id)
	if self._records[record.id] == record then
		self._records[record.id] = nil
	end
	local job = record.job
	record.job = nil
	if not record.loadTest and type(job) == "table" and job.kind == "Load" and job.claimed then
		self._companies:staffReleaseOrder(record.companyId, job.orderNumber)
	end
	if not record.loadTest and record.companyId ~= nil then
		self._companies:noteStaff(record.companyId, record.role, nil, nil)
	end
end

function StaffNpcService:_countOnPlot(plotId: string): number
	local count = 0
	for _, record in pairs(self._records) do
		if record.plotId == plotId then
			count += 1
		end
	end
	return count
end

-- One hired role appears at its seat: tired -> Resting, else it walks to its post. A failed
-- spawn waits RespawnSeconds.
function StaffNpcService:_spawn(companyId: string, plotId: string, role: string, view, now: number)
	local id = companyId .. "|" .. role
	local retryAt = self._retryAt[id]
	if retryAt ~= nil and now < retryAt then
		return
	end
	local area = view.breakArea
	local at = Staff.restPoint(area, role)
	if not self:_call("spawnAvatar", plotId, id, role, at, areaCentre(area)) then
		self._retryAt[id] = now + Config.RespawnSeconds
		return
	end
	self._retryAt[id] = nil
	local saved = if type(view.energy) == "table" then view.energy[role] else nil
	local energy = if type(saved) == "number" then saved else Config.Energy.Max
	local record = newRecord(id, plotId, role, area, at, energy, now)
	record.companyId = companyId
	record.token = view.token
	record.level = if type(view.lotExpansion) == "number" then view.lotExpansion else 0
	self._records[id] = record
	if Staff.isTired(energy) then
		self:_stand(record, "Resting", at, areaCentre(area), now)
	else
		self:_toPost(record, now)
	end
end

function StaffNpcService:_saveEnergy()
	local byCompany: { [string]: { [string]: number } } = {}
	for _, record in pairs(self._records) do
		if not record.loadTest and record.companyId ~= nil then
			local energies = byCompany[record.companyId]
			if energies == nil then
				energies = {}
				byCompany[record.companyId] = energies
			end
			energies[record.role] = record.energy
		end
	end
	local ids = {}
	for companyId in pairs(byCompany) do
		table.insert(ids, companyId)
	end
	table.sort(ids)
	for _, companyId in ipairs(ids) do
		self._companies:setStaffEnergy(companyId, byCompany[companyId])
	end
end

function StaffNpcService:tick()
	if self._stopped then
		return
	end
	local now = self._now()
	-- 1. The live companies with a plot.
	local live = {}
	local views = {}
	for _, companyId in ipairs(self._companies:liveCompanyIds()) do
		local plotId = self._plotOf(companyId)
		if plotId ~= nil then
			local view = self._companies:getStaffView(companyId)
			if type(view) == "table" then
				table.insert(live, companyId)
				views[companyId] = { view = view, plotId = plotId }
			end
		end
	end
	-- 2. Records that lost their session, plot or hire go.
	for _, record in ipairs(self:_ordered()) do
		if not record.loadTest then
			local entry = views[record.companyId]
			if
				entry == nil
				or entry.view.token ~= record.token
				or entry.plotId ~= record.plotId
				or entry.view.hired[record.role] ~= true
			then
				self:_remove(record)
			else
				self:_followArea(record, entry.view.breakArea, now)
				record.level = if type(entry.view.lotExpansion) == "number" then entry.view.lotExpansion else 0
			end
		end
	end
	-- 3. Each hired working role without a record appears, within the budget.
	for _, companyId in ipairs(live) do
		local entry = views[companyId]
		for _, role in ipairs(Config.WorkingRoles) do
			local id = companyId .. "|" .. role
			if
				entry.view.hired[role] == true
				and self._records[id] == nil
				and self:count() < self._maxPerServer
				and self:_countOnPlot(entry.plotId) < Config.MaxPerPlot
			then
				self:_spawn(companyId, entry.plotId, role, entry.view, now)
			end
		end
	end
	-- 4. Every record steps.
	for _, record in ipairs(self:_ordered()) do
		if self._records[record.id] == record then
			self:_step(record, now)
		end
	end
	-- 5. Energy rides along with the next save.
	if self._energySavedAt == nil then
		self._energySavedAt = now
	elseif elapsed(now, self._energySavedAt :: number, Config.EnergySaveSeconds) then
		self._energySavedAt = now
		self:_saveEnergy()
	end
end

-- A live Cashier stands at the counter (CustomerNpcService serves the queue then).
function StaffNpcService:cashierReady(companyId: string): boolean
	local record = self._records[companyId .. "|Cashier"]
	return record ~= nil and record.state == "OnDuty"
end

-- Hot Cider Round (CM2-46a): every live staff record of the company is fully rested at once.
-- Returns the number of records rested.
function StaffNpcService:restAll(companyId: string): number
	local count = 0
	for _, record in ipairs(self:_ordered()) do
		if not record.loadTest and record.companyId == companyId then
			record.energy = Config.Energy.Max
			count += 1
		end
	end
	return count
end

-- Removes every record on the plot (the plot is released).
function StaffNpcService:clearPlot(plotId: string)
	for _, record in ipairs(self:_ordered()) do
		if record.plotId == plotId then
			self:_remove(record)
		end
	end
end

-- Removes everything; later ticks do nothing.
function StaffNpcService:shutdown()
	self._stopped = true
	for _, record in ipairs(self:_ordered()) do
		self:_remove(record)
	end
end

function StaffNpcService:count(): number
	local count = 0
	for _ in pairs(self._records) do
		count += 1
	end
	return count
end

function StaffNpcService:snapshot()
	local staff = {}
	for _, record in ipairs(self:_ordered()) do
		local job = record.job
		table.insert(staff, {
			staffId = record.id,
			companyId = record.companyId,
			plotId = record.plotId,
			role = record.role,
			state = record.state,
			energy = math.floor(record.energy * 10 + 0.5) / 10,
			job = if type(job) == "table" then job.kind else nil,
			orderNumber = if type(job) == "table" then job.orderNumber else nil,
			snaps = record.snaps,
		})
	end
	return { count = #staff, snaps = self._snaps, loadSnaps = self._loadSnaps, staff = staff }
end

-- Studio test instruments only (StudioTestService); never called by gameplay code.

-- Sets a live record's energy; false without a record.
function StaffNpcService:setEnergyForTest(companyId: string, role: string, energy: number): boolean
	local record = self._records[companyId .. "|" .. role]
	if record == nil or type(energy) ~= "number" or energy ~= energy then
		return false
	end
	record.energy = math.clamp(energy, 0, Config.Energy.Max)
	return true
end

-- Load-test staff: no company, no transaction. The i-th is a Cashier or Lot Worker in turn and
-- walks between its post and its seat at break-area candidate 1 for `seconds`. Only
-- MaxPerServer limits them. Returns the number spawned.
function StaffNpcService:spawnLoad(plotId: string, count: number, seconds: number?): number
	if self._stopped or type(count) ~= "number" or type(plotId) ~= "string" then
		return 0
	end
	local now = self._now()
	local wanted = math.max(0, math.min(math.floor(count), self._maxPerServer - self:count()))
	local spawned = 0
	for index = 1, wanted do
		self._seq += 1
		local id = "staffload:" .. self._seq
		local roles = Config.WorkingRoles
		local role = roles[((index - 1) % #roles) + 1]
		local area = loadArea()
		local at = Staff.restPoint(area, role)
		if self:_call("spawnAvatar", plotId, id, role, at, areaCentre(area)) then
			local record = newRecord(id, plotId, role, area, at, Config.Energy.Max, now)
			record.loadTest = true
			record.loadSeconds = if type(seconds) == "number" then seconds else Npc.LoadSeconds
			self._records[id] = record
			self:_enter(record, "LoadLoop", now)
			record.loadLeg = 1
			self:_startRoute(record, postOf(role), now)
			spawned += 1
		end
	end
	return spawned
end

-- Removes every remaining load record; returns the number removed.
function StaffNpcService:clearLoad(): number
	local removed = 0
	for _, record in ipairs(self:_ordered()) do
		if record.loadTest then
			self:_remove(record)
			removed += 1
		end
	end
	return removed
end

return StaffNpcService
