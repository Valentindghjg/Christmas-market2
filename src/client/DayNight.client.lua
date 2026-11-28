--!strict
-- Day/night sky and night lights (CM2-G12a, docs/archive/plans/CM2-G12a.md). The server owns each
-- save's clock and mirrors it into the `DayNumber`, `DayElapsed` and `DaySyncAt` attributes;
-- this script extrapolates the active save's elapsed time and writes the local Lighting only
-- (sky clock, look blend through shared/LightingBlend.lua, CM2-VIBE1).
-- Without an active save the sky stays at DefaultClockTime and the night lights stay off.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LightingBlend = require(Shared:WaitForChild("LightingBlend"))

local Config = GameConfig.DayCycle
local LightingConfig = GameConfig.Lighting
local player = Players.LocalPlayer :: Player

-- CM2-VIBE1: `Lighting` and the four CM2* effect children (placed by the project files) are blended
-- Day -> Night; Technology and shadows are static place properties and never written here.
local targets: { [string]: Instance } = { Lighting = Lighting }
for name in pairs(LightingConfig.Classes) do
	local instance = Lighting:WaitForChild(name, 5)
	if instance then
		targets[name] = instance
	else
		warn("DayNight: Lighting." .. name .. " missing")
	end
end

local lastBlend: number? = nil
local lightsOn: boolean? = nil

local function setLight(instance: Instance, on: boolean)
	if instance:IsA("Light") then
		instance.Enabled = on
	end
end

local function setLights(on: boolean)
	if on == lightsOn then
		return
	end
	lightsOn = on
	for _, instance in CollectionService:GetTagged(Config.NightLightTag) do
		setLight(instance, on)
	end
end

CollectionService:GetInstanceAddedSignal(Config.NightLightTag):Connect(function(instance: Instance)
	setLight(instance, lightsOn == true)
end)

local function apply(blend: number)
	for target, properties in pairs(LightingBlend.values(blend)) do
		local instance = targets[target]
		if instance then
			for key, v in pairs(properties) do
				(instance :: any)[key] = if type(v) == "table" then Color3.fromRGB(v[1], v[2], v[3]) else v
			end
		end
	end
end

-- Bloom and SunRays follow the graphics quality (off at 1-3, as the snow).
local gameSettings = UserSettings():GetService("UserGameSettings")
local function applyQuality()
	local on = LightingBlend.effectsOn(gameSettings.SavedQualityLevel.Value)
	for _, name in { "CM2Bloom", "CM2SunRays" } do
		local effect = targets[name]
		if effect then
			(effect :: any).Enabled = on
		end
	end
end
applyQuality()
gameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(applyQuality)

local function update()
	local elapsed = player:GetAttribute("DayElapsed")
	local syncAt = player:GetAttribute("DaySyncAt")
	local clockTime: number
	local blend: number
	local on: boolean
	if type(elapsed) == "number" and type(syncAt) == "number" then
		local e = DayCycle.extrapolate(elapsed, syncAt, workspace:GetServerTimeNow())
		clockTime = DayCycle.clockTime(e)
		blend = DayCycle.nightBlend(e)
		on = DayCycle.lightsOn(e)
	else
		clockTime = Config.DefaultClockTime
		blend = 0
		on = false
	end
	if math.abs(Lighting.ClockTime - clockTime) > 0.001 then
		Lighting.ClockTime = clockTime
	end
	if lastBlend == nil or math.abs(blend - lastBlend) > 0.001 then
		apply(blend)
		lastBlend = blend
	end
	setLights(on)
end

while true do
	update()
	task.wait(Config.ClientUpdateSeconds)
end
