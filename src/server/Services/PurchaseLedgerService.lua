--!strict
-- The player purchase ledger (CM2-46a, docs/archive/plans/CM2-46a.md): one record per player in its
-- own store. It binds a Robux purchase to the save that receives it before the grant
-- (`pending`), keeps the finished purchases (`done`), the player's Robux spent, the passes
-- already counted and the per-player unlocks. The company save holds the receipt itself.
-- Every call is one UpdateAsync; a transform that changes nothing, or finds an invalid
-- record, returns nil and writes nothing. A corrupt ledger is never overwritten.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local PurchaseLedgerService = {}
PurchaseLedgerService.__index = PurchaseLedgerService

local STORE_NAME = "ChristmasMarket2_Purchases_v1"
local LEDGER_VERSION = 1
local MAX_ATTEMPTS = 3
local RETRY_WAITS = { 1, 2 }
local MAX_PURCHASE_ID_BYTES = 64

PurchaseLedgerService.STORE_NAME = STORE_NAME

-- `purchases:<userId>`: at most 29 characters for a 19-digit user ID.
function PurchaseLedgerService.keyFor(userId: number): string
	return "purchases:" .. SaveProfile.userIdText(userId)
end

-- Resolved lazily: the headless runner (Lune) has no `task` library.
local function defaultWait(seconds: number)
	task.wait(seconds)
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[deepCopy(key)] = deepCopy(inner)
	end
	return copy
end

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function isCount(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 0
end

local function isPurchaseId(value: unknown): boolean
	return type(value) == "string" and #value >= 1 and #value <= MAX_PURCHASE_ID_BYTES
end

-- A proper array: keys exactly 1..n. Returns n, or nil when the table is not an array.
local function arrayLength(value: { [any]: any }): number?
	local entries = 0
	local maxKey = 0
	for key in pairs(value) do
		if not isFiniteInteger(key) or key < 1 then
			return nil
		end
		entries += 1
		if key > maxKey then
			maxKey = key
		end
	end
	if maxKey ~= entries then
		return nil
	end
	return entries
end

local function validFlags(flags: unknown): boolean
	if type(flags) ~= "table" then
		return false
	end
	for key, value in pairs(flags :: { [any]: any }) do
		if not ShopConfig.isKey(key) or value ~= true then
			return false
		end
	end
	return true
end

local function validBinding(entry: any): boolean
	return type(entry) == "table"
		and ShopConfig.isKey(entry.productKey)
		and SaveProfile.isSaveId(entry.saveId)
		and isCount(entry.robux)
		and isCount(entry.at)
end

local function isValidRecord(record: any): boolean
	if
		type(record) ~= "table"
		or record.ledgerVersion ~= LEDGER_VERSION
		or not isFiniteInteger(record.userId)
		or not isCount(record.robuxSpent)
	then
		return false
	end
	if type(record.pending) ~= "table" then
		return false
	end
	local pendingCount = 0
	for purchaseId, entry in pairs(record.pending) do
		if not isPurchaseId(purchaseId) or not validBinding(entry) then
			return false
		end
		pendingCount += 1
	end
	if pendingCount > ShopConfig.LedgerPendingCap then
		return false
	end
	if type(record.done) ~= "table" then
		return false
	end
	local doneLength = arrayLength(record.done)
	if doneLength == nil or doneLength > ShopConfig.LedgerDoneCap then
		return false
	end
	for _, entry in ipairs(record.done) do
		if not validBinding(entry) or not isPurchaseId(entry.purchaseId) then
			return false
		end
	end
	return validFlags(record.passesCounted) and validFlags(record.unlocks)
end

local function findDone(record, purchaseId: string): boolean
	for _, entry in ipairs(record.done) do
		if entry.purchaseId == purchaseId then
			return true
		end
	end
	return false
end

local function pendingCount(record): number
	local count = 0
	for _ in pairs(record.pending) do
		count += 1
	end
	return count
end

function PurchaseLedgerService.new(store, wait)
	local self = setmetatable({}, PurchaseLedgerService)
	self._store = store or DataStoreService:GetDataStore(STORE_NAME)
	self._wait = wait or defaultWait
	return self
end

function PurchaseLedgerService.newRecord(userId: number)
	return {
		ledgerVersion = LEDGER_VERSION,
		userId = userId,
		robuxSpent = 0,
		pending = {},
		done = {},
		passesCounted = {},
		unlocks = {},
	}
end

-- One UpdateAsync on the player's key. change(record) works on a copy and returns
-- (changed, ...results); a changed record is written only when it is still valid.
-- Returns (true, record, ...results) or (false, errorCode).
function PurchaseLedgerService:_update(userId: number, change): (boolean, any, any, any)
	local key = PurchaseLedgerService.keyFor(userId)
	local refusal: string? = nil
	local result: any = nil
	local first: any = nil
	local second: any = nil
	local lastError = "Unknown"
	for attempt = 1, MAX_ATTEMPTS do
		local ok, err = pcall(function()
			return self._store:UpdateAsync(key, function(previous)
				-- The transform can run more than once; reset its results first.
				refusal = nil
				result = nil
				first = nil
				second = nil
				local record = if previous == nil then PurchaseLedgerService.newRecord(userId) else deepCopy(previous)
				if not isValidRecord(record) then
					refusal = "LedgerCorrupt"
					return nil
				end
				local changed, a, b = change(record)
				if changed and not isValidRecord(record) then
					refusal = "LedgerCorrupt"
					return nil
				end
				result = record
				first = a
				second = b
				return if changed then record else nil
			end)
		end)
		if ok then
			if refusal ~= nil then
				return false, refusal, nil, nil
			end
			return true, deepCopy(result), first, second
		end
		lastError = tostring(err)
		if attempt < MAX_ATTEMPTS then
			self._wait(RETRY_WAITS[attempt])
		end
	end
	warn(
		string.format("[ChristmasMarket2] purchase ledger of %s failed: %s", SaveProfile.userIdText(userId), lastError)
	)
	return false, "LoadFailed", nil, nil
end

-- The player's ledger (a new, unwritten record when none exists). Never writes.
function PurchaseLedgerService:read(userId: number): (any, string?)
	local ok, record = self:_update(userId, function()
		return false
	end)
	if not ok then
		return nil, record
	end
	return record, nil
end

-- Binds a purchase to the save that is about to receive it (before the grant).
-- entry = {purchaseId, productKey, saveId, robux, at}. Returns "Done" (already finished),
-- "Bound", ("Other", pendingSaveId) or "Full"; a pending binding to replaceSaveId is moved to
-- entry.saveId. Errors return (nil, errorCode).
function PurchaseLedgerService:bind(userId: number, entry, replaceSaveId: string?): (string?, string?)
	local ok, recordOrCode, status, other = self:_update(userId, function(record)
		local purchaseId = entry.purchaseId
		if findDone(record, purchaseId) then
			return false, "Done", nil
		end
		local pending = record.pending[purchaseId]
		if pending ~= nil then
			if pending.saveId == entry.saveId then
				return false, "Bound", nil
			end
			if replaceSaveId ~= nil and pending.saveId == replaceSaveId then
				pending.saveId = entry.saveId
				pending.at = entry.at
				return true, "Bound", nil
			end
			return false, "Other", pending.saveId
		end
		if pendingCount(record) >= ShopConfig.LedgerPendingCap then
			return false, "Full", nil
		end
		record.pending[purchaseId] = {
			productKey = entry.productKey,
			saveId = entry.saveId,
			robux = entry.robux,
			at = entry.at,
		}
		return true, "Bound", nil
	end)
	if not ok then
		return nil, recordOrCode
	end
	return status, other
end

-- Records a purchase as finished once: it leaves `pending`, joins `done` (oldest trimmed),
-- adds its Robux to robuxSpent and, for a per-player product, unlocks it.
function PurchaseLedgerService:finish(userId: number, entry, perPlayer: boolean?): (any, string?)
	local ok, record = self:_update(userId, function(current)
		if findDone(current, entry.purchaseId) then
			return false
		end
		current.pending[entry.purchaseId] = nil
		table.insert(current.done, {
			purchaseId = entry.purchaseId,
			productKey = entry.productKey,
			saveId = entry.saveId,
			robux = entry.robux,
			at = entry.at,
		})
		while #current.done > ShopConfig.LedgerDoneCap do
			table.remove(current.done, 1)
		end
		current.robuxSpent += entry.robux
		if perPlayer == true then
			current.unlocks[entry.productKey] = true
		end
		return true
	end)
	if not ok then
		return nil, record
	end
	return record, nil
end

-- Adds each owned pass's price to robuxSpent once. prices = { [passKey] = robux }.
function PurchaseLedgerService:countPasses(userId: number, prices: { [string]: number }): (any, string?)
	local ok, record = self:_update(userId, function(current)
		local changed = false
		for passKey, price in pairs(prices) do
			if current.passesCounted[passKey] ~= true then
				current.passesCounted[passKey] = true
				current.robuxSpent += price
				changed = true
			end
		end
		return changed
	end)
	if not ok then
		return nil, record
	end
	return record, nil
end

return PurchaseLedgerService
