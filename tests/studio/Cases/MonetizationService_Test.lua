--!strict
-- CM2-46a: Robux receipts, passes, perks and Shop.* actions over the real company, persistence
-- and ledger services with fake DataStores. No test touches a real store or MarketplaceService.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local MonetizationService = require(Services:WaitForChild("MonetizationService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PurchaseLedgerService = require(Services:WaitForChild("PurchaseLedgerService"))
	local expect = t.expect

	local USER = 42
	local OTHER_USER = 43
	local SAVE_A = "42_" .. string.rep("0a", 8)
	local SAVE_B = "42_" .. string.rep("0b", 8)
	local COMPANY_A = "save:" .. SAVE_A
	local COMPANY_B = "save:" .. SAVE_B
	local NOW = 1000

	-- Test-only IDs; the shipped config keeps every ID 0.
	local IDS = {
		CashPinecone = 1001,
		StarterPack = 1002,
		BoostCashX2 = 1003,
		DecorSnowGlobe = 1009, -- has an ID but is not ready
		PassCashX2 = 2001,
		PassVip = 2002,
	}

	local function configWithIds()
		local config = table.clone(ShopConfig)
		local products = {}
		for _, product in ipairs(ShopConfig.Products) do
			local copy = table.clone(product)
			copy.id = IDS[product.key] or 0
			table.insert(products, copy)
		end
		config.Products = products
		config.byKey = function(key)
			for _, product in ipairs(products) do
				if product.key == key then
					return product
				end
			end
			return nil
		end
		local function byId(kind: string)
			return function(id)
				if type(id) ~= "number" or id <= 0 then
					return nil
				end
				for _, product in ipairs(products) do
					if product.kind == kind and product.id == id then
						return product
					end
				end
				return nil
			end
		end
		config.byProductId = byId("Product")
		config.byPassId = byId("Pass")
		return config
	end

	local function deepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = deepCopy(inner)
		end
		return copy
	end

	local function fakeStore()
		local store: any = { records = {}, writes = 0, failCount = 0 }
		function store.UpdateAsync(_, key: string, transform)
			if store.failCount > 0 then
				store.failCount -= 1
				error("Throttled")
			end
			local nextValue = transform(deepCopy(store.records[key]))
			if nextValue ~= nil then
				store.records[key] = deepCopy(nextValue)
				store.writes += 1
			end
			return deepCopy(store.records[key])
		end
		return store
	end

	local function noWait() end

	local function setup()
		local env: any = {
			active = {},
			present = {},
			owns = {},
			prompts = 0,
			promptFails = false,
			waits = 0,
			onWait = nil,
			applied = {},
			attributes = {},
			companyStore = fakeStore(),
			ledgerStore = fakeStore(),
		}
		local function clock()
			return NOW
		end
		env.persistence = PersistenceService.new(env.companyStore, "job-a", clock, noWait)
		env.companies = CompanyStateService.new(env.persistence, clock, function()
			return 0
		end, noWait)
		env.ledger = PurchaseLedgerService.new(env.ledgerStore, noWait)
		env.monetization = MonetizationService.new({
			companies = env.companies,
			ledger = env.ledger,
			persistence = env.persistence,
			activeCompanyId = function(userId)
				return env.active[userId]
			end,
			playersOn = function(companyId)
				local list = {}
				for userId, active in pairs(env.active) do
					if active == companyId then
						table.insert(list, userId)
					end
				end
				table.sort(list)
				return list
			end,
			isPresent = function(userId)
				return env.present[userId] == true
			end,
			ownsPass = function(userId, passId)
				return env.owns[userId .. ":" .. passId] == true
			end,
			prompt = function()
				env.prompts += 1
				if env.promptFails then
					error("prompt down")
				end
			end,
			productPrice = function()
				return nil
			end,
			onApplied = function(_, _, product)
				table.insert(env.applied, product.key)
			end,
			setAttribute = function(userId, name, value)
				env.attributes[userId .. ":" .. name] = value
			end,
			wait = function()
				env.waits += 1
				if env.onWait then
					env.onWait(env.waits)
				end
			end,
			clock = clock,
			shopConfig = configWithIds(),
		})
		return env
	end

	-- Loads a save for USER and makes it the active one.
	local function play(env, companyId: string, userId: number?)
		local owner = userId or USER
		local state = nil
		if not env.companies:hasSession(companyId) then
			state = env.companies:loadCompany(companyId, USER)
			expect.truthy(state)
		end
		env.active[owner] = companyId
		env.present[owner] = true
		return state
	end

	local function receipt(purchaseId: string, productId: number?, robux: number?)
		return {
			PlayerId = USER,
			ProductId = productId or IDS.CashPinecone,
			PurchaseId = purchaseId,
			CurrencySpent = robux or 29,
		}
	end

	local function ledgerOf(env, userId: number?)
		return env.ledgerStore.records[PurchaseLedgerService.keyFor(userId or USER)]
	end

	local function stored(env, companyId: string)
		return env.companyStore.records[PersistenceService.keyFor(companyId)]
	end

	local requestCount = 0
	local function shop(env, userId: number, action: string, payload)
		requestCount += 1
		return env.monetization:handle(userId, {
			version = 1,
			requestId = string.format("shop_%06d", requestCount),
			action = action,
			payload = payload,
		})
	end

	t.test("grants a receipt once when it is replayed", function()
		local env = setup()
		local state = play(env, COMPANY_A)
		local cash = state.cash
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(state.cash, cash + 1200)
		expect.equal(state.purchases.owned.CashPinecone, 1)
		expect.equal(stored(env, COMPANY_A).cash, cash + 1200)
		expect.equal(stored(env, COMPANY_A).purchases.receipts[1], "r1")
		local record = ledgerOf(env)
		expect.equal(record.robuxSpent, 29)
		expect.equal(#record.done, 1)
		expect.equal(record.pending.r1, nil)
		expect.equal(env.monetization:robuxSpent(USER), 29)
		expect.equal(env.attributes[USER .. ":RobuxSpent"], 29)
		-- The effect hook runs once over both calls.
		expect.equal(#env.applied, 1)
	end)

	t.test("returns NotProcessedYet without an active save", function()
		local env = setup()
		env.present[USER] = true
		expect.equal(env.monetization:processReceipt(receipt("r1")), "NotProcessedYet")
		expect.equal(env.waits, 30)
		expect.equal(env.ledgerStore.writes, 0)
		expect.equal(env.companyStore.writes, 0)
	end)

	t.test("grants on the next load after the player left mid-purchase", function()
		local env = setup()
		expect.equal(env.monetization:processReceipt(receipt("r1")), "NotProcessedYet")
		expect.equal(env.waits, 0)
		expect.equal(env.ledgerStore.writes, 0)
		local state = play(env, COMPANY_A)
		local cash = state.cash
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(state.cash, cash + 1200)
	end)

	t.test("returns NotProcessedYet when the save fails and grants once on retry", function()
		local env = setup()
		local state = play(env, COMPANY_A)
		local cash = state.cash
		env.companyStore.failCount = 3
		expect.equal(env.monetization:processReceipt(receipt("r1")), "NotProcessedYet")
		expect.equal(ledgerOf(env).pending.r1.saveId, SAVE_A)
		expect.equal(#ledgerOf(env).done, 0)
		-- Amendment 1: the effect follows the live record, so it ran once despite the failed save.
		expect.equal(#env.applied, 1)
		expect.equal(env.applied[1], "CashPinecone")
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(#env.applied, 1)
		expect.equal(state.cash, cash + 1200)
		expect.equal(stored(env, COMPANY_A).cash, cash + 1200)
		expect.equal(ledgerOf(env).robuxSpent, 29)
		expect.equal(stored(env, COMPANY_A).purchases.owned.CashPinecone, 1)
	end)

	t.test("finishes a purchase already saved in another save", function()
		local env = setup()
		play(env, COMPANY_A)
		local product = configWithIds().byKey("CashPinecone")
		-- An earlier server bound the purchase to A, granted and saved it, then stopped.
		expect.equal(
			env.ledger:bind(
				USER,
				{ purchaseId = "r1", productKey = "CashPinecone", saveId = SAVE_A, robux = 29, at = 1 }
			),
			"Bound"
		)
		expect.truthy(env.companies:grantPurchase(COMPANY_A, "r1", product))
		expect.truthy(env.companies:unloadCompany(COMPANY_A))
		local stateB = play(env, COMPANY_B)
		local cashB = stateB.cash
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(stateB.cash, cashB)
		local record = ledgerOf(env)
		expect.equal(#record.done, 1)
		expect.equal(record.done[1].saveId, SAVE_A)
		expect.equal(record.robuxSpent, 29)
	end)

	t.test("moves a purchase to the current save when the bound save never got it", function()
		local env = setup()
		play(env, COMPANY_A)
		expect.truthy(env.companies:unloadCompany(COMPANY_A))
		expect.equal(
			env.ledger:bind(
				USER,
				{ purchaseId = "r1", productKey = "CashPinecone", saveId = SAVE_A, robux = 29, at = 1 }
			),
			"Bound"
		)
		local stateB = play(env, COMPANY_B)
		local cashB = stateB.cash
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(stateB.cash, cashB + 1200)
		expect.equal(ledgerOf(env).done[1].saveId, SAVE_B)
		expect.equal(stored(env, COMPANY_A).purchases.receipts[1], nil)
	end)

	t.test("waits while the bound save is held", function()
		local env = setup()
		play(env, COMPANY_A)
		expect.truthy(env.companies:unloadCompany(COMPANY_A))
		expect.equal(
			env.ledger:bind(
				USER,
				{ purchaseId = "r1", productKey = "CashPinecone", saveId = SAVE_A, robux = 29, at = 1 }
			),
			"Bound"
		)
		-- Another server holds A's lock.
		stored(env, COMPANY_A)._session = { jobId = "job-b", expiresAt = NOW + 60 }
		local stateB = play(env, COMPANY_B)
		local cashB = stateB.cash
		expect.equal(env.monetization:processReceipt(receipt("r1")), "NotProcessedYet")
		expect.equal(stateB.cash, cashB)
		expect.equal(ledgerOf(env).pending.r1.saveId, SAVE_A)
		expect.equal(#ledgerOf(env).done, 0)
	end)

	t.test("refuses unknown products and parallel duplicates", function()
		local env = setup()
		local state = play(env, COMPANY_A)
		local cash = state.cash
		expect.equal(env.monetization:processReceipt(receipt("r0", 9999)), "NotProcessedYet")
		expect.equal(env.monetization:processReceipt(receipt("r0", 0)), "NotProcessedYet")
		expect.equal(env.ledgerStore.writes, 0)
		-- The first call waits for its save; a second call for the same ID is refused meanwhile.
		env.active[USER] = nil
		local nested = nil
		env.onWait = function()
			if nested == nil then
				nested = env.monetization:processReceipt(receipt("r1"))
				env.active[USER] = COMPANY_A
			end
		end
		expect.equal(env.monetization:processReceipt(receipt("r1")), "PurchaseGranted")
		expect.equal(nested, "NotProcessedYet")
		expect.equal(state.cash, cash + 1200)
	end)

	t.test("validates Shop.Prompt and never prompts without an ID", function()
		local env = setup()
		local state = play(env, COMPANY_A)
		env.owns[USER .. ":" .. IDS.PassVip] = true
		env.monetization:onPlayerJoined(USER)
		local function code(userId: number, productKey: string): string?
			return shop(env, userId, "Shop.Prompt", { productKey = productKey }).errorCode
		end
		expect.equal(code(USER, "Nope"), "UnknownProduct")
		expect.equal(code(USER, "TreeFrostcrown"), "ComingSoon")
		expect.equal(code(USER, "DecorSnowGlobe"), "ComingSoon")
		expect.equal(env.prompts, 0)
		expect.equal(code(USER, "PassVip"), "AlreadyOwned")
		-- OTHER_USER never joined: no cached ledger, no active save.
		expect.equal(code(OTHER_USER, "StarterPack"), "ShopUnavailable")
		expect.equal(code(OTHER_USER, "CashPinecone"), "NoActiveSave")
		state.purchases.boosts.CashX2 = ShopConfig.BoostCapSeconds - 100
		expect.equal(code(USER, "BoostCashX2"), "BoostFull")
		expect.equal(env.prompts, 0)
		env.promptFails = true
		expect.equal(code(USER, "CashPinecone"), "PromptFailed")
		env.promptFails = false
		local ok = shop(env, USER, "Shop.Prompt", { productKey = "CashPinecone" })
		expect.truthy(ok.ok)
		expect.equal(env.prompts, 2)
		expect.equal(env.monetization:promptCountForTest(), 2)
		expect.equal(shop(env, USER, "Shop.Prompt", { productKey = "bad key" }).errorCode, "InvalidProduct")
		-- ShopLimit: 10 requests per 10 s per player.
		for _ = 1, 10 do
			expect.truthy(shop(env, OTHER_USER + 1, "Shop.Catalog", {}).ok)
		end
		expect.equal(shop(env, OTHER_USER + 1, "Shop.Catalog", {}).errorCode, "RateLimited")
	end)

	t.test("applies pass perks while a holder plays the save", function()
		local env = setup()
		play(env, COMPANY_A)
		play(env, COMPANY_A, OTHER_USER)
		env.owns[USER .. ":" .. IDS.PassCashX2] = true
		expect.falsy(env.companies:perksOf(COMPANY_A).cashX2)
		env.monetization:onPlayerJoined(USER)
		expect.truthy(env.companies:perksOf(COMPANY_A).cashX2)
		expect.falsy(env.companies:perksOf(COMPANY_A).vip)
		expect.equal(env.attributes[USER .. ":ShopPassCashX2"], true)
		expect.equal(env.attributes[USER .. ":ShopPassVip"], false)
		expect.equal(env.monetization:robuxSpent(USER), 99)
		-- The holder leaves the save: the other player has no pass.
		env.monetization:refreshPerks(COMPANY_A, USER)
		expect.falsy(env.companies:perksOf(COMPANY_A).cashX2)
		env.monetization:refreshPerks(COMPANY_A)
		expect.truthy(env.companies:perksOf(COMPANY_A).cashX2)
		-- The pass's Robux are counted once, however often it is seen.
		env.monetization:refreshPasses(USER)
		env.monetization:onPassPurchaseFinished(USER, IDS.PassCashX2, true)
		expect.equal(env.monetization:robuxSpent(USER), 99)
		expect.equal(ledgerOf(env).robuxSpent, 99)
		-- A pass bought in this session counts at once.
		env.monetization:onPassPurchaseFinished(USER, IDS.PassVip, true)
		expect.truthy(env.companies:perksOf(COMPANY_A).vip)
		expect.equal(env.monetization:robuxSpent(USER), 99 + 199)
	end)

	t.test("lists catalog states", function()
		local env = setup()
		play(env, COMPANY_A)
		env.owns[USER .. ":" .. IDS.PassVip] = true
		env.monetization:onPlayerJoined(USER)
		expect.equal(env.monetization:processReceipt(receipt("r1", IDS.StarterPack, 79)), "PurchaseGranted")
		local response = shop(env, USER, "Shop.Catalog", {})
		expect.truthy(response.ok)
		local products = response.data.products
		expect.equal(#products, 27)
		local states = {}
		for index, entry in ipairs(products) do
			expect.equal(entry.key, ShopConfig.Products[index].key)
			states[entry.key] = entry.state
		end
		expect.equal(states.TreeFrostcrown, "ComingSoon")
		expect.equal(states.DecorSnowGlobe, "ComingSoon")
		expect.equal(states.PassCashX2, "Buy")
		expect.equal(states.CashPinecone, "Buy")
		expect.equal(states.PassVip, "Owned")
		expect.equal(states.StarterPack, "Owned")
		expect.equal(products[6].grant.cash, 1200)
		expect.equal(response.data.robuxSpent, 199 + 79)
		expect.equal(shop(env, USER, "Shop.Prompt", { productKey = "StarterPack" }).errorCode, "AlreadyOwned")
	end)
end
