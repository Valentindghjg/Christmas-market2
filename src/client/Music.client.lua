--!strict
-- Background music and the Music panel (CM2-MUSIC, docs/plans/CM2-MUSIC.md, docs/AUDIO.md).
-- Plays GameConfig.Music.TrackIds in a loop through the SoundGroup "Music" under SoundService;
-- the group's volume is the player's saved music volume (attribute MusicVolume, set by the
-- server). The panel only sends Settings.SetMusicVolume {volume}; the server validates, clamps,
-- stores and answers with the stored value. Only the local volume is optimistic.
-- An empty TrackIds list means no music and a hidden Music button.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local MusicSettings = require(Shared:WaitForChild("MusicSettings"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local businessAction = remotes:WaitForChild("BusinessAction") :: RemoteFunction

local Config = GameConfig.Music
local TRACK_IDS = Config.TrackIds
local MODAL_ID = "Music"
local ACTION = "Settings.SetMusicVolume"
local BUTTON_HEIGHT = UiTheme.MinTouch
local CLOSE_WIDTH = 120
local POLL_SECONDS = 0.5
local INSET = UiTheme.ClipInset -- room for strokes and hover growth inside Controls

local localized = UiKit.localized
local localizedFormat = UiKit.localizedFormat
local textLabel = UiKit.label
local textButton = UiKit.button

local PANEL = UiKit.Colors.Panel
local SAND = UiKit.Colors.Sand
local RED = UiKit.Colors.Red

local BUSY_CODES: { [string]: boolean } = {
	RateLimited = true,
	SettingBusy = true,
}

-- Playback objects ---------------------------------------------------------------------------

local group = Instance.new("SoundGroup")
group.Name = "Music"
group.Volume = 0
group.Parent = SoundService

local sounds: { Sound } = {}
for index, id in ipairs(TRACK_IDS) do
	local sound = Instance.new("Sound")
	sound.Name = "Track_" .. index
	sound.SoundId = MusicSettings.soundId(id)
	sound.Volume = 0
	sound.Looped = false
	sound.SoundGroup = group
	sound.Parent = group
	table.insert(sounds, sound)
end

local function tween(target: Instance, seconds: number, goal: { [string]: any }): Tween
	local created = TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Sine), goal)
	created:Play()
	return created
end

-- Panel layout -------------------------------------------------------------------------------

local gui = UiKit.screenGui("MusicUI", 15)
local railButton = UiKit.addRailButton("MusicButton", "musicButton", 80)

local panel = Instance.new("Frame")
panel.Name = "MusicPanel"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Active = true
panel.Visible = false
panel.Parent = gui
UiKit.window(panel)
UiKit.padding(panel, 12)

local title = textLabel(panel, "Title", localized("musicTitle"), 22)
UiKit.headerBand(title)
title.Size = UDim2.new(1, 0, 0, 30)

local controls = Instance.new("Frame")
controls.Name = "Controls"
controls.BackgroundTransparency = 1
controls.BorderSizePixel = 0
controls.Parent = panel

local valueLabel = textLabel(controls, "Value", "", UiTheme.TextSize.Body)
valueLabel.Position = UDim2.fromOffset(INSET, INSET)
valueLabel.Size = UDim2.new(1, -2 * INSET, 0, 30)

local downButton = textButton(controls, "Down", localized("musicDown"), SAND)
downButton.Position = UDim2.fromOffset(INSET, INSET + 36)
downButton.Size = UDim2.fromOffset(48, BUTTON_HEIGHT)

local upButton = textButton(controls, "Up", localized("musicUp"), SAND)
upButton.Position = UDim2.fromOffset(INSET + 54, INSET + 36)
upButton.Size = UDim2.fromOffset(48, BUTTON_HEIGHT)

local muteButton = textButton(controls, "Mute", localized("musicMute"), SAND)
muteButton.Position = UDim2.fromOffset(INSET + 108, INSET + 36)
muteButton.Size = UDim2.new(1, -(2 * INSET + 108), 0, BUTTON_HEIGHT)

local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.BorderSizePixel = 0
footer.Parent = panel

local status = textLabel(footer, "Status", "", UiTheme.TextSize.Small)
status.Size = UDim2.new(1, -(CLOSE_WIDTH + 8), 1, 0)
status.TextWrapped = true

local closeButton = textButton(footer, "CloseButton", localized("musicClose"), RED)
closeButton.AnchorPoint = Vector2.new(1, 1)
closeButton.Position = UDim2.fromScale(1, 1)
closeButton.Size = UDim2.fromOffset(CLOSE_WIDTH, BUTTON_HEIGHT)

UiKit.bindDialog(gui, { frame = panel, list = controls, footer = footer, rightHeader = title }, UiTheme.Dialogs.Music)

-- Volume state -------------------------------------------------------------------------------

local volume = MusicSettings.DEFAULT -- shown and heard
local confirmed = MusicSettings.DEFAULT -- last server value
local lastAudible = MusicSettings.DEFAULT -- last non-zero value, for Unmute
local inFlight = false
local token = 0

local function render()
	if volume <= 0 then
		valueLabel.Text = localized("musicMuted")
		muteButton.Text = localized("musicUnmute")
	else
		valueLabel.Text = localizedFormat("musicVolume", MusicSettings.percent(volume))
		muteButton.Text = localized("musicMute")
	end
	UiKit.setEnabled(downButton, volume > 0, SAND)
	UiKit.setEnabled(upButton, volume < 1, SAND)
end

local function setVolume(value: number)
	volume = value
	tween(group, Config.GroupTweenSeconds, { Volume = value })
	render()
	if value > 0 then
		lastAudible = value
	end
end

local flush: () -> ()

local function schedule()
	token += 1
	local mine = token
	task.delay(Config.SendDebounceSeconds, function()
		if token == mine then
			flush()
		end
	end)
end

flush = function()
	if inFlight or volume == confirmed then
		return
	end
	inFlight = true
	local sent = volume
	local response = UiKit.request(businessAction, ACTION, { volume = sent })
	inFlight = false
	local data = response.data
	local stored = if type(data) == "table" then data.musicVolume else nil
	if response.ok == true and type(stored) == "number" and MusicSettings.isValid(stored) then
		confirmed = stored
		status.Text = ""
		if volume ~= confirmed then
			schedule()
		end
		return
	end
	local code = response.errorCode
	status.Text =
		localized(if type(code) == "string" and BUSY_CODES[code] then "shopErrorBusy" else "rewardErrorFailed")
	if volume == sent then
		setVolume(confirmed)
	end
end

local function change(value: number)
	if value == volume then
		return
	end
	setVolume(value)
	schedule()
end

local function attributeVolume(): number?
	local value = player:GetAttribute("MusicVolume")
	if type(value) == "number" and MusicSettings.isValid(value) then
		return value
	end
	return nil
end

-- A server value moves the slider only while the player has no unsent or in-flight change.
local function applyServerVolume(value: number)
	if not inFlight and volume == confirmed then
		setVolume(value)
	end
	confirmed = value
end

player:GetAttributeChangedSignal("MusicVolume"):Connect(function()
	local value = attributeVolume()
	if value ~= nil then
		applyServerVolume(value)
	end
end)

-- Panel --------------------------------------------------------------------------------------

local close: () -> ()

local function open()
	UiKit.claimModal(MODAL_ID, close)
	panel.Visible = true
	status.Text = ""
	render()
end

close = function()
	UiKit.releaseModal(MODAL_ID)
	panel.Visible = false
end

UiKit.onActivated(downButton, function()
	change(MusicSettings.step(volume, -1))
end)
UiKit.onActivated(upButton, function()
	change(MusicSettings.step(volume, 1))
end)
UiKit.onActivated(muteButton, function()
	change(if volume <= 0 then lastAudible else 0)
end)
UiKit.onActivated(closeButton, close)
UiKit.onActivated(railButton, function()
	if panel.Visible then
		close()
	else
		open()
	end
end)

local function updateReady()
	local ready = player:GetAttribute("CompanyReady") == true
	railButton.Visible = ready and #TRACK_IDS > 0
	if not ready and panel.Visible then
		close()
	end
end
player:GetAttributeChangedSignal("CompanyReady"):Connect(updateReady)
updateReady()
render()

-- Playback -----------------------------------------------------------------------------------

local function playLoop(loaded: { Sound })
	local index = math.random(1, #loaded)
	while true do
		local sound = loaded[index]
		sound.TimePosition = 0
		sound.Volume = 0
		sound:Play()
		tween(sound, Config.FadeInSeconds, { Volume = Config.TrackVolume })
		while sound.IsPlaying and sound.TimePosition < sound.TimeLength - Config.FadeOutSeconds do
			task.wait(POLL_SECONDS)
		end
		tween(sound, Config.FadeOutSeconds, { Volume = 0 })
		task.wait(Config.FadeOutSeconds)
		sound:Stop()
		task.wait(Config.GapSeconds)
		index = index % #loaded + 1
	end
end

task.spawn(function()
	local deadline = os.clock() + Config.SettingWaitSeconds
	local initial = attributeVolume()
	while initial == nil and os.clock() < deadline do
		task.wait(POLL_SECONDS)
		initial = attributeVolume()
	end
	if initial ~= nil then
		applyServerVolume(initial)
	else
		setVolume(volume)
	end
	if #sounds == 0 then
		return
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
	local loaded: { Sound } = {}
	for index, sound in ipairs(sounds) do
		if sound.IsLoaded == false or sound.TimeLength <= 0 then
			warn(string.format("[ChristmasMarket2] music track %d did not load", TRACK_IDS[index]))
		else
			table.insert(loaded, sound)
		end
	end
	if #loaded == 0 then
		return
	end
	playLoop(loaded)
end)
