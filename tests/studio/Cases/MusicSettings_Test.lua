--!strict
-- CM2-MUSIC: the pure music volume rules (normalize, validate, step, default, percent).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local MusicSettings = require(Shared:WaitForChild("MusicSettings"))
	local expect = t.expect
	local NAN = 0 / 0

	t.test("normalizes", function()
		expect.equal(MusicSettings.normalize(0.333), 0.33)
		expect.equal(MusicSettings.normalize(1.7), 1)
		expect.equal(MusicSettings.normalize(-0.2), 0)
		for _, bad in { "0.5", NAN, math.huge, -math.huge } :: { any } do
			local value, code = MusicSettings.normalize(bad)
			expect.equal(value, nil)
			expect.equal(code, "InvalidVolume")
		end
		local value, code = MusicSettings.normalize(nil)
		expect.equal(value, nil)
		expect.equal(code, "InvalidVolume")
	end)

	t.test("validates", function()
		expect.truthy(MusicSettings.isValid(nil))
		for _, good in { 0, 0.5, 1 } do
			expect.truthy(MusicSettings.isValid(good))
		end
		for _, bad in { -0.01, 1.01, NAN, math.huge, "x", {} } :: { any } do
			expect.falsy(MusicSettings.isValid(bad))
		end
	end)

	t.test("steps", function()
		expect.equal(MusicSettings.step(0.5, 1), 0.6)
		expect.equal(MusicSettings.step(0.5, -1), 0.4)
		expect.equal(MusicSettings.step(0.4, -1), 0.3)
		expect.equal(MusicSettings.step(0, -1), 0)
		expect.equal(MusicSettings.step(1, 1), 1)
	end)

	t.test("reads default", function()
		expect.equal(MusicSettings.volumeOf({}), 0.5)
		expect.equal(MusicSettings.volumeOf({ musicVolume = 0 }), 0)
		expect.equal(MusicSettings.percent(0.3), 30)
		expect.equal(MusicSettings.soundId(140169923347660), "rbxassetid://140169923347660")
	end)
end
