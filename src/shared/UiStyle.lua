--!strict
-- CM2-UI1: pure interaction and decoration specs for the UI kit. No Instances: the client UiKit
-- turns these plain values into UIScale, UICorner, UIStroke and UIGradient children, and
-- tests/studio/Cases/UiStyle_Test.lua checks them headlessly. Look values are PROVISIONAL.
local UiTheme = require(script.Parent.UiTheme)

local UiStyle = {}

export type Kind = "button" | "tab" | "card" | "window" | "header"

export type DecorSpec = {
	className: string,
	name: string,
	props: { [string]: any },
}

export type InteractionSpec = {
	scale: number,
	time: number,
	style: "Quad" | "Back",
	direction: "Out",
}

local function spec(scale: number, time: number, style: "Quad" | "Back"): InteractionSpec
	return { scale = scale, time = time, style = style, direction = "Out" }
end

-- state: "idle", "hover", "press", "touchPress" or "release"; unknown states are idle.
function UiStyle.interaction(state: string, hovering: boolean?): InteractionSpec
	local motion = UiTheme.Motion
	if state == "hover" then
		return spec(motion.hoverScale, motion.hoverTime, "Quad")
	elseif state == "press" or state == "touchPress" then
		return spec(motion.pressScale, motion.pressTime, "Quad")
	elseif state == "release" then
		return spec(if hovering == true then motion.hoverScale else 1, motion.releaseTime, "Back")
	end
	return spec(1, motion.hoverTime, "Quad")
end

local function corner(radius: number): DecorSpec
	return { className = "UICorner", name = "Corner", props = { CornerRadius = radius } }
end

local function outline(thickness: number): DecorSpec
	return {
		className = "UIStroke",
		name = "Outline",
		props = {
			Thickness = thickness,
			ApplyStrokeMode = "Border",
			Color = "Outline",
			Transparency = UiTheme.Style.StrokeTransparency,
		},
	}
end

local function shade(): DecorSpec
	return {
		className = "UIGradient",
		name = "Shade",
		props = { Rotation = 90, Top = 1, Bottom = UiTheme.Style.GradientBottom },
	}
end

-- props.Color names a UiTheme.Colors entry; UiKit resolves it.
function UiStyle.decorations(kind: string): { DecorSpec }
	local style = UiTheme.Style
	if kind == "button" or kind == "tab" then
		return {
			{ className = "UIScale", name = "Press", props = { Scale = 1 } },
			corner(UiTheme.CornerRadius.Button),
			outline(style.StrokeControl),
			shade(),
		}
	elseif kind == "card" then
		return { corner(UiTheme.CornerRadius.Row), outline(style.StrokeCard) }
	elseif kind == "window" then
		return {
			corner(UiTheme.CornerRadius.Panel),
			outline(style.StrokeControl),
			shade(),
			{ className = "UIScale", name = "Open", props = { Scale = 1 } },
		}
	elseif kind == "header" then
		return { corner(UiTheme.CornerRadius.Button), shade() }
	end
	return {}
end

-- CM2-UI2: fills that carry Cream text; every other fill carries DarkText.
local LightTextFills: { [string]: boolean } = table.freeze({
	Primary = true,
	Header = true,
	Red = true,
	Disabled = true,
})
UiStyle.LightTextFills = LightTextFills

-- CM2-UICLIP: a growing scale (> 1) is capped so the total growth stays within Motion.hoverGrowMax px.
function UiStyle.cappedScale(scale: number, width: number, height: number): number
	if scale <= 1 then
		return scale
	end
	return math.min(scale, 1 + UiTheme.Motion.hoverGrowMax / math.max(width, height, 1))
end

-- Total px a hovering control grows (the larger side times the capped hover scale minus 1).
function UiStyle.hoverGrowth(width: number, height: number): number
	local longest = math.max(width, height, 1)
	return (UiStyle.cappedScale(UiTheme.Motion.hoverScale, width, height) - 1) * longest
end

-- fill names a UiTheme.Colors entry; returns the name of the text colour.
function UiStyle.textOn(fill: string): string
	return if LightTextFills[fill] == true then "Cream" else "DarkText"
end

-- A disabled button gets no hover or press motion.
function UiStyle.interactive(active: boolean, disabled: boolean?): boolean
	return active and disabled ~= true
end

return UiStyle
