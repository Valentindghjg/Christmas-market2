--!strict
return function(t)
	local Localization =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Localization"))
	local expect = t.expect

	t.test("returns German translations", function()
		expect.equal(Localization.get("de", "cash"), "Geld")
	end)

	t.test("falls back to English then key", function()
		expect.equal(Localization.get("fr", "cash"), "Cash")
		expect.equal(Localization.get("de", "missingKey"), "missingKey")
	end)

	t.test("compact stocking header (CM2-UVF10)", function()
		expect.equal(
			Localization.format("en", "stockingHeaderCompact", "Douglas Fir", 12, 12, 12),
			"Douglas Fir · S 12 · M 12 · L 12"
		)
		expect.equal(
			Localization.format("de", "stockingHeaderCompact", "Douglas Fir", 12, 12, 12),
			"Douglas Fir · K 12 · M 12 · G 12"
		)
	end)

	-- The spec requires localized keys rather than hardcoded prose in both languages.
	t.test("defines every key in both languages", function()
		for key in pairs(Localization.Strings.en) do
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		for key in pairs(Localization.Strings.de) do
			expect.equal(type(Localization.Strings.en[key]), "string")
		end
	end)

	-- CM2-46b: the shop chrome, every product name and every description in both languages.
	t.test("has every shop key in English and German", function()
		local ShopConfig =
			require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ShopConfig"))
		local keys = {
			"shopButton",
			"shopTitle",
			"shopPrice",
			"shopBuy",
			"shopOwned",
			"shopComingSoon",
			"shopBoostActive",
			"shopLoading",
			"shopClose",
			"shopPromptOpen",
			"shopErrorComingSoon",
			"shopErrorOwned",
			"shopErrorNoSave",
			"shopErrorBoostFull",
			"shopErrorBusy",
			"shopErrorUnavailable",
			"shopDescStarterPack",
			"shopDescPassCashX2",
			"shopDescPassReputationX2",
			"shopDescPassInstantDelivery",
			"shopDescPassVip",
			"shopDescCash",
			"shopDescBoostCashX2",
			"shopDescBoostRested",
			"shopDescSpecialTree",
			"shopDescEventTree",
			"shopDescEventDecorPack",
			"shopDescPremiumDecor",
		}
		for _, id in ipairs(ShopConfig.Categories) do
			table.insert(keys, "shopCategory" .. id)
		end
		for _, product in ipairs(ShopConfig.Products) do
			local nameKey, descKey = ShopConfig.textKeys(product)
			table.insert(keys, nameKey)
			table.insert(keys, descKey)
		end
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
	end)

	-- CM2-UVF8: cash packs read "Adds $1,200 ..." in both languages.
	t.test("formats the cash pack description with a dollar sign", function()
		local expected = "Adds $1,200 to the save you are playing."
		expect.equal(Localization.format("en", "shopDescCash", "1,200"), expected)
		expect.equal(Localization.format("de", "shopDescCash", "1,200"), expected)
	end)

	t.test("formats templates and tolerates bad arguments", function()
		expect.equal(Localization.format("de", "orderAccepted", 32), "Bestellung angenommen: 32 $")
		expect.equal(Localization.format("en", "orderAccepted", "not a number"), "Order accepted: $%d")
	end)

	-- CM2-S1/R3: every save error code has a player-facing text in both languages.
	t.test("has an English text for every save error code", function()
		for code, key in pairs(Localization.SaveErrorKeys) do
			expect.equal(type(code), "string")
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
			expect.equal(Localization.saveErrorKey(code), key)
		end
		expect.equal(type(Localization.Strings.en.saveErrorUnknown), "string")
		expect.equal(type(Localization.Strings.de.saveErrorUnknown), "string")
		expect.equal(Localization.saveErrorKey("NoSuchCode"), "saveErrorUnknown")
		expect.equal(Localization.saveErrorKey(nil), "saveErrorUnknown")
	end)

	-- CM2-S1 fix round 1: a reason suffix after ":" stays in CompanyError for diagnostics.
	t.test("maps error codes with a reason suffix", function()
		expect.equal(Localization.saveErrorKey("LoadFailed:Throttled"), "saveErrorLoadFailed")
		expect.equal(Localization.saveErrorKey("SaveFailed:x"), "saveErrorSaveFailed")
		expect.equal(Localization.saveErrorKey("ServerShuttingDown"), "saveErrorLoadFailed")
		expect.equal(Localization.saveErrorKey("Nope"), "saveErrorUnknown")
		expect.equal(Localization.saveErrorKey(nil), "saveErrorUnknown")
	end)

	-- CM2-S2: the co-op error and UI keys of plan step 10.
	t.test("has every co-op UI key in English and German", function()
		local keys = {
			"saveErrorOwnerOnly",
			"saveErrorNotMember",
			"saveErrorRemoved",
			"saveErrorInviteInvalid",
			"saveErrorSaveFull",
			"saveErrorJoinLocked",
			"saveErrorOwnerCannotLeave",
			"saveErrorCannotRemoveOwner",
			"saveErrorNotActive",
			"saveErrorSizeTooSmall",
			"saveErrorSoloNoCode",
			"saveErrorCodeUnavailable",
			"saveErrorInUse",
			"saveSizeSolo",
			"saveSizeDuo",
			"saveSizeTrio",
			"saveSizeQuad",
			"saveRowSolo",
			"saveRowCoopOwner",
			"saveRowCoopMember",
			"sharedSaveName",
			"sharedSaveNameUnknown",
			"saveLeave",
			"joinCodePlaceholder",
			"joinButton",
			"teamButton",
			"teamTitle",
			"teamSeats",
			"teamCode",
			"teamCodeHint",
			"teamNoCode",
			"teamCodePending",
			"teamNewCode",
			"teamRemove",
			"teamRemoveConfirm",
			"teamLeave",
			"teamLeaveConfirm",
			"teamOwnerTag",
			"teamMemberTag",
			"teamOnline",
			"teamOffline",
			"teamUnknownPlayer",
			"teamClose",
			"hudSharedSaveStatus",
			"hudSharedSaveStatusUnknown",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(Localization.saveErrorKey("InvalidInviteCode"), "saveErrorInviteInvalid")
		expect.equal(Localization.saveErrorKey("RemovedFromSave"), "saveErrorRemoved")
		expect.equal(Localization.saveErrorKey("InvalidSize"), "saveErrorUnknown")
		expect.equal(Localization.saveErrorKey("InvalidUserId"), "saveErrorUnknown")
		expect.equal(Localization.format("en", "sharedSaveName", "Kim"), "Shared lot from Kim")
		expect.equal(Localization.format("en", "teamSeats", 2, 4), "2 of 4 seats are taken.")
	end)

	t.test("has every cross-server and finder key in English and German", function()
		local errorKeys = {
			SaveInUseElsewhere = "saveErrorElsewhere",
			ServerFull = "saveErrorServerFull",
			SaveServerGone = "saveErrorServerGone",
			TeleportFailed = "saveErrorTeleportFailed",
			TeleportUnavailable = "saveErrorTeleportUnavailable",
			SaveNotElsewhere = "saveErrorNotElsewhere",
			ListingGone = "saveErrorListingGone",
			OwnListing = "saveErrorOwnListing",
		}
		for code, key in pairs(errorKeys) do
			expect.equal(Localization.saveErrorKey(code), key)
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		local keys = {
			"saveRowElsewhere",
			"saveRowElsewhereUnknown",
			"saveJoinServer",
			"teleportJoining",
			"finderButton",
			"finderOpen",
			"finderTitle",
			"finderHint",
			"finderEmpty",
			"finderSeats",
			"finderJoin",
			"finderStart",
			"finderStartHint",
			"finderOwnListing",
			"finderStop",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(Localization.saveErrorKey("ServerFull:3"), "saveErrorServerFull")
		expect.equal(Localization.saveErrorKey("InvalidTeleportTarget"), "saveErrorUnknown")
		expect.equal(Localization.format("en", "saveRowElsewhere", "Kim"), "Being played by Kim")
		expect.equal(Localization.format("en", "finderSeats", 1, 3), "1 of 3 seats are taken.")
	end)

	-- CM2-40: the HUD and Lot Manager keys exist in both languages, and the tab list is complete.
	t.test("has every HUD and Lot Manager key in English and German", function()
		local UiTheme = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UiTheme"))
		local keys = {
			"tabSupplier",
			"lotManagerButton",
			"lotManagerTitle",
			"lotManagerClose",
			"lotManagerTabSoon",
			"lotManagerTabError",
			"hudCash",
			"hudReputation",
			"hudDay",
			"hudDayUnknown",
			"hudLotOpen",
			"hudLotPaused",
			"hudLotClosed",
			"orderAcceptedTruck",
			"finderStartHint",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		for _, tab in ipairs(UiTheme.LotManagerTabs) do
			expect.equal(type(Localization.Strings.en[tab.labelKey]), "string")
			expect.equal(type(Localization.Strings.de[tab.labelKey]), "string")
		end
		local ids = {}
		for _, tab in ipairs(UiTheme.LotManagerTabs) do
			table.insert(ids, tab.id)
		end
		expect.equal(table.concat(ids, ","), "Supplier,Catalog,Pricing,Employees,Land,Analytics")
		expect.equal(Localization.format("en", "hudCash", "1,615"), "$1,615")
	end)

	t.test("formats the supplier species row", function()
		expect.equal(
			Localization.format("en", "supplierSpeciesRow", "Douglas Fir", 21, 28, 41),
			"Douglas Fir\n$21 / $28 / $41"
		)
		expect.equal(
			Localization.format("de", "supplierSpeciesRow", "Douglas Fir", 21, 28, 41),
			"Douglas Fir\n21 $ / 28 $ / 41 $"
		)
	end)

	-- CM2-G14: every stocking error code has a sentence in both languages.
	t.test("has a sentence for every stocking error", function()
		local Stocking = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Stocking"))
		local codes = 0
		for code, key in pairs(Stocking.ErrorKeys) do
			codes += 1
			expect.equal(type(code), "string")
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(codes, 13)
		expect.equal(
			Localization.format("en", "stockingHeader", "Douglas Fir", 1, 2, 3),
			"Douglas Fir · 1 Small · 2 Medium · 3 Large"
		)
		expect.equal(Localization.format("en", "bayArriving", "0:25"), "Delivery arriving 0:25")
	end)

	-- CM2-G7: the Pricing tab keys.
	t.test("has every pricing key in English and German", function()
		local keys = {
			"pricingRule",
			"pricingAutoOn",
			"pricingAutoOff",
			"pricingAutoHint",
			"pricingWholesaleTypical",
			"pricingMargin",
			"pricingSizes",
			"pricingPrice",
			"pricingStep",
			"pricingSaved",
			"pricingErrorInvalid",
			"pricingSentimentBargain",
			"pricingSentimentFair",
			"pricingSentimentPricey",
			"pricingSentimentTooHigh",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(Localization.format("en", "pricingStep", -5), "-5")
		expect.equal(Localization.format("en", "pricingStep", 5), "+5")
	end)

	-- CM2-25/26 part b: the Employees tab and the break-area mode.
	t.test("has every staff and break-area key in English and German", function()
		local keys = {
			"staffHiredCount",
			"staffCashier",
			"staffLotWorker",
			"staffLotManager",
			"staffCashierRole",
			"staffLotWorkerRole",
			"staffLotManagerRole",
			"staffCost",
			"staffHire",
			"staffHireConfirm",
			"staffHired",
			"staffLocked",
			"staffLockedShort",
			"staffCapacityFull",
			"staffStatus",
			"staffWorking",
			"staffOnTheWay",
			"staffResting",
			"staffArriving",
			"staffNoCashier",
			"staffNoWages",
			"breakAreaTitle",
			"breakAreaMove",
			"breakAreaHint",
			"breakAreaRotate",
			"breakAreaPlace",
			"breakAreaCancel",
			"breakAreaMoved",
			"breakAreaTrees",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(Localization.format("en", "staffHiredCount", 0, 2), "0 / 2 hired")
		expect.equal(Localization.format("en", "staffCost", "1,200"), "One-time cost: $1,200")
		expect.equal(Localization.format("en", "staffHireConfirm", "1,200"), "Confirm $1,200")
		expect.equal(Localization.format("en", "staffStatus", 85, "Working"), "Energy 85% · Working")
		expect.equal(Localization.format("de", "staffStatus", 85, "Arbeitet"), "Energie 85% · Arbeitet")
	end)

	-- CM2-46a: the Robux shop notices.
	t.test("has the shop notice keys in English and German", function()
		for _, key in ipairs({ "shopThanks", "shopPassActive" }) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		expect.equal(Localization.get("en", "shopPassActive"), "Thanks! Your game pass is now active.")
		expect.equal(Localization.get("de", "shopPassActive"), "Danke! Dein Spielpass ist jetzt aktiv.")
	end)

	-- CM2-49: the guided tutorial's hints and Skip button.
	t.test("has every tutorial key in English and German", function()
		local keys = {
			"tutorialOrder",
			"tutorialDelivery",
			"tutorialStock",
			"tutorialPlace",
			"tutorialCheckoutWait",
			"tutorialCheckout",
			"tutorialDone",
			"tutorialSkip",
			"tutorialSkipConfirm",
			"tutorialSkipFailed",
			"tutorialArrow",
		}
		for _, key in ipairs(keys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
	end)
end
