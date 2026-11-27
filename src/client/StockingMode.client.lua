--!strict
-- Stocking mode (CM2-G14, docs/archive/plans/CM2-G14.md): the touch-first bar that opens at a receiving
-- bay. Size, rotate, single place, row fill with gap control and store mode, which puts a tree
-- back into receiving. The ghost is a client-only preview under the camera; the server checks
-- every spot again (Stock.Place / Stock.Store), so the preview is presentation only.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Stocking = require(Shared:WaitForChild("Stocking"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local UiKit = require(script.Parent:WaitForChild("UiKit") :: ModuleScript)

local player = Players.LocalPlayer :: Player
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BusinessAction") :: RemoteFunction

local MODAL_ID = "Stocking"
local PLACEMENT = GameConfig.Placement
local GHOST_POOL = 10
local VALID_COLOR = UiKit.Colors.Valid
local INVALID_COLOR = UiKit.Colors.Red
local TREE_HEIGHT = 7 -- studs of needles at display scale 1.0
local SIZE_SCALES = { Small = 0.6, Medium = 0.8, Large = 1.0 }
local PREVIEW_SECONDS = 0.25
local TAP_SECONDS = 0.3
local TAP_PIXELS = 12
local STORE_PICK_DISTANCE = 4
local RESULT_SECONDS = 2
local BAY_CHANGED_SECONDS = 1.5

type Session = {
	token: number,
	plot: Model,
	bay: BasePart,
	bayIndex: number,
	speciesId: string,
	sizeId: string,
	rotation: number,
	rowOn: boolean,
	gap: number,
	storeOn: boolean,
	pointer: { x: number, z: number },
	trees: { Stocking.Tree },
	level: number,
	breakArea: Stocking.Position?,
	lastPreviewAt: number,
	inFlight: boolean,
	closing: boolean,
	result: string?,
	resultAt: number,
	placeCount: number,
	placeValid: boolean,
	compact: boolean,
	storeTarget: Model?,
	connections: { RBXScriptConnection },
	gui: ScreenGui,
	ghostFolder: Folder,
	ghosts: { Model },
	highlight: Highlight,
	header: TextLabel,
	reason: TextLabel,
	buttons: { [string]: TextButton },
}

local session: Session? = nil
local sessionCounter = 0

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

local function count(bay: BasePart, sizeId: string): number
	local value = bay:GetAttribute("Count" .. sizeId)
	return if type(value) == "number" then value else 0
end

local function speciesName(speciesId: unknown): string
	local tree = type(speciesId) == "string" and GameConfig.Trees[speciesId]
	return if tree then tree.displayName else ""
end

local function errorText(code: unknown): string
	local key = type(code) == "string" and Stocking.ErrorKeys[code]
	if key then
		return UiKit.localized(key)
	end
	return UiKit.localizedFormat("errorStatus", tostring(code))
end

local function firstAvailableSize(bay: BasePart): string?
	for _, sizeId in ipairs(GameConfig.SizeIds) do
		if count(bay, sizeId) > 0 then
			return sizeId
		end
	end
	return nil
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

-- Ghost ----------------------------------------------------------------------------------------

local function ghostPart(parent: Instance, name: string): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Shape = Enum.PartType.Cylinder
	value.Anchored = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.CastShadow = false
	value.Transparency = 0.5
	value.Material = Enum.Material.SmoothPlastic
	value.Parent = parent
	return value
end

local function newGhost(folder: Folder, index: number): Model
	local model = Instance.new("Model")
	model.Name = "StockGhost_" .. index
	ghostPart(model, "Footprint")
	ghostPart(model, "Body")
	model.Parent = folder
	return model
end

-- Places one ghost: footprint disc of diameter 2r and a body cylinder, both upright.
local function showGhost(ghost: Model, position: Vector3, sizeId: string, valid: boolean)
	local r = Stocking.radius(sizeId)
	local height = TREE_HEIGHT * (SIZE_SCALES[sizeId] or 0.8)
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local color = if valid then VALID_COLOR else INVALID_COLOR
	local footprint = ghost:FindFirstChild("Footprint") :: Part
	footprint.Size = Vector3.new(0.2, 2 * r, 2 * r)
	footprint.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * upright
	footprint.Color = color
	footprint.Transparency = 0.5
	local body = ghost:FindFirstChild("Body") :: Part
	body.Size = Vector3.new(height, r, r)
	body.CFrame = CFrame.new(position + Vector3.new(0, 0.2 + height / 2, 0)) * upright
	body.Color = color
	body.Transparency = 0.5
end

local function hideGhost(ghost: Model)
	for _, child in ghost:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1
		end
	end
end

-- Exit -----------------------------------------------------------------------------------------

local function exit()
	local current = session
	if current == nil then
		return
	end
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
	-- CM2-25/26: trees may not stand in the staff break area.
	local areaX, areaZ = current.plot:GetAttribute("BreakAreaX"), current.plot:GetAttribute("BreakAreaZ")
	current.breakArea = if type(areaX) == "number" and type(areaZ) == "number" then { x = areaX, z = areaZ } else nil
end

local function nearestTree(current: Session): Model?
	local display = current.plot:FindFirstChild("DisplayedTrees")
	if not display then
		return nil
	end
	local best: Model? = nil
	local bestDistance = STORE_PICK_DISTANCE
	for _, model in display:GetChildren() do
		local x, z = model:GetAttribute("LotX"), model:GetAttribute("LotZ")
		if
			model:IsA("Model")
			and string.sub(model.Name, 1, 14) == "DisplayedTree_"
			and type(x) == "number"
			and type(z) == "number"
		then
			local dx, dz = x - current.pointer.x, z - current.pointer.z
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

local function hint(current: Session): string
	if current.storeOn then
		return UiKit.localized("stockingStoreHint")
	end
	if UserInputService.PreferredInput == Enum.PreferredInput.Touch then
		return UiKit.localized("stockingHintTouch")
	end
	return UiKit.localized("stockingHintMouse")
end

local function setButton(button: TextButton, text: string, enabled: boolean?)
	button.Text = text
	if enabled ~= nil then
		button.BackgroundColor3 = if enabled then UiKit.Colors.Gold else UiKit.Colors.Disabled
	end
end

local function render(current: Session)
	local bay = current.bay
	local available = count(bay, current.sizeId)
	if available < 1 then
		local other = firstAvailableSize(bay)
		if other then
			current.sizeId = other
			available = count(bay, other)
		end
	end
	current.header.Text = UiKit.localizedFormat(
		if current.compact then "stockingHeaderCompact" else "stockingHeader",
		speciesName(current.speciesId),
		count(bay, "Small"),
		count(bay, "Medium"),
		count(bay, "Large")
	)

	local carrying = player.Character ~= nil and (player.Character :: Model):FindFirstChild("CarriedTree") ~= nil
	local reasonText: string? = nil
	local valid = false
	current.placeCount = 0
	current.storeTarget = nil
	current.highlight.Adornee = nil

	if current.storeOn then
		for _, ghost in current.ghosts do
			hideGhost(ghost)
		end
		local target = nearestTree(current)
		if target then
			local reserved = target:GetAttribute("Reserved") == true
			current.highlight.Adornee = target
			current.highlight.FillColor = if reserved then INVALID_COLOR else VALID_COLOR
			current.highlight.OutlineColor = if reserved then INVALID_COLOR else VALID_COLOR
			if reserved then
				reasonText = errorText("Reserved")
			else
				current.storeTarget = target
				valid = true
			end
		end
	elseif available > 0 then
		local input: Stocking.LayoutInput =
			{ lotExpansion = current.level, trees = current.trees, breakArea = current.breakArea }
		local wanted = if current.rowOn then math.min(available, PLACEMENT.RowMax) else 1
		local positions = Stocking.rowPositions(
			current.pointer.x,
			current.pointer.z,
			current.rotation,
			current.sizeId,
			wanted,
			current.gap
		)
		local fits, code, failedAt = Stocking.checkRow(input, positions, current.sizeId)
		local validCount = if fits then #positions else (failedAt or 1) - 1
		for index, ghost in current.ghosts do
			local position = positions[index]
			if position and index <= validCount then
				showGhost(ghost, worldPoint(current.plot, position.x, position.z), current.sizeId, true)
			elseif position and index == validCount + 1 and not fits then
				showGhost(ghost, worldPoint(current.plot, position.x, position.z), current.sizeId, false)
			else
				hideGhost(ghost)
			end
		end
		if not fits then
			reasonText = errorText(code)
		end
		current.placeCount = validCount
		valid = validCount > 0
	else
		for _, ghost in current.ghosts do
			hideGhost(ghost)
		end
	end

	if reasonText == nil then
		if carrying then
			reasonText = UiKit.localized("handsFull")
		elseif available < 1 and not current.storeOn then
			reasonText = UiKit.localized("stockingBayEmpty")
		else
			reasonText = hint(current)
		end
	end
	if carrying then
		valid = false
	end
	if current.result and os.clock() - current.resultAt < RESULT_SECONDS then
		reasonText = current.result
	end
	current.reason.Text = reasonText :: string
	current.placeValid = valid

	local buttons = current.buttons
	setButton(buttons.Size, UiKit.localizedFormat("stockingSize", UiKit.localized("size" .. current.sizeId)))
	setButton(buttons.Rotate, UiKit.localized("stockingRotate"))
	setButton(buttons.Row, UiKit.localized(if current.rowOn then "stockingRowOn" else "stockingRowOff"))
	setButton(buttons.GapDown, "-")
	setButton(buttons.Gap, UiKit.localizedFormat("stockingGap", string.format("%.1f", current.gap)))
	setButton(buttons.GapUp, "+")
	setButton(buttons.Store, UiKit.localized(if current.storeOn then "stockingStoreOn" else "stockingStoreOff"))
	local placeText = if current.storeOn
		then UiKit.localized("stockingStoreAction")
		elseif current.rowOn and current.placeCount > 1 then UiKit.localizedFormat(
			"stockingPlaceRow",
			current.placeCount
		)
		else UiKit.localized("stockingPlace")
	setButton(buttons.Place, placeText, valid and not current.inFlight)
	setButton(buttons.Done, UiKit.localized("stockingDone"))
end

-- Actions --------------------------------------------------------------------------------------

local function showResult(current: Session, text: string)
	current.result = text
	current.resultAt = os.clock()
	render(current)
end

local function place()
	local current = session
	if current == nil or current.inFlight or current.closing then
		return
	end
	render(current)
	if not current.placeValid then
		return
	end
	current.inFlight = true
	render(current)
	local response
	if current.storeOn then
		local target = current.storeTarget :: Model
		response = UiKit.request(remote, "Stock.Store", { placementId = target:GetAttribute("PlacementId") })
	else
		response = UiKit.request(remote, "Stock.Place", {
			bay = current.bayIndex,
			speciesId = current.speciesId,
			sizeId = current.sizeId,
			x = current.pointer.x,
			z = current.pointer.z,
			rotation = current.rotation,
			count = current.placeCount,
			gap = current.gap,
		})
	end
	if session ~= current then
		return
	end
	current.inFlight = false
	if not response.ok then
		showResult(current, errorText(response.errorCode))
	elseif current.storeOn then
		showResult(current, UiKit.localized("stockingStored"))
	else
		local placed = if type(response.data) == "table" and type(response.data.placementIds) == "table"
			then #response.data.placementIds
			else current.placeCount
		showResult(
			current,
			if placed == 1
				then UiKit.localized("stockingPlacedOne")
				else UiKit.localizedFormat("stockingPlacedMany", placed)
		)
	end
end

local function cycleSize(current: Session)
	local sizes = GameConfig.SizeIds
	local start = table.find(sizes, current.sizeId) or 1
	for offset = 1, #sizes do
		local candidate = sizes[(start - 1 + offset) % #sizes + 1]
		if count(current.bay, candidate) > 0 then
			current.sizeId = candidate
			break
		end
	end
	render(current)
end

local function rotate(current: Session)
	current.rotation = (current.rotation + PLACEMENT.RotationStep) % 360
	render(current)
end

local function toggleRow(current: Session)
	current.rowOn = not current.rowOn
	render(current)
end

local function toggleStore(current: Session)
	current.storeOn = not current.storeOn
	render(current)
end

local function changeGap(current: Session, direction: number)
	local gap = PLACEMENT.Gap
	current.gap = math.clamp(current.gap + direction * gap.Step, gap.Min, gap.Max)
	render(current)
end

-- Bar ------------------------------------------------------------------------------------------

local function buildBar(current: Session)
	local gui = current.gui
	local frame = Instance.new("Frame")
	frame.Name = "StockingBar"
	frame.BackgroundColor3 = UiKit.Colors.Panel
	frame.BackgroundTransparency = 0.05
	frame.Parent = gui
	UiKit.window(frame)
	local header = UiKit.label(frame, "Header", "", UiTheme.TextSize.Body)
	local reason = UiKit.label(frame, "Reason", "", UiTheme.TextSize.Small)
	reason.TextColor3 = UiKit.Colors.Sand
	reason.TextWrapped = true
	reason.TextTruncate = Enum.TextTruncate.None
	current.header = header
	current.reason = reason
	local actions: { [string]: () -> () } = {
		Size = function()
			cycleSize(current)
		end,
		Rotate = function()
			rotate(current)
		end,
		Row = function()
			toggleRow(current)
		end,
		GapDown = function()
			changeGap(current, -1)
		end,
		Gap = function() end,
		GapUp = function()
			changeGap(current, 1)
		end,
		Store = function()
			toggleStore(current)
		end,
		Place = place,
		Done = exit,
	}
	for id, action in pairs(actions) do
		local color = if id == "Place" then UiKit.Colors.Gold else UiKit.Colors.Sand
		local button = UiKit.button(frame, id, "", color, UiTheme.TextSize.Small)
		UiKit.onActivated(button, action)
		current.buttons[id] = button
	end
	local function placeBox(item: GuiObject, box: UiTheme.Box)
		item.Position = UDim2.fromOffset(box.x, box.y)
		item.Size = UDim2.fromOffset(box.w, box.h)
	end
	table.insert(
		current.connections,
		UiKit.onLayout(gui, function(m)
			current.compact = m.compact
			local layout = UiTheme.stockingBarLayout(m)
			placeBox(frame, layout.frame)
			placeBox(header, layout.header)
			placeBox(reason, layout.reason)
			for id, button in pairs(current.buttons) do
				local box = layout.controls[id]
				if box then
					placeBox(button, box)
				end
			end
		end)
	)
end

-- Entry ----------------------------------------------------------------------------------------

local function start(prompt: ProximityPrompt)
	if session ~= nil or player:GetAttribute("CompanyReady") ~= true then
		return
	end
	local bay = prompt.Parent
	local folder = bay and bay.Parent
	local plot = folder and folder.Parent
	if not (bay and bay:IsA("BasePart") and plot and plot:IsA("Model")) then
		return
	end
	local ownPlot = plotModel(player:GetAttribute("PlotId"))
	if ownPlot == nil or ownPlot ~= plot or plot:GetAttribute("PlotId") ~= player:GetAttribute("PlotId") then
		return
	end
	local bayIndex = prompt:GetAttribute("BayIndex")
	local speciesId = bay:GetAttribute("SpeciesId")
	if type(bayIndex) ~= "number" or type(speciesId) ~= "string" or not GameConfig.Trees[speciesId] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	sessionCounter += 1
	local gui = UiKit.screenGui("StockingUI", 20)
	local ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "StockingGhost"
	ghostFolder.Parent = workspace.CurrentCamera
	local highlight = Instance.new("Highlight")
	highlight.Name = "StoreTarget"
	highlight.FillTransparency = 0.6
	highlight.Parent = ghostFolder
	local pointer = { x = 0, z = 0 }
	if root and root:IsA("BasePart") then
		pointer = toLotFrame(plot, root.Position + root.CFrame.LookVector * 8)
	end
	local current: Session = {
		token = sessionCounter,
		plot = plot,
		bay = bay,
		bayIndex = bayIndex,
		speciesId = speciesId,
		sizeId = firstAvailableSize(bay) or GameConfig.SizeIds[1],
		rotation = 0,
		rowOn = false,
		gap = PLACEMENT.Gap.Default,
		storeOn = false,
		pointer = pointer,
		trees = {},
		level = 0,
		breakArea = nil,
		lastPreviewAt = 0,
		inFlight = false,
		closing = false,
		result = nil,
		resultAt = 0,
		placeCount = 0,
		placeValid = false,
		compact = false,
		storeTarget = nil,
		connections = {},
		gui = gui,
		ghostFolder = ghostFolder,
		ghosts = {},
		highlight = highlight,
		header = nil :: any,
		reason = nil :: any,
		buttons = {},
	}
	for index = 1, GHOST_POOL do
		local ghost = newGhost(ghostFolder, index)
		hideGhost(ghost)
		table.insert(current.ghosts, ghost)
	end
	session = current
	UiKit.claimModal(MODAL_ID, exit)
	buildBar(current)
	refreshTrees(current)

	local function track(connection: RBXScriptConnection)
		table.insert(current.connections, connection)
	end
	track(player:GetAttributeChangedSignal("CompanyReady"):Connect(function()
		if player:GetAttribute("CompanyReady") ~= true then
			exit()
		end
	end))
	track(player:GetAttributeChangedSignal("ActiveSaveId"):Connect(exit))
	if humanoid then
		track(humanoid.Died:Connect(exit))
	end
	track(player.CharacterRemoving:Connect(exit))
	track(bay.AttributeChanged:Connect(function()
		if session ~= current or current.closing then
			return
		end
		local now = bay:GetAttribute("SpeciesId")
		if type(now) == "string" and now ~= "" and now ~= current.speciesId then
			-- Another species took this bay: say why, then leave stocking mode.
			current.closing = true
			showResult(current, UiKit.localized("stockBayChanged"))
			task.delay(BAY_CHANGED_SECONDS, function()
				if session == current then
					exit()
				end
			end)
			return
		end
		render(current)
	end))

	local touchStarts: { [InputObject]: { at: number, position: Vector3 } } = {}
	track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or session ~= current then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			touchStarts[input] = { at = os.clock(), position = input.Position }
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			place()
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.F then
				cycleSize(current)
			elseif key == Enum.KeyCode.R then
				rotate(current)
			elseif key == Enum.KeyCode.L then
				toggleRow(current)
			elseif key == Enum.KeyCode.G then
				toggleStore(current)
			elseif key == Enum.KeyCode.Q then
				exit()
			elseif key == Enum.KeyCode.Minus then
				changeGap(current, -1)
			elseif key == Enum.KeyCode.Equals then
				changeGap(current, 1)
			end
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local began = touchStarts[input]
		touchStarts[input] = nil
		if processed or began == nil or session ~= current then
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
		if UserInputService.PreferredInput ~= Enum.PreferredInput.Touch then
			local camera = workspace.CurrentCamera
			local mouse = UserInputService:GetMouseLocation()
			local hit = raycastLot(plot, camera:ViewportPointToRay(mouse.X, mouse.Y))
			if hit then
				current.pointer = toLotFrame(plot, hit)
			end
		end
		render(current)
	end))
	render(current)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, triggeredBy: Player)
	if triggeredBy ~= player or prompt:GetAttribute("PromptKind") ~= "StockBay" then
		return
	end
	start(prompt)
end)
