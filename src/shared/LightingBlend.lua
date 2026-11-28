--!strict
-- Day -> Night look blend (CM2-VIBE1, docs/plans/CM2-VIBE1.md). Pure: colours are { r, g, b } 0-255
-- arrays; the client (DayNight.client.lua) turns them into Color3 and writes the Lighting objects.
local GameConfig = require(script.Parent.GameConfig)

local LightingBlend = {}

export type Values = { [string]: { [string]: number | { number } } }

local Config = GameConfig.Lighting

-- Day and Night must name the same targets and keys, or a blend would leave a property behind.
for target, dayValues in pairs(Config.Day) do
	local nightValues = (Config.Night :: any)[target]
	for key in pairs(dayValues :: any) do
		assert(
			nightValues ~= nil and nightValues[key] ~= nil,
			"GameConfig.Lighting Day/Night keys differ: " .. target .. "." .. key
		)
	end
end
for target, nightValues in pairs(Config.Night) do
	local dayValues = (Config.Day :: any)[target]
	for key in pairs(nightValues :: any) do
		assert(
			dayValues ~= nil and dayValues[key] ~= nil,
			"GameConfig.Lighting Day/Night keys differ: " .. target .. "." .. key
		)
	end
end

local function mix(day: number, night: number, blend: number): number
	return day + (night - day) * blend
end

-- Every target and property of the blended look at `blend` (0 = day, 1 = night).
function LightingBlend.values(blend: number): Values
	blend = math.clamp(blend, 0, 1)
	local result: Values = {}
	for target, dayValues in pairs(Config.Day :: any) do
		local nightValues = (Config.Night :: any)[target]
		local out: { [string]: number | { number } } = {}
		for key, dayValue in pairs(dayValues) do
			local nightValue = nightValues[key]
			if type(dayValue) == "table" then
				local color = {}
				for channel = 1, 3 do
					color[channel] = math.floor(mix(dayValue[channel], nightValue[channel], blend) + 0.5)
				end
				out[key] = color
			else
				out[key] = mix(dayValue, nightValue, blend)
			end
		end
		result[target] = out
	end
	return result
end

-- Bloom and SunRays are on at quality 0 (Automatic) and from EffectsMinQualityLevel (as GameConfig.snowRate).
function LightingBlend.effectsOn(qualityLevel: number): boolean
	return qualityLevel < 1 or qualityLevel >= Config.EffectsMinQualityLevel
end

return LightingBlend
