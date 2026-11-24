--!strict
-- Day/night sky and night lights (CM2-G12a, docs/plans/CM2-G12a.md). The server owns each
-- save's clock and mirrors it into the `DayNumber`, `DayElapsed` and `DaySyncAt` attributes;
-- this script extrapolates the active save's elapsed time and writes the local Lighting only.
-- Without an active save the sky stays at DefaultClockTime and the night lights stay off.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Config = GameConfig.DayCycle
local player = Players.LocalPlayer :: Player

local dayAmbient = Lighting.OutdoorAmbient
local nightAmbient = Color3.fromRGB(table.unpack(Config.NightOutdoorAmbient))

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

local function changed(a: Color3, b: Color3): boolean
	return a.R ~= b.R or a.G ~= b.G or a.B ~= b.B
end

local function update()
	local elapsed = player:GetAttribute("DayElapsed")
	local syncAt = player:GetAttribute("DaySyncAt")
	local clockTime: number
	local ambient: Color3
	local on: boolean
	if type(elapsed) == "number" and type(syncAt) == "number" then
		local e = DayCycle.extrapolate(elapsed, syncAt, workspace:GetServerTimeNow())
		clockTime = DayCycle.clockTime(e)
		ambient = dayAmbient:Lerp(nightAmbient, DayCycle.nightBlend(e))
		on = DayCycle.lightsOn(e)
	else
		clockTime = Config.DefaultClockTime
		ambient = dayAmbient
		on = false
	end
	if math.abs(Lighting.ClockTime - clockTime) > 0.001 then
		Lighting.ClockTime = clockTime
	end
	if changed(Lighting.OutdoorAmbient, ambient) then
		Lighting.OutdoorAmbient = ambient
	end
	setLights(on)
end

while true do
	update()
	task.wait(Config.ClientUpdateSeconds)
end
