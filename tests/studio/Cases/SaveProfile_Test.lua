--!strict
-- CM2-S1: the pure player-profile schema (names, save IDs, cap, list order).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local expect = t.expect
	local MAX_USER_ID = 9223372036854774784 -- 2^63 - 1024, the largest Luau number below int64 max

	local function saveId(number: number): string
		return string.format("42_%016x", number)
	end

	local function entry(number: number, name: string?)
		return {
			saveId = saveId(number),
			name = name or ("Lot " .. number),
			role = "Owner",
			size = "Solo",
			createdAt = number,
			lastPlayedAt = 0,
		}
	end

	local function profileWith(count: number)
		local profile = SaveProfile.new(42, 100)
		profile.legacyState = "None"
		for number = 1, count do
			table.insert(profile.saves, entry(number))
		end
		profile.nextSaveNumber = count + 1
		return profile
	end

	t.test("normalizes and validates save names", function()
		expect.equal(SaveProfile.normalizeName("  My   Lot "), "My Lot")
		for _, bad in { "", "   ", string.rep("a", 25), "A#B", "a\nb", "\255" } do
			local name, reason = SaveProfile.normalizeName(bad)
			expect.equal(name, nil)
			expect.equal(reason, "NameInvalid")
		end
		expect.equal(SaveProfile.normalizeName(string.rep("a", 24)), string.rep("a", 24))
		expect.equal(SaveProfile.normalizeName("Grüne Tanne"), "Grüne Tanne")
		expect.equal(SaveProfile.normalizeName(42), nil)
	end)

	t.test("matches typed confirmation case-insensitively", function()
		expect.truthy(SaveProfile.confirmMatches("Tree Lot 1", " tree  lot 1 "))
		expect.falsy(SaveProfile.confirmMatches("Tree Lot 1", "Tree Lot"))
		expect.falsy(SaveProfile.confirmMatches("Tree Lot 1", nil))
	end)

	t.test("recognizes save IDs", function()
		expect.truthy(SaveProfile.isSaveId("42_" .. string.rep("ab", 8)))
		expect.falsy(SaveProfile.isSaveId("42_" .. string.rep("AB", 8)))
		expect.falsy(SaveProfile.isSaveId("42" .. string.rep("ab", 8)))
		expect.falsy(SaveProfile.isSaveId("42_" .. string.rep("a", 15)))
		expect.falsy(SaveProfile.isSaveId("42_" .. string.rep("ab", 16))) -- old 32-hex format
		expect.falsy(SaveProfile.isSaveId(string.rep("1", 20) .. "_" .. string.rep("ab", 8)))
		expect.falsy(SaveProfile.isSaveId(42))
	end)

	-- CM2-S1 Fix round 2: every save key fits the 50-char DataStore key limit.
	t.test("builds short save IDs for a 19-digit user ID", function()
		local id = SaveProfile.newSaveId(MAX_USER_ID, "0F8FAD5B-D9CB-469F-A165-70867728950E")
		expect.equal(id, "9223372036854774784_a16570867728950e")
		expect.equal(#id, 36)
		expect.truthy(SaveProfile.isSaveId(id))
		expect.equal(SaveProfile.userIdText(MAX_USER_ID), "9223372036854774784")
		expect.truthy(#("company:save:" .. id) <= SaveProfile.KEY_MAX_LENGTH)
	end)

	t.test("enforces the save cap and unique names", function()
		local cap = GameConfig.Saves.MaxSavesPerPlayer
		local full = profileWith(cap)
		expect.truthy(SaveProfile.validate(full))
		table.insert(full.saves, entry(cap + 1))
		expect.falsy(SaveProfile.validate(full))
		local profile = profileWith(2)
		expect.truthy(SaveProfile.nameTaken(profile, "lot 1"))
		expect.truthy(SaveProfile.nameTaken(profile, "LOT 2"))
		expect.falsy(SaveProfile.nameTaken(profile, "lot 1", saveId(1)))
		expect.falsy(SaveProfile.nameTaken(profile, "Lot 3"))
	end)

	t.test("lists saves by last played, then newest", function()
		local profile = profileWith(3)
		profile.saves[1].lastPlayedAt = 500
		profile.saves[2].lastPlayedAt = 0
		profile.saves[3].lastPlayedAt = 0
		profile.lastSaveId = saveId(1)
		local view = SaveProfile.listView(profile, saveId(3))
		expect.equal(#view, 3)
		expect.equal(view[1].saveId, saveId(1))
		expect.equal(view[2].saveId, saveId(3))
		expect.equal(view[3].saveId, saveId(2))
		expect.truthy(view[1].lastPlayed)
		expect.falsy(view[1].active)
		expect.truthy(view[2].active)
		expect.falsy(view[2].lastPlayed)
		expect.falsy(view[3].active)
		expect.equal(view[1].name, "Lot 1")
		local found, index = SaveProfile.find(profile, saveId(2))
		expect.equal(found and found.name, "Lot 2")
		expect.equal(index, 2)
	end)

	t.test("validates profile shape", function()
		expect.truthy(SaveProfile.validate(SaveProfile.new(42, 100)))
		local badRole = profileWith(1)
		badRole.saves[1].role = "Boss"
		expect.falsy(SaveProfile.validate(badRole))
		local badSize = profileWith(1)
		badSize.saves[1].size = "Huge"
		expect.falsy(SaveProfile.validate(badSize))
		local member = profileWith(1)
		member.saves[1].role = "Member"
		member.saves[1].size = "Quad"
		expect.truthy(SaveProfile.validate(member))
		local duplicate = profileWith(2)
		duplicate.saves[2].saveId = duplicate.saves[1].saveId
		expect.falsy(SaveProfile.validate(duplicate))
		local tooMany = profileWith(GameConfig.Saves.MaxSavesPerPlayer + 1)
		expect.falsy(SaveProfile.validate(tooMany))
	end)

	-- CM2-S2: co-op saves read the owner from the save ID; shared entries never block names.
	t.test("reads the owner from a save ID and ignores shared names", function()
		expect.equal(SaveProfile.ownerUserIdOf(saveId(1)), 42)
		local bigId = SaveProfile.newSaveId(MAX_USER_ID, "0F8FAD5B-D9CB-469F-A165-70867728950E")
		expect.equal(SaveProfile.ownerUserIdOf(bigId), MAX_USER_ID)
		expect.equal(SaveProfile.ownerUserIdOf(nil), nil)
		for _, bad in { "nope", "42_" .. string.rep("AB", 8), 42, "_" .. string.rep("ab", 8) } do
			expect.equal(SaveProfile.ownerUserIdOf(bad), nil)
		end
		local profile = profileWith(1)
		table.insert(profile.saves, {
			saveId = string.format("43_%016x", 9),
			name = GameConfig.Saves.SharedEntryName,
			role = "Member",
			size = "Duo",
			createdAt = 5,
			lastPlayedAt = 0,
		})
		expect.truthy(SaveProfile.validate(profile))
		expect.falsy(SaveProfile.nameTaken(profile, "Shared lot"))
		expect.falsy(SaveProfile.nameTaken(profile, "shared LOT"))
		table.insert(profile.saves, entry(2, "Shared lot"))
		expect.truthy(SaveProfile.validate(profile))
		expect.truthy(SaveProfile.nameTaken(profile, "shared lot"))
	end)

	-- CM2-49: the profile remembers that the player was offered the guided tutorial.
	t.test("validates the tutorialOffered flag", function()
		local profile = profileWith(1)
		expect.equal(SaveProfile.new(42, 100).tutorialOffered, false)
		for _, valid in { true, false } do
			profile.tutorialOffered = valid
			expect.truthy(SaveProfile.validate(profile))
		end
		profile.tutorialOffered = nil
		expect.truthy(SaveProfile.validate(profile))
		for _, bad in { "yes", 1 } do
			profile.tutorialOffered = bad :: any
			expect.falsy(SaveProfile.validate(profile))
		end
	end)

	-- CM2-PP: a save entry may remember the last plot it was played on.
	t.test("accepts an optional lastPlotId string", function()
		local profile = profileWith(1)
		for _, valid in { "Plot_03" } do
			profile.saves[1].lastPlotId = valid
			expect.truthy(SaveProfile.validate(profile))
		end
		profile.saves[1].lastPlotId = nil
		expect.truthy(SaveProfile.validate(profile))
		for _, bad in { 5, "", string.rep("p", 33) } do
			profile.saves[1].lastPlotId = bad :: any
			expect.falsy(SaveProfile.validate(profile))
		end
	end)
end
