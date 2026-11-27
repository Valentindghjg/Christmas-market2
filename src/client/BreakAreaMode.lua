--!strict
-- Break-area mode (CM2-25/26 part b, docs/archive/plans/CM2-25-26b.md): a modal bar that moves the staff
-- break area. A ghost square follows the pointer (the mouse on PC, a short tap on touch); Rotate
-- (R), Place (Enter) and Cancel (Q). The client check is only a preview: the server checks the
-- spot again (Staff.MoveBreakArea) and decides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Staff = require(Shared:WaitForChild("Staff"))
local Stocking = require(Shared:WaitForChild("Stocking"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local BreakAreaMode = {}

local player = Players.LocalPlayer :: Player

local MODAL_ID = "BreakAreaMode"
local VALID_COLOR = UiKit.Colors.Valid
local INVALID_COLOR = UiKit.Colors.Red
local GHOST_SIZE = Vector3.new(8, 0.2, 8)
local ROTATION_STEP = 90
local PREVIEW_SECONDS = 0.25
local TAP_SECONDS = 0.3
local TAP_PIXELS = 12
local RESULT_SECONDS = 2
local DONE_SECONDS = 1.5
local BAR_PADDING = 8
local BAR_GAP = 6
local BUTTON_MAX_WIDTH = 160

-- Refusal codes of Staff.checkBreakArea and the sentence that explains each one.
local REASON_KEYS: { [string]: string } = {
	OutsideLot = "stockOutsideLot",
	KeepClear = "stockKeepClear",
	TooClose = "breakAreaTrees",
}

type Request = (action: string, payload: { [string]: any }) -> any

type Session = {
	plot: Model,
	pointer: { x: number, z: number },
	rotation: number,
	trees: { Stocking.Tree },
	level: number,
	valid: boolean,
	code: string?,
	lastPreviewAt: number,
	hovering: boolean,
	inFlight: boolean,
	done: boolean,
	result: string?,
	resultAt: number,
	request: Request,
	onDone: () -> (),
	connections: { RBXScriptConnection },
	gui: ScreenGui,
	ghostFolder: Folder,
	ghost: Part,
	header: TextLabel,
	reason: TextLabel,
	buttons: { [string]: TextButton },
}

local session: Session? = nil

-- Lot frame helpers (same code as StockingMode) ------------------------------------------------

local function plotModel(plotId: unknown): Model?
	if type(plotId) ~= "string" then
		return nil
	end
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(plotId)
	if plot and plot:IsA("Model") and plot.PrimaryPart then
		return plot
	end
	return nil
end

local function plotCenter(plot: Model): Vector3
	return (plot.PrimaryPart :: BasePart).Position
end

local function plotFacing(plot: Model): number
	return Stocking.facing(plotCenter(plot).Z)
end

local function snapHalf(value: number): number
	return math.floor(value * 2 + 0.5) / 2
end

local function groundY(plot: Model): number
	local ground = plot.PrimaryPart :: BasePart
	return ground.Position.Y + ground.Size.Y / 2
end

local function worldPoint(plot: Model, x: number, z: number): Vector3
	local center = plotCenter(plot)
	return Vector3.new(center.X + x, groundY(plot), center.Z + plotFacing(plot) * z)
end

local function toLotFrame(plot: Model, hit: Vector3): { x: number, z: number }
	local center = plotCenter(plot)
	return { x = snapHalf(hit.X - center.X), z = snapHalf((hit.Z - center.Z) * plotFacing(plot)) }
end

local function raycastLot(plot: Model, ray: Ray): Vector3?
	local include: { Instance } = { plot.PrimaryPart :: BasePart }
	local visuals = plot:FindFirstChild("ProgressionVisuals")
	local pad = visuals and visuals:FindFirstChild("LotExpansionPad")
	if pad then
		table.insert(include, pad)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local result = workspace:Raycast(ray.Origin, ray.Direction.Unit * 500, params)
	return if result then result.Position else nil
end

-- Exit -----------------------------------------------------------------------------------------

local function trace(message: string)
	if RunService:IsStudio() then
		print("[BREAK] " .. message)
	end
end

local function exit(reason: string)
	local current = session
	if current == nil then
		return
	end
	trace("exit " .. reason)
	session = nil
	for _, connection in current.connections do
		connection:Disconnect()
	end
	UiKit.releaseModal(MODAL_ID)
	current.ghostFolder:Destroy()
	current.gui:Destroy()
end

-- Preview --------------------------------------------------------------------------------------

local function refreshTrees(current: Session)
	local trees: { Stocking.Tree } = {}
	local display = current.plot:FindFirstChild("DisplayedTrees")
	if display then
		for _, model in display:GetChildren() do
			local x, z, sizeId = model:GetAttribute("LotX"), model:GetAttribute("LotZ"), model:GetAttribute("SizeId")
			if type(x) == "number" and type(z) == "number" and type(sizeId) == "string" then
				table.insert(trees, { x = x, z = z, sizeId = sizeId })
			end
		end
	end
	current.trees = trees
	local level = current.plot:GetAttribute("LotExpansionLevel")
	current.level = if type(level) == "number" then level else 0
end

local function reasonText(code: unknown): string
	local key = if type(code) == "string" then REASON_KEYS[code] else nil
	if key then
		return UiKit.localized(key)
	end
	return UiKit.localizedFormat("errorStatus", tostring(code))
end

local function setButton(button: TextButton, text: string, enabled: boolean?)
	button.Text = text
	if enabled ~= nil then
		UiKit.setEnabled(button, enabled, UiKit.Colors.Primary)
	end
end

local function render(current: Session)
	local input: Stocking.LayoutInput = { lotExpansion = current.level, trees = current.trees }
	local valid, code = Staff.checkBreakArea(input, current.pointer.x, current.pointer.z)
	current.valid = valid
	current.code = code

	local ghost = current.ghost
	ghost.CFrame = CFrame.new(worldPoint(current.plot, current.pointer.x, current.pointer.z) + Vector3.new(0, 0.1, 0))
		* CFrame.Angles(0, math.rad(current.rotation), 0)
	ghost.Color = if valid then VALID_COLOR else INVALID_COLOR

	current.header.Text = UiKit.localized("breakAreaMove")
	local text = if valid then UiKit.localized("breakAreaHint") else reasonText(code)
	if current.result and (current.done or os.clock() - current.resultAt < RESULT_SECONDS) then
		text = current.result :: string
	end
	current.reason.Text = text

	local buttons = current.buttons
	setButton(buttons.Rotate, UiKit.localized("breakAreaRotate"))
	setButton(buttons.Place, UiKit.localized("breakAreaPlace"), valid and not current.inFlight and not current.done)
	setButton(buttons.Cancel, UiKit.localized("breakAreaCancel"))
end

-- Actions --------------------------------------------------------------------------------------

local function rotate(current: Session)
	if current.done then
		return
	end
	current.rotation = (current.rotation + ROTATION_STEP) % 360
	render(current)
end

local function place()
	local current = session
	if current == nil or current.inFlight or current.done then
		return
	end
	render(current)
	if not current.valid then
		return
	end
	current.inFlight = true
	render(current)
	local response = current.request("Staff.MoveBreakArea", {
		x = current.pointer.x,
		z = current.pointer.z,
		rotation = current.rotation,
	})
	if session ~= current then
		return
	end
	current.inFlight = false
	current.resultAt = os.clock()
	if type(response) == "table" and response.ok == true then
		current.done = true
		current.result = UiKit.localized("breakAreaMoved")
		render(current)
		task.delay(DONE_SECONDS, function()
			if session == current then
				exit("placed")
				current.onDone()
			end
		end)
	else
		current.result = reasonText(if type(response) == "table" then response.errorCode else nil)
		render(current)
	end
end

-- Bar ------------------------------------------------------------------------------------------

local function placeBox(item: GuiObject, x: number, y: number, w: number, h: number)
	item.Position = UDim2.fromOffset(x, y)
	item.Size = UDim2.fromOffset(w, h)
end

local function buildBar(current: Session)
	local gui = current.gui
	local frame = Instance.new("Frame")
	frame.Name = "BreakAreaBar"
	frame.BackgroundColor3 = UiKit.Colors.Panel
	frame.BackgroundTransparency = 0.05
	frame.Active = true
	frame.Parent = gui
	UiKit.window(frame)
	local header = UiKit.label(frame, "Header", "", UiTheme.TextSize.Body)
	local reason = UiKit.label(frame, "Reason", "", UiTheme.TextSize.Small)
	reason.TextColor3 = UiKit.Colors.Muted
	current.header = header
	current.reason = reason
	local order = { "Rotate", "Place", "Cancel" }
	local actions: { [string]: () -> () } = {
		Rotate = function()
			rotate(current)
		end,
		Place = place,
		Cancel = function()
			exit("cancel")
		end,
	}
	for _, id in ipairs(order) do
		local color = if id == "Place" then UiKit.Colors.Primary else UiKit.Colors.Sand
		local button = UiKit.button(frame, id, "", color, UiTheme.TextSize.Small)
		UiKit.onActivated(button, actions[id])
		current.buttons[id] = button
	end
	-- On PC the pointer stays put while the mouse is over the bar, so its buttons can be used.
	table.insert(
		current.connections,
		frame.MouseEnter:Connect(function()
			current.hovering = true
		end)
	)
	table.insert(
		current.connections,
		frame.MouseLeave:Connect(function()
			current.hovering = false
		end)
	)
	-- The stocking bar's frame, header and reason boxes; one row of three buttons.
	table.insert(
		current.connections,
		UiKit.onLayout(gui, function(m)
			local layout = UiTheme.stockingBarLayout(m)
			local box = layout.frame
			local first = layout.controls.Size
			local buttonY = first.y
			local height = buttonY + first.h + BAR_PADDING
			placeBox(frame, box.x, box.y + box.h - height, box.w, height)
			placeBox(header, layout.header.x, layout.header.y, layout.header.w, layout.header.h)
			placeBox(reason, layout.reason.x, layout.reason.y, layout.reason.w, layout.reason.h)
			local width =
				math.min(BUTTON_MAX_WIDTH, math.floor((box.w - 2 * BAR_PADDING - (#order - 1) * BAR_GAP) / #order))
			for index, id in ipairs(order) do
				placeBox(current.buttons[id], BAR_PADDING + (index - 1) * (width + BAR_GAP), buttonY, width, first.h)
			end
		end)
	)
end

-- Entry ----------------------------------------------------------------------------------------

-- Opens the mode on the player's own plot (closes the Lot Manager). request sends one business
-- action; onDone runs after a successful move, once the bar has closed.
function BreakAreaMode.start(plotId: string, request: Request, onDone: () -> ())
	trace("start requested " .. tostring(plotId))
	if session ~= nil then
		trace("start skipped session")
		return
	end
	if player:GetAttribute("CompanyReady") ~= true then
		trace("start skipped notReady")
		return
	end
	local plot = plotModel(plotId)
	if plot == nil then
		trace("start skipped noPlot")
		return
	end
	local areaX, areaZ = plot:GetAttribute("BreakAreaX"), plot:GetAttribute("BreakAreaZ")
	local areaRotation = plot:GetAttribute("BreakAreaRotation")
	local pointer = if type(areaX) == "number" and type(areaZ) == "number"
		then { x = areaX, z = areaZ }
		else { x = 0, z = 0 }

	local gui = UiKit.screenGui("BreakAreaUI", 20)
	local ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "BreakAreaGhostFolder"
	ghostFolder.Parent = workspace.CurrentCamera
	local ghost = Instance.new("Part")
	ghost.Name = "BreakAreaGhost"
	ghost.Size = GHOST_SIZE
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.SmoothPlastic
	ghost.Color = VALID_COLOR
	ghost.Parent = ghostFolder

	local current: Session = {
		plot = plot,
		pointer = pointer,
		rotation = if type(areaRotation) == "number" then areaRotation % 360 else 0,
		trees = {},
		level = 0,
		valid = false,
		code = nil,
		lastPreviewAt = 0,
		hovering = false,
		inFlight = false,
		done = false,
		result = nil,
		resultAt = 0,
		request = request,
		onDone = onDone,
		connections = {},
		gui = gui,
		ghostFolder = ghostFolder,
		ghost = ghost,
		header = nil :: any,
		reason = nil :: any,
		buttons = {},
	}
	session = current
	UiKit.claimModal(MODAL_ID, function()
		exit("claim")
	end)
	buildBar(current)
	refreshTrees(current)

	local function track(connection: RBXScriptConnection)
		table.insert(current.connections, connection)
	end
	track(player:GetAttributeChangedSignal("CompanyReady"):Connect(function()
		if player:GetAttribute("CompanyReady") ~= true then
			exit("company")
		end
	end))
	track(player:GetAttributeChangedSignal("ActiveSaveId"):Connect(function()
		exit("save")
	end))
	track(player:GetAttributeChangedSignal("PlotId"):Connect(function()
		exit("plot")
	end))

	local touchStarts: { [InputObject]: { at: number, position: Vector3 } } = {}
	track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or session ~= current then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			touchStarts[input] = { at = os.clock(), position = input.Position }
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.R then
				rotate(current)
			elseif key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter then
				place()
			elseif key == Enum.KeyCode.Q then
				exit("keyQ")
			end
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local began = touchStarts[input]
		touchStarts[input] = nil
		if processed or began == nil or session ~= current or current.done then
			return
		end
		local moved = (input.Position - began.position).Magnitude
		if os.clock() - began.at >= TAP_SECONDS or moved >= TAP_PIXELS then
			return
		end
		local camera = workspace.CurrentCamera
		local hit = raycastLot(plot, camera:ScreenPointToRay(input.Position.X, input.Position.Y))
		if hit then
			current.pointer = toLotFrame(plot, hit)
			render(current)
		end
	end))
	track(RunService.RenderStepped:Connect(function()
		if session ~= current then
			return
		end
		if os.clock() - current.lastPreviewAt >= PREVIEW_SECONDS then
			current.lastPreviewAt = os.clock()
			refreshTrees(current)
		end
		if
			UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
			and not current.hovering
			and not current.done
			and not current.inFlight
		then
			local camera = workspace.CurrentCamera
			local mouse = UserInputService:GetMouseLocation()
			local hit = raycastLot(plot, camera:ViewportPointToRay(mouse.X, mouse.Y))
			if hit then
				current.pointer = toLotFrame(plot, hit)
			end
		end
		render(current)
	end))
	trace("start ok")
	render(current)
end

return BreakAreaMode
