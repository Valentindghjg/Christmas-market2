--!strict
-- CM2-VIBE1: the Day -> Night look blend (shared/LightingBlend.lua) and the GameConfig.Lighting rules.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DayCycle = require(Shared:WaitForChild("DayCycle"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local LightingBlend = require(Shared:WaitForChild("LightingBlend"))
	local expect = t.expect
	local Config = GameConfig.Lighting

	-- Every target and key of `table` against `values`; numbers within `tolerance`, colours per channel.
	local function expectMatches(values, expected, tolerance)
		for target, properties in pairs(expected) do
			for key, want in pairs(properties) do
				local got = values[target][key]
				if type(want) == "table" then
					for channel = 1, 3 do
						expect.equal(got[channel], want[channel])
					end
				else
					expect.truthy(math.abs(got - want) <= tolerance)
				end
			end
		end
	end

	t.test("day values", function()
		expectMatches(LightingBlend.values(0), Config.Day, 0)
	end)

	t.test("night values", function()
		expectMatches(LightingBlend.values(1), Config.Night, 1e-9)
	end)

	t.test("dusk midpoint and clamp", function()
		local dusk = LightingBlend.values(DayCycle.nightBlend(735))
		expect.truthy(math.abs(dusk.CM2ColorCorrection.Saturation - 0.135) < 1e-9)
		expect.equal(dusk.CM2Atmosphere.Color[1], 141)
		expect.equal(dusk.CM2Atmosphere.Color[2], 149)
		expect.equal(dusk.CM2Atmosphere.Color[3], 169)
		expectMatches(LightingBlend.values(-1), Config.Day, 0)
		expectMatches(LightingBlend.values(2), Config.Night, 1e-9)
		expect.equal(DayCycle.nightBlend(480), 0) -- ClockTime 14
		expect.equal(DayCycle.nightBlend(840), 1) -- ClockTime 22
	end)

	t.test("look rules", function()
		local day, night = Config.Day, Config.Night
		expect.truthy(day.CM2ColorCorrection.Saturation > 0)
		expect.truthy(day.CM2ColorCorrection.Contrast > 0)
		local tint = day.CM2ColorCorrection.TintColor
		expect.truthy(tint[1] >= tint[2] and tint[2] >= tint[3])
		expect.truthy(night.CM2ColorCorrection.Saturation < day.CM2ColorCorrection.Saturation)
		expect.truthy(day.CM2Bloom.Intensity <= 0.4)
		expect.truthy(day.CM2Bloom.Threshold >= 1)
		expect.truthy(day.CM2Atmosphere.Density < 0.5)
		expect.truthy(night.CM2Atmosphere.Density < 0.5)
		expect.truthy(night.Lighting.ExposureCompensation >= day.Lighting.ExposureCompensation)
		expect.truthy(Config.Static.Brightness <= 3)
		for _, look in { day, night } do
			for _, key in { "Ambient", "OutdoorAmbient" } do
				for channel = 1, 3 do
					expect.truthy(look.Lighting[key][channel] >= 40)
				end
			end
		end
	end)

	t.test("effects quality gate", function()
		expect.truthy(LightingBlend.effectsOn(0))
		for level = 1, 3 do
			expect.falsy(LightingBlend.effectsOn(level))
		end
		expect.truthy(LightingBlend.effectsOn(4))
		expect.truthy(LightingBlend.effectsOn(10))
	end)
end
