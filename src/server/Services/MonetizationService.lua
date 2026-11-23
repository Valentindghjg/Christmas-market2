--!strict
-- Robux shop server (CM2-46a, docs/plans/CM2-46a.md): developer-product receipts, game-pass
-- ownership and perks, Robux spent and the validated Shop.* actions. Headless: every engine
-- call comes in through injected deps (main.server.lua wires MarketplaceService and Players).
--
-- Receipt rule: a receipt is granted only into the buyer's active, available save. The
-- purchase is bound to that save in the player ledger before the grant; the grant writes the
-- receipt ID into the save record and saves it; the ledger then records the purchase as done.
-- Only after all three succeed is the receipt PurchaseGranted. Every failure returns
-- NotProcessedYet, and a retry finds the receipt in the save, so nothing is granted twice.
-- The purchase effect (staff rest, thanks notice) follows the live record: it runs once per
-- live grant, also when the save after the grant failed (Amendment 1).
-- Engineering creates or publishes nothing on Roblox: with every ID 0 nothing is prompted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("Protocol"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local MonetizationService = {}
MonetizationService.__index = MonetizationService

local GRANTED = "PurchaseGranted"
local NOT_PROCESSED = "NotProcessedYet"
local MAX_ROBUX = 1e6
local MAX_PURCHASE_ID_BYTES = 64
local SHOP_BUCKET = "Shop"

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

-- The save ID of a `save:<saveId>` company, or nil.
local function saveIdOf(companyId: unknown): string?
	if type(companyId) ~= "string" then
		return nil
	end
	local saveId = string.match(companyId, "^save:(.+)$")
	return if SaveProfile.isSaveId(saveId) then saveId else nil
end

-- deps: companies, ledger, persistence, activeCompanyId(userId), playersOn(companyId),
-- isPresent(userId), ownsPass(userId, passId), prompt(userId, kind, id),
-- productPrice(kind, id), onApplied(userId, companyId, product),
-- setAttribute(userId, name, value), wait(seconds), clock(), shopConfig?.
function MonetizationService.new(deps)
	local self = setmetatable({}, MonetizationService)
	self._deps = deps
	self._companies = deps.companies
	self._ledger = deps.ledger
	self._persistence = deps.persistence
	self._config = deps.shopConfig or ShopConfig
	self._limiter = Protocol.newRateLimiter(self._config.ShopLimit.limit, self._config.ShopLimit.window)
	-- Purchase IDs whose receipt this server is processing right now.
	self._inFlight = {}
	-- Ledger records per user (runtime cache; the ledger store is the truth).
	self._records = {}
	-- Pass ownership per user: { [passKey] = boolean }.
	self._owned = {}
	-- Live Robux prices per product key (refreshPrices).
	self._livePrices = {}
	self._prompts = 0
	return self
end

-- Calls an injected dep in pcall. Returns (true, results...) or (false, error).
function MonetizationService:_dep(name: string, ...): (boolean, any)
	local fn = self._deps[name]
	if type(fn) ~= "function" then
		return false, "MissingDep:" .. name
	end
	return pcall(fn, ...)
end

function MonetizationService:_now(): number
	local ok, value = self:_dep("clock")
	if ok and isFiniteInteger(value) and value >= 0 then
		return value
	end
	return 0
end

function MonetizationService:_setAttribute(userId: number, name: string, value: any)
	local ok, err = self:_dep("setAttribute", userId, name, value)
	if not ok then
		warn(string.format("[ChristmasMarket2] shop attribute %s failed: %s", name, tostring(err)))
	end
end

function MonetizationService:_activeCompanyId(userId: number): string?
	local ok, companyId = self:_dep("activeCompanyId", userId)
	return if ok and type(companyId) == "string" then companyId else nil
end

function MonetizationService:_cacheRecord(userId: number, record)
	if type(record) == "table" then
		self._records[userId] = record
		self:_setAttribute(userId, "RobuxSpent", record.robuxSpent)
	end
end

function MonetizationService:_passOwned(userId: number, key: string): boolean
	local owned = self._owned[userId]
	return owned ~= nil and owned[key] == true
end

function MonetizationService:_unlocked(userId: number, key: string): boolean
	local record = self._records[userId]
	return record ~= nil and type(record.unlocks) == "table" and record.unlocks[key] == true
end

function MonetizationService:_priceOf(product): number
	local live = self._livePrices[product.key]
	return if type(live) == "number" then live else product.price
end

-- Developer-product receipts (MarketplaceService.ProcessReceipt). Unknown product IDs are
-- never granted.
function MonetizationService:processReceipt(info): string
	local productId = if type(info) == "table" then info.ProductId else nil
	local product = self._config.byProductId(productId)
	if product == nil then
		warn(string.format("[ChristmasMarket2] unknown product %s", tostring(productId)))
		return NOT_PROCESSED
	end
	return self:processReceiptByKey(product.key, info)
end

-- One receipt for a known product key. options.present (Studio hook only) replaces the
-- isPresent check. Returns "PurchaseGranted" or "NotProcessedYet".
function MonetizationService:processReceiptByKey(productKey: string, info, options): string
	if type(info) ~= "table" then
		return NOT_PROCESSED
	end
	local userId = info.PlayerId
	local purchaseId = info.PurchaseId
	if not isFiniteInteger(userId) then
		return NOT_PROCESSED
	end
	if type(purchaseId) ~= "string" or #purchaseId < 1 or #purchaseId > MAX_PURCHASE_ID_BYTES then
		return NOT_PROCESSED
	end
	local product = self._config.byKey(productKey)
	if product == nil or product.kind ~= "Product" then
		return NOT_PROCESSED
	end
	local spent = info.CurrencySpent
	local robux = if isFiniteInteger(spent) and spent >= 0 and spent <= MAX_ROBUX then spent else 0
	if self._inFlight[purchaseId] then
		return NOT_PROCESSED
	end
	self._inFlight[purchaseId] = true
	local called, decision = pcall(self._process, self, userId, purchaseId, product, robux, options)
	self._inFlight[purchaseId] = nil
	if not called then
		warn(string.format("[ChristmasMarket2] receipt %s failed: %s", purchaseId, tostring(decision)))
		return NOT_PROCESSED
	end
	return if decision == GRANTED then GRANTED else NOT_PROCESSED
end

-- Waits for the buyer's available save: nil when the buyer is gone or none is played in time.
function MonetizationService:_awaitSave(userId: number, options): string?
	local config = self._config
	local polls = math.floor(config.ReceiptWaitSeconds / config.ReceiptPollSeconds)
	for _ = 1, polls do
		local present = false
		if type(options) == "table" and options.present ~= nil then
			present = options.present == true
		else
			local ok, value = self:_dep("isPresent", userId)
			present = ok and value == true
		end
		if not present then
			return nil
		end
		local companyId = self:_activeCompanyId(userId)
		if companyId ~= nil and saveIdOf(companyId) ~= nil and self._companies:isAvailable(companyId) then
			return companyId
		end
		local waited, err = self:_dep("wait", config.ReceiptPollSeconds)
		if not waited then
			warn(string.format("[ChristmasMarket2] receipt wait failed: %s", tostring(err)))
			return nil
		end
	end
	return nil
end

function MonetizationService:_process(userId: number, purchaseId: string, product, robux: number, options): string
	-- 1. The buyer's active save.
	local companyId = self:_awaitSave(userId, options)
	if companyId == nil then
		return NOT_PROCESSED
	end
	local saveId = saveIdOf(companyId) :: string
	local entry = {
		purchaseId = purchaseId,
		productKey = product.key,
		saveId = saveId,
		robux = robux,
		at = self:_now(),
	}

	-- 2. Bind the purchase to this save before the grant.
	local status, other = self._ledger:bind(userId, entry)
	if status == "Done" then
		return GRANTED
	end
	if status == "Other" then
		if not SaveProfile.isSaveId(other) then
			return NOT_PROCESSED
		end
		local peeked = self._persistence:peekReceipt("save:" .. other, purchaseId)
		if peeked == "Applied" then
			-- The other save already received it: finish there, grant nothing here.
			local finished = table.clone(entry)
			finished.saveId = other :: string
			local record = self._ledger:finish(userId, finished, product.perPlayer)
			if record == nil then
				return NOT_PROCESSED
			end
			self:_cacheRecord(userId, record)
			return GRANTED
		end
		if peeked ~= "Free" then
			-- Held by a live session (or the peek failed): that save may still save it.
			return NOT_PROCESSED
		end
		-- No live session holds the other save and it never got the grant: move it here.
		if self._ledger:bind(userId, entry, other) ~= "Bound" then
			return NOT_PROCESSED
		end
	elseif status ~= "Bound" then
		return NOT_PROCESSED
	end

	-- 3. Grant into the save; the receipt is saved with it.
	-- The effect follows the live record (Amendment 1), so it runs before the save check.
	local granted, grantError, applied = self._companies:grantPurchase(companyId, purchaseId, product)
	if applied then
		local ok, err = self:_dep("onApplied", userId, companyId, product)
		if not ok then
			warn(string.format("[ChristmasMarket2] purchase effect hook failed: %s", tostring(err)))
		end
	end
	if not granted then
		warn(string.format("[ChristmasMarket2] receipt %s not granted: %s", purchaseId, tostring(grantError)))
		return NOT_PROCESSED
	end

	-- 4. The ledger records it as done, then the receipt is acknowledged.
	local record = self._ledger:finish(userId, entry, product.perPlayer)
	if record == nil then
		return NOT_PROCESSED
	end
	self:_cacheRecord(userId, record)
	return GRANTED
end

-- A player joined: cache the ledger, show Robux spent and check the passes.
function MonetizationService:onPlayerJoined(userId: number)
	local record = self._ledger:read(userId)
	if type(record) == "table" then
		self._records[userId] = record
	end
	self:_setAttribute(userId, "RobuxSpent", if type(record) == "table" then record.robuxSpent else 0)
	self:refreshPasses(userId)
end

-- Adds the price of each owned pass to Robux spent once (live price, else the config price).
function MonetizationService:_countOwnedPasses(userId: number)
	local record = self._records[userId]
	local counted = if record ~= nil and type(record.passesCounted) == "table" then record.passesCounted else {}
	local prices = {}
	local any = false
	for _, product in ipairs(self._config.Products) do
		if product.kind == "Pass" and self:_passOwned(userId, product.key) and counted[product.key] ~= true then
			prices[product.key] = self:_priceOf(product)
			any = true
		end
	end
	if not any then
		return
	end
	local updated = self._ledger:countPasses(userId, prices)
	self:_cacheRecord(userId, updated)
end

function MonetizationService:_showPasses(userId: number)
	for _, product in ipairs(self._config.Products) do
		if product.kind == "Pass" then
			self:_setAttribute(userId, "Shop" .. product.key, self:_passOwned(userId, product.key))
		end
	end
end

-- Checks every pass with an ID; an error keeps the previous value (default false).
function MonetizationService:refreshPasses(userId: number)
	local owned = self._owned[userId] or {}
	self._owned[userId] = owned
	for _, product in ipairs(self._config.Products) do
		if product.kind == "Pass" then
			if product.id > 0 then
				local ok, result = self:_dep("ownsPass", userId, product.id)
				if ok and type(result) == "boolean" then
					owned[product.key] = result
				end
			end
			if owned[product.key] == nil then
				owned[product.key] = false
			end
		end
	end
	self:_showPasses(userId)
	self:_countOwnedPasses(userId)
	self:refreshPerks(self:_activeCompanyId(userId))
end

-- PromptGamePassPurchaseFinished: a bought known pass is owned at once.
function MonetizationService:onPassPurchaseFinished(userId: number, passId: number, purchased: boolean)
	if purchased ~= true then
		return
	end
	local product = self._config.byPassId(passId)
	if product == nil then
		return
	end
	local owned = self._owned[userId] or {}
	self._owned[userId] = owned
	owned[product.key] = true
	self:_setAttribute(userId, "Shop" .. product.key, true)
	self:_countOwnedPasses(userId)
	self:refreshPerks(self:_activeCompanyId(userId))
end

-- A pass perk applies to a save while at least one of its players on this server owns the
-- pass. excludeUserId leaves out a player who is leaving the save.
function MonetizationService:refreshPerks(companyId: string?, excludeUserId: number?)
	if companyId == nil then
		return
	end
	local ok, userIds = self:_dep("playersOn", companyId)
	if not ok or type(userIds) ~= "table" then
		return
	end
	local perks = {}
	for _, field in ipairs(self._config.PerkFields) do
		perks[field] = false
	end
	for _, userId in ipairs(userIds) do
		if userId ~= excludeUserId then
			for _, product in ipairs(self._config.Products) do
				if product.kind == "Pass" and product.perk ~= nil and self:_passOwned(userId, product.key) then
					perks[product.perk] = true
				end
			end
		end
	end
	self._companies:setPerks(companyId, perks)
end

-- Caches the live Robux price of every product with an ID.
function MonetizationService:refreshPrices()
	for _, product in ipairs(self._config.Products) do
		if product.id > 0 then
			local ok, price = self:_dep("productPrice", product.kind, product.id)
			if ok and isFiniteInteger(price) and price >= 0 then
				self._livePrices[product.key] = price
			end
		end
	end
end

function MonetizationService:_state(userId: number, product): string
	if product.id <= 0 or not product.ready then
		return "ComingSoon"
	end
	if product.kind == "Pass" and self:_passOwned(userId, product.key) then
		return "Owned"
	end
	if product.perPlayer and self:_unlocked(userId, product.key) then
		return "Owned"
	end
	return "Buy"
end

function MonetizationService:_catalog(userId: number)
	local products = {}
	for _, product in ipairs(self._config.Products) do
		table.insert(products, {
			key = product.key,
			category = product.category,
			kind = product.kind,
			price = self:_priceOf(product),
			state = self:_state(userId, product),
			grant = if product.grant ~= nil then table.clone(product.grant) else nil,
		})
	end
	return { ok = true, data = { products = products, robuxSpent = self:robuxSpent(userId) } }
end

function MonetizationService:_prompt(userId: number, productKey: string)
	local config = self._config
	local product = config.byKey(productKey)
	if product == nil then
		return { ok = false, errorCode = "UnknownProduct" }
	end
	if product.id <= 0 or not product.ready then
		return { ok = false, errorCode = "ComingSoon" }
	end
	if
		(product.kind == "Pass" and self:_passOwned(userId, product.key))
		or (product.perPlayer and self:_unlocked(userId, product.key))
	then
		return { ok = false, errorCode = "AlreadyOwned" }
	end
	if product.perPlayer and self._records[userId] == nil then
		return { ok = false, errorCode = "ShopUnavailable" }
	end
	if product.kind == "Product" then
		local companyId = self:_activeCompanyId(userId)
		if companyId == nil or not self._companies:isAvailable(companyId) then
			return { ok = false, errorCode = "NoActiveSave" }
		end
		local grant = product.grant
		if grant ~= nil and type(grant.boostSeconds) == "number" then
			local current = self._companies:boostSeconds(companyId) or 0
			if current + grant.boostSeconds > config.BoostCapSeconds then
				return { ok = false, errorCode = "BoostFull" }
			end
		end
	end
	self._prompts += 1
	local ok, err = self:_dep("prompt", userId, product.kind, product.id)
	if not ok then
		warn(string.format("[ChristmasMarket2] shop prompt failed: %s", tostring(err)))
		return { ok = false, errorCode = "PromptFailed" }
	end
	return { ok = true }
end

-- Untrusted Shop.* requests: validated, rate-limited, then answered. Only the server prompts.
function MonetizationService:handle(userId: number, request)
	local valid, validationError = Protocol.validateShopRequest(request)
	if not valid then
		return { ok = false, errorCode = validationError }
	end
	if not Protocol.allowRequest(self._limiter, userId, SHOP_BUCKET, self:_now()) then
		return { ok = false, errorCode = "RateLimited" }
	end
	if request.action == Protocol.ShopActions.Catalog then
		return self:_catalog(userId)
	end
	return self:_prompt(userId, request.payload.productKey)
end

-- The player's Robux spent from the cached ledger; nil without a cache.
function MonetizationService:robuxSpent(userId: number): number?
	local record = self._records[userId]
	return if record ~= nil then record.robuxSpent else nil
end

function MonetizationService:forgetUser(userId: number)
	self._records[userId] = nil
	self._owned[userId] = nil
	Protocol.forgetUser(self._limiter, userId)
end

-- Studio test instruments only (StudioTestService); never called by gameplay code.

-- Sets the user's pass ownership (passes = { [passKey] = true }), its attributes and perks.
function MonetizationService:setPassesForTest(userId: number, passes)
	local owned = {}
	for _, product in ipairs(self._config.Products) do
		if product.kind == "Pass" then
			owned[product.key] = type(passes) == "table" and passes[product.key] == true
		end
	end
	self._owned[userId] = owned
	self:_showPasses(userId)
	self:refreshPerks(self:_activeCompanyId(userId))
end

-- How often deps.prompt was called.
function MonetizationService:promptCountForTest(): number
	return self._prompts
end

return MonetizationService
