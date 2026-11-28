--!strict
-- Falling snow around the camera (CM2-V2-SNOW). One invisible emitter part sits over the local
-- camera (client only, never replicated); GameConfig.snowRate gates it by graphics quality.
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Config = GameConfig.Snow
if not Config.Enabled then
	return
end

local gameSettings = UserSettings():GetService("UserGameSettings")

local emitterPart = Instance.new("Part")
emitterPart.Name = "SnowEmitter"
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.CanTouch = false
emitterPart.Transparency = 1
emitterPart.Size = Vector3.new(Config.AreaSize, 1, Config.AreaSize)

local emitter = Instance.new("ParticleEmitter")
emitter.Name = "Snow"
emitter.Texture = Config.Texture
emitter.EmissionDirection = Enum.NormalId.Bottom
emitter.Color = ColorSequence.new(BrickColor.White().Color)
emitter.LightEmission = 0
emitter.LockedToPart = false
emitter.SpreadAngle = Vector2.new(10, 10)
emitter.Lifetime = NumberRange.new(Config.LifetimeMin, Config.LifetimeMax)
emitter.Speed = NumberRange.new(Config.SpeedMin, Config.SpeedMax)
emitter.Size = NumberSequence.new(Config.Size)
emitter.Transparency = NumberSequence.new(Config.Transparency)
emitter.Acceleration = Vector3.zero
emitter.Rotation = NumberRange.new(0, 360)
emitter.Parent = emitterPart

local function applyRate()
	emitter.Rate = GameConfig.snowRate(gameSettings.SavedQualityLevel.Value)
end
applyRate()
gameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(applyRate)

local function attachToCamera()
	local camera = workspace.CurrentCamera
	if camera then
		emitterPart.Parent = camera
	end
end
attachToCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachToCamera)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if camera then
		emitterPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, Config.HeightAbove, 0))
	end
end)
