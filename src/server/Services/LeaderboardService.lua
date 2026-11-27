--!strict
-- Four leaderboards (CM2-G12b, docs/archive/plans/CM2-G12b.md): a server cache of the board values,
-- cached and rate-limited OrderedDataStore writes, playtime increments and the top-list reads.
-- Headless: every engine call comes in through injected deps (main.server.lua wires
-- DataStoreService, the request budget, usernames, the clock and the published folder).
--
-- Write rule: Set entries (CashEarned, Reputation, RobuxSpent) are written with SetAsync only
-- when their value changed since the last successful write; a value of 0 that was never
-- written is not written. Hours played is counted in whole seconds by IncrementAsync deltas;
-- the ordered store is its only record. A flush runs at most once per WriteIntervalSeconds
-- (unless forced), writes at most MaxWritesPerFlush entries and stops below MinWriteBudget.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local Config = GameConfig.Leaderboards
local HOURS = "HoursPlayed"
local ROBUX = "RobuxSpent"
local MAX_PLAYTIME_STEP = 3600

local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function isBoard(boardKey: unknown): boolean
	for _, key in Config.Keys do
		if key == boardKey then
			return true
		end
	end
	return false
end

function LeaderboardService.playerKey(userId: number): string
	return "player_" .. SaveProfile.userIdText(userId)
end

function LeaderboardService.saveKey(saveId: string): string
	return "save_" .. saveId
end

-- The user ID inside a board key: `player_<digits>` or the owner of `save_<saveId>`.
function LeaderboardService.ownerOfKey(key: string): number?
	if type(key) ~= "string" then
		return nil
	end
	local digits = string.match(key, "^player_(%d+)$")
	if digits then
		return tonumber(digits)
	end
	local saveId = string.match(key, "^save_(.+)$")
	if saveId then
		return SaveProfile.ownerUserIdOf(saveId)
	end
	return nil
end

function LeaderboardService.storeName(boardKey: string, studio: boolean): string
	local name = string.format(Config.StoreFormat, boardKey)
	return if studio then name .. Config.StudioSuffix else name
end

-- deps: store(boardKey) -> OrderedDataStore, budget() -> number, userName(userId) -> string?,
-- clock() -> number, publish(boardKey, rows).
function LeaderboardService.new(deps)
	local self = setmetatable({}, LeaderboardService)
	self._deps = deps
	self._entries = {} :: { [string]: { [string]: { value: number, written: number? } } }
	for _, board in Config.Keys do
		self._entries[board] = {}
	end
	self._play = {} :: { [number]: { pending: number, total: number? } }
	self._ranks = {} :: { [string]: { [string]: number } }
	self._inflight = {} :: { [string]: boolean }
	self._lastFlushAt = -math.huge
	self._flushing = false
	self._stats = { flushes = 0, writes = 0, failures = 0, rateLimited = 0, noBudget = 0 }
	return self
end

function LeaderboardService:_budget(): number
	local ok, value = pcall(self._deps.budget)
	return if ok and isFinite(value) then value else 0
end

function LeaderboardService:_playOf(userId: number)
	local play = self._play[userId]
	if play == nil then
		play = { pending = 0, total = nil }
		self._play[userId] = play
	end
	return play
end

-- Caches a Set board value; false for an unknown board, HoursPlayed, a wrong key or value.
function LeaderboardService:report(boardKey: string, key: string, value: number): boolean
	if not isBoard(boardKey) or boardKey == HOURS then
		return false
	end
	if type(key) ~= "string" or #key > SaveProfile.KEY_MAX_LENGTH then
		return false
	end
	if Config.PerSave[boardKey] then
		local saveId = string.match(key, "^save_(.+)$")
		if not SaveProfile.isSaveId(saveId) then
			return false
		end
	elseif string.match(key, "^player_%d+$") == nil then
		return false
	end
	if not isFinite(value) or value < 0 then
		return false
	end
	local entries = self._entries[boardKey]
	local entry = entries[key]
	if entry == nil then
		entries[key] = { value = math.floor(value), written = nil }
	else
		entry.value = math.floor(value)
	end
	return true
end

-- Adds played seconds (finite, > 0, at most one hour per call); written by the next flush.
function LeaderboardService:addPlaytime(userId: number, seconds: number)
	if not isFinite(seconds) or seconds <= 0 or seconds > MAX_PLAYTIME_STEP then
		return
	end
	local play = self:_playOf(userId)
	play.pending += seconds
end

-- Reads the stored hours-played seconds once, so the "You" row has a total before a write.
function LeaderboardService:loadPlayer(userId: number)
	local ok, value = pcall(function()
		return self._deps.store(HOURS):GetAsync(LeaderboardService.playerKey(userId))
	end)
	if ok and isFinite(value) then
		local play = self:_playOf(userId)
		if play.total == nil then
			play.total = value
		end
	end
end

function LeaderboardService:forgetPlayer(userId: number)
	local play = self._play[userId]
	if play == nil then
		return
	end
	play.total = nil
	if play.pending < 1 then
		self._play[userId] = nil
	end
end

local function isDirty(entry): boolean
	return entry.value ~= entry.written and not (entry.written == nil and entry.value == 0)
end

-- One IncrementAsync of the whole pending seconds; true on success.
function LeaderboardService:_writePlaytime(userId: number): boolean
	local play = self._play[userId]
	local key = LeaderboardService.playerKey(userId)
	local flightKey = HOURS .. ":" .. key
	if play == nil or play.pending < 1 or self._inflight[flightKey] then
		return false
	end
	local delta = math.floor(play.pending)
	self._inflight[flightKey] = true
	local ok, result = pcall(function()
		return self._deps.store(HOURS):IncrementAsync(key, delta)
	end)
	self._inflight[flightKey] = nil
	if ok then
		play.pending -= delta
		play.total = if isFinite(result) then result else (play.total or 0) + delta
		self._stats.writes += 1
		return true
	end
	self._stats.failures += 1
	warn(string.format("[ChristmasMarket2] leaderboard write %s failed: %s", flightKey, tostring(result)))
	return false
end

-- One SetAsync of a dirty entry's current value; true on success.
function LeaderboardService:_writeEntry(board: string, key: string): boolean
	local entry = self._entries[board][key]
	local flightKey = board .. ":" .. key
	if entry == nil or not isDirty(entry) or self._inflight[flightKey] then
		return false
	end
	local v = entry.value
	self._inflight[flightKey] = true
	local ok, result = pcall(function()
		return self._deps.store(board):SetAsync(key, v)
	end)
	self._inflight[flightKey] = nil
	if ok then
		entry.written = v
		self._stats.writes += 1
		return true
	end
	self._stats.failures += 1
	warn(string.format("[ChristmasMarket2] leaderboard write %s failed: %s", flightKey, tostring(result)))
	return false
end

-- Write candidates in order: playtime per userId ascending, then dirty Set entries by board
-- order and key ascending. Entries in flight are skipped.
function LeaderboardService:_candidates(): { { kind: string, board: string, key: string, userId: number } }
	local list = {}
	local userIds = {}
	for userId, play in self._play do
		if play.pending >= 1 then
			table.insert(userIds, userId)
		end
	end
	table.sort(userIds)
	for _, userId in userIds do
		local key = LeaderboardService.playerKey(userId)
		if not self._inflight[HOURS .. ":" .. key] then
			table.insert(list, { kind = "play", board = HOURS, key = key, userId = userId })
		end
	end
	for _, board in Config.Keys do
		local keys = {}
		for key, entry in self._entries[board] do
			if isDirty(entry) and not self._inflight[board .. ":" .. key] then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		for _, key in keys do
			table.insert(list, { kind = "set", board = board, key = key, userId = 0 })
		end
	end
	return list
end

-- Writes cached changes. Returns the successful writes, plus "Busy", "RateLimited" or
-- "NoBudget" when nothing was attempted.
function LeaderboardService:flush(force: boolean?): (number, string?)
	if self._flushing then
		return 0, "Busy"
	end
	local now = self._deps.clock()
	if not force and now - self._lastFlushAt < Config.WriteIntervalSeconds then
		self._stats.rateLimited += 1
		return 0, "RateLimited"
	end
	if self:_budget() < Config.MinWriteBudget then
		self._stats.noBudget += 1
		return 0, "NoBudget"
	end
	self._flushing = true
	self._lastFlushAt = now
	self._stats.flushes += 1
	local written = 0
	local ok, err = pcall(function()
		local attempts = 0
		for _, candidate in self:_candidates() do
			if attempts >= Config.MaxWritesPerFlush or self:_budget() < Config.MinWriteBudget then
				break
			end
			attempts += 1
			local success = if candidate.kind == "play"
				then self:_writePlaytime(candidate.userId)
				else self:_writeEntry(candidate.board, candidate.key)
			if success then
				written += 1
			end
		end
	end)
	self._flushing = false
	if not ok then
		warn(string.format("[ChristmasMarket2] leaderboard flush errored: %s", tostring(err)))
	end
	return written, nil
end

-- Writes one leaving player's playtime and Robux spent at once, without the interval.
function LeaderboardService:flushUser(userId: number): number
	local written = 0
	if self:_budget() < Config.MinWriteBudget then
		return written
	end
	if self:_writePlaytime(userId) then
		written += 1
	end
	if self:_budget() < Config.MinWriteBudget then
		return written
	end
	if self:_writeEntry(ROBUX, LeaderboardService.playerKey(userId)) then
		written += 1
	end
	return written
end

-- Reads the top RankDepth of every board, publishes its top TopCount rows and keeps the ranks.
-- A failed read keeps the board's old ranks and publishes nothing. Returns the boards read.
function LeaderboardService:refresh(): number
	local read = 0
	for _, board in Config.Keys do
		local ok, page = pcall(function()
			local pages = self._deps.store(board):GetSortedAsync(false, Config.RankDepth)
			return pages:GetCurrentPage()
		end)
		if ok and type(page) == "table" then
			read += 1
			local ranks: { [string]: number } = {}
			local rows = {}
			for index, item in ipairs(page) do
				ranks[item.key] = index
				if index <= Config.TopCount then
					local owner = LeaderboardService.ownerOfKey(item.key)
					local name: string? = nil
					if owner ~= nil then
						local named, result = pcall(self._deps.userName, owner)
						if named and type(result) == "string" then
							name = result
						end
					end
					table.insert(rows, { rank = index, name = name, value = item.value })
				end
			end
			self._ranks[board] = ranks
			self._deps.publish(board, rows)
		end
	end
	return read
end

-- The viewer's value (nil when unknown) and rank (0 = not in the top RankDepth).
function LeaderboardService:you(boardKey: string, key: string): (number?, number)
	local value: number? = nil
	if boardKey == HOURS then
		local userId = LeaderboardService.ownerOfKey(key)
		local play = if userId ~= nil and string.match(key, "^player_") then self._play[userId] else nil
		if play ~= nil and play.total ~= nil then
			value = play.total + math.floor(play.pending)
		end
	else
		local entries = self._entries[boardKey]
		local entry = entries and entries[key]
		if entry ~= nil then
			value = entry.value
		end
	end
	local ranks = self._ranks[boardKey]
	local rank = ranks and ranks[key] or 0
	return value, rank
end

function LeaderboardService:stats()
	local copy = table.clone(self._stats) :: any
	local dirty = 0
	for _, board in Config.Keys do
		for _, entry in self._entries[board] do
			if isDirty(entry) then
				dirty += 1
			end
		end
	end
	copy.dirty = dirty
	local pending = {}
	for userId, play in self._play do
		pending[SaveProfile.userIdText(userId)] = play.pending
	end
	copy.playtimePending = pending
	return copy
end

return LeaderboardService
