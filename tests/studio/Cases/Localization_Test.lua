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

	-- The spec requires localized keys rather than hardcoded prose in both languages.
	t.test("defines every key in both languages", function()
		for key in pairs(Localization.Strings.en) do
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
		for key in pairs(Localization.Strings.de) do
			expect.equal(type(Localization.Strings.en[key]), "string")
		end
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
end
