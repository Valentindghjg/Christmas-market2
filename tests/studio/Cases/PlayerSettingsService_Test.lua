--!strict
-- CM2-MUSIC: the Settings.SetMusicVolume action and the MusicVolume attribute with the real
-- SaveSlotService over a fake profile store and a mutable clock. No test touches a real
-- DataStore; no test plays a save.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local CompanyStateService = require(Services:WaitForChild("CompanyStateService"))
	local PersistenceService = require(Services:WaitForChild("PersistenceService"))
	local PlayerSettingsService = require(Services:WaitForChild("PlayerSettingsService"))
	local PlotService = require(Services:WaitForChild("PlotService"))
	local SaveSlotService = require(Services:WaitForChild("SaveSlotService"))
	local expect = t.expect

	local USER = 42
	local OTHER = 43
	local START = 1796299200 -- 2026-12-03 12:00 UTC
	local NAN = 0 / 0

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
		local store: any = { records = {}, writes = 0 }
		function store.UpdateAsync(_, key: string, transform)
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

	local function newSaveSlots(env, profileStore)
		local function clock(): number
			return env.now
		end
		local persistence = PersistenceService.new(fakeStore(), "job-a", clock, noWait)
		local companies = CompanyStateService.new(persistence, clock, nil, noWait)
		local counter = 0
		return SaveSlotService.new({
			profileStore = profileStore,
			persistence = persistence,
			companies = companies,
			plots = PlotService.new({ "Plot_01", "Plot_02" }),
			clock = clock,
			wait = noWait,
			newSaveId = function(userId: number): string
				counter += 1
				return string.format("%d_%016x", userId, counter)
			end,
			filterName = function(_, text: string)
				return true, text
			end,
			teleport = function()
				return true
			end,
		})
	end

	-- open = true opens USER's profile (no play).
	local function setup(open: boolean)
		local env: any = { now = START, attributes = {} }
		env.store = fakeStore()
		env.saveSlots = newSaveSlots(env, env.store)
		env.settings = PlayerSettingsService.new({
			saveSlots = env.saveSlots,
			clock = function(): number
				return env.now
			end,
			setAttribute = function(userId: number, name: string, value: any)
				env.attributes[userId] = env.attributes[userId] or {}
				env.attributes[userId][name] = value
			end,
		})
		if open then
			expect.truthy(env.saveSlots:openProfile(USER))
		end
		return env
	end

	local requestNumber = 0
	local function setRequest(payload: any)
		requestNumber += 1
		return {
			version = 1,
			requestId = string.format("music_req_%06d", requestNumber),
			action = "Settings.SetMusicVolume",
			payload = payload,
		}
	end

	local function setVolume(env, value: any, userId: number?)
		return env.settings:handle(userId or USER, setRequest({ volume = value }))
	end

	local function stored(env, userId: number?)
		return env.store.records[SaveSlotService.profileKey(userId or USER)]
	end

	local function attribute(env, userId: number?)
		local attributes = env.attributes[userId or USER]
		return if attributes then attributes.MusicVolume else nil
	end

	t.test("defaults on join", function()
		local env = setup(true)
		env.settings:onPlayerJoined(USER)
		expect.equal(attribute(env), 0.5)
		expect.truthy(stored(env))
		expect.equal(stored(env).musicVolume, nil)
	end)

	t.test("migrates an old profile", function()
		local env = setup(false)
		local old = SaveProfile.new(USER, START)
		old.legacyState = "None"
		expect.equal(old.musicVolume, nil)
		env.store.records[SaveSlotService.profileKey(USER)] = deepCopy(old)
		expect.truthy(env.saveSlots:openProfile(USER))
		env.settings:onPlayerJoined(USER)
		expect.equal(attribute(env), 0.5)
		local open, volume = env.saveSlots:musicVolumeOf(USER)
		expect.truthy(open)
		expect.equal(volume, 0.5)
		local response = setVolume(env, 0.3)
		expect.truthy(response.ok)
		expect.equal(response.data.musicVolume, 0.3)
		expect.equal(stored(env).musicVolume, 0.3)
		expect.equal(stored(env).profileVersion, 1)
	end)

	t.test("clamps and rounds", function()
		local env = setup(true)
		for _, case in { { 1.7, 1 }, { -0.2, 0 }, { 0.333, 0.33 } } do
			local response = setVolume(env, case[1])
			expect.truthy(response.ok)
			expect.equal(response.revision, nil)
			expect.equal(response.data.musicVolume, case[2])
			expect.equal(stored(env).musicVolume, case[2])
			expect.equal(attribute(env), case[2])
		end
	end)

	t.test("rejects wrong types without a write", function()
		local env = setup(true)
		local writes = env.store.writes
		for _, bad in { "loud", NAN, math.huge } :: { any } do
			local response = setVolume(env, bad)
			expect.falsy(response.ok)
			expect.equal(response.errorCode, "InvalidVolume")
		end
		local extra = env.settings:handle(USER, setRequest({ volume = 0.5, x = 1 }))
		expect.falsy(extra.ok)
		expect.equal(extra.errorCode, "UnexpectedField")
		expect.equal(env.store.writes, writes)
		expect.equal(attribute(env), nil)
	end)

	t.test("rate limits", function()
		local env = setup(true)
		expect.truthy(env.saveSlots:openProfile(OTHER))
		for index = 1, 6 do
			local response = setVolume(env, index / 10)
			expect.truthy(response.ok)
		end
		local limited = setVolume(env, 0.9)
		expect.falsy(limited.ok)
		expect.equal(limited.errorCode, "RateLimited")
		expect.truthy(setVolume(env, 0.9, OTHER).ok)
		env.now += 31
		expect.truthy(setVolume(env, 0.9).ok)
		expect.equal(stored(env).musicVolume, 0.9)
	end)

	t.test("round trip", function()
		local env = setup(true)
		expect.truthy(setVolume(env, 0.2).ok)
		env.saveSlots:closeProfile(USER)
		expect.truthy(env.saveSlots:openProfile(USER))
		local open, volume = env.saveSlots:musicVolumeOf(USER)
		expect.truthy(open)
		expect.equal(volume, 0.2)
		local second = newSaveSlots(env, env.store)
		expect.truthy(second:openProfile(USER))
		local secondOpen, secondVolume = second:musicVolumeOf(USER)
		expect.truthy(secondOpen)
		expect.equal(secondVolume, 0.2)
		local writes = env.store.writes
		local again = setVolume(env, 0.2)
		expect.truthy(again.ok)
		expect.equal(again.data.musicVolume, 0.2)
		expect.equal(env.store.writes, writes)
	end)

	t.test("needs an open profile", function()
		local env = setup(false)
		local response = setVolume(env, 0.4)
		expect.falsy(response.ok)
		expect.equal(response.errorCode, "ProfileUnavailable")
		expect.equal(env.store.writes, 0)
		expect.equal(stored(env), nil)
		local open, volume = env.saveSlots:musicVolumeOf(USER)
		expect.falsy(open)
		expect.equal(volume, 0.5)
		env.settings:onPlayerJoined(USER)
		expect.equal(attribute(env), nil)
	end)
end
