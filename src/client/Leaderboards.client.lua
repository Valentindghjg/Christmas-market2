--!strict
-- Leaderboard screens on the village square (CM2-G12b, docs/archive/plans/CM2-G12b.md). The server
-- publishes each board's top rows as JSON in `ReplicatedStorage.Leaderboards` and the viewer's
-- value and rank as `Lb<Key>Value` / `Lb<Key>Rank`; this script only draws them on one
-- SurfaceGui per board in PlayerGui, adorned to the board's `Screen` part.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LeaderboardView = require(Shared:WaitForChild("LeaderboardView"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local Config = GameConfig.Leaderboards
local Layout = UiTheme.Leaderboard
local player = Players.LocalPlayer :: Player
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("Leaderboards")

local CANVAS_WIDTH = 440
local ADORNEE_SECONDS = 2

type RowLabels = { rank: TextLabel, name: TextLabel, value: TextLabel }
type Board = { gui: SurfaceGui, rows: { RowLabels }, you: RowLabels }

local function label(parent: Instance, name: string, x: number, width: number, you: boolean): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(x, 0)
	text.Size = UDim2.fromOffset(width, Layout.rowHeight)
	text.TextSize = Layout.textSize
	-- UiTheme.Fonts: Regular = Gotham, Bold = GothamBold.
	text.Font = if you then Enum.Font.GothamBold else Enum.Font.Gotham
	text.TextColor3 = if you then UiKit.Colors.Gold else UiKit.Colors.Cream
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.AutoLocalize = false
	text.Text = ""
	text.Parent = parent
	return text
end

local function row(parent: Instance, index: number, y: number, you: boolean): RowLabels
	local frame = Instance.new("Frame")
	frame.Name = if you then "You" else string.format("Row%02d", index)
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(0, y)
	frame.Size = UDim2.fromOffset(CANVAS_WIDTH, Layout.rowHeight)
	frame.Parent = parent
	local nameWidth = CANVAS_WIDTH - 2 * Layout.padding - Layout.rankWidth - Layout.valueWidth
	local rank = label(frame, "Rank", Layout.padding, Layout.rankWidth, you)
	local name = label(frame, "Name", Layout.padding + Layout.rankWidth, nameWidth, you)
	local value = label(frame, "Value", Layout.padding + Layout.rankWidth + nameWidth, Layout.valueWidth, you)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return { rank = rank, name = name, value = value }
end

local function newBoard(key: string): Board
	local gui = playerGui:FindFirstChild("Leaderboard_" .. key)
	if gui then
		gui:Destroy()
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Leaderboard_" .. key
	surface.ResetOnSpawn = false
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = Layout.pixelsPerStud
	surface.MaxDistance = Layout.maxDistance
	surface.LightInfluence = 0
	local rows: { RowLabels } = {}
	for i = 1, Config.TopCount do
		table.insert(rows, row(surface, i, Layout.padding + (i - 1) * Layout.rowHeight, false))
	end
	local you = row(surface, 0, Layout.padding + Config.TopCount * Layout.rowHeight + Layout.youGap, true)
	surface.Parent = playerGui
	return { gui = surface, rows = rows, you = you }
end

local boards: { [string]: Board } = {}
for _, key in Config.Keys do
	boards[key] = newBoard(key)
end

local function decodedRows(key: string): { LeaderboardView.Row }
	local raw = folder:GetAttribute(key)
	local decoded: any = nil
	if type(raw) == "string" then
		local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			decoded = result
		end
	end
	return LeaderboardView.rows(decoded)
end

local function valueText(key: string, value: number): string
	return UiKit.localizedFormat(LeaderboardView.valueText(key, value))
end

local function render(key: string)
	local board = boards[key]
	if board == nil then
		return
	end
	local list = decodedRows(key)
	for i, labels in board.rows do
		local entry = list[i]
		if entry then
			labels.rank.Text = tostring(entry.rank)
			labels.name.Text = entry.name or UiKit.localized("lbUnknownPlayer")
			labels.value.Text = valueText(key, entry.value)
		else
			labels.rank.Text = ""
			labels.name.Text = if i == 1 and #list == 0 then UiKit.localized("lbEmpty") else ""
			labels.value.Text = ""
		end
	end
	local noRank = UiKit.localized("lbNoRank")
	local value = player:GetAttribute("Lb" .. key .. "Value")
	board.you.rank.Text = LeaderboardView.rankText(player:GetAttribute("Lb" .. key .. "Rank")) or noRank
	board.you.name.Text = UiKit.localized("lbYou")
	board.you.value.Text = if type(value) == "number" then valueText(key, value) else noRank
end

for _, key in Config.Keys do
	render(key)
end

folder.AttributeChanged:Connect(function(name: string)
	render(name)
end)

player.AttributeChanged:Connect(function(name: string)
	local key = string.match(name, "^Lb(.+)Value$") or string.match(name, "^Lb(.+)Rank$")
	if key then
		render(key)
	end
end)

-- The boards stream in and out; the adornee follows every ADORNEE_SECONDS.
local function screenOf(key: string): Instance?
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local map = world and world:FindFirstChild("Map")
	local square = map and map:FindFirstChild("Square")
	local model = square and square:FindFirstChild("Board_" .. key)
	local screen = model and model:FindFirstChild("Screen")
	return if screen and screen:IsA("BasePart") then screen else nil
end

while true do
	for key, board in boards do
		local screen = screenOf(key)
		if board.gui.Adornee ~= screen then
			board.gui.Adornee = screen
		end
	end
	task.wait(ADORNEE_SECONDS)
end
