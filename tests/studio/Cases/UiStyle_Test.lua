--!strict
-- CM2-UI1: the pure style kit specs and the 22a tokens.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local UiStyle = require(Shared:WaitForChild("UiStyle"))
	local UiTheme = require(Shared:WaitForChild("UiTheme"))
	local expect = t.expect

	local function find(specs, className, name)
		local found = {}
		for _, item in ipairs(specs) do
			if item.className == className and item.name == name then
				table.insert(found, item)
			end
		end
		return found
	end

	t.test("interaction returns the CM2-UI scales and times", function()
		local idle = UiStyle.interaction("idle")
		expect.equal(idle.scale, 1)
		expect.equal(idle.time, 0.15)
		expect.equal(idle.style, "Quad")
		expect.equal(idle.direction, "Out")
		local hover = UiStyle.interaction("hover")
		expect.equal(hover.scale, 1.05)
		expect.equal(hover.time, 0.15)
		expect.equal(hover.style, "Quad")
		for _, state in ipairs({ "press", "touchPress" }) do
			local press = UiStyle.interaction(state)
			expect.equal(press.scale, 0.95)
			expect.equal(press.time, 0.08)
			expect.equal(press.style, "Quad")
		end
		local releaseHover = UiStyle.interaction("release", true)
		expect.equal(releaseHover.scale, 1.05)
		expect.equal(releaseHover.time, 0.15)
		expect.equal(releaseHover.style, "Back")
		expect.equal(UiStyle.interaction("release", false).scale, 1)
		expect.equal(UiStyle.interaction("release").scale, 1)
		local unknown = UiStyle.interaction("nonsense")
		expect.equal(unknown.scale, 1)
		expect.equal(unknown.style, "Quad")
	end)

	t.test("button and tab decorations", function()
		for _, kind in ipairs({ "button", "tab" }) do
			local specs = UiStyle.decorations(kind)
			expect.equal(#find(specs, "UIScale", "Press"), 1)
			local corner = find(specs, "UICorner", "Corner")
			expect.equal(#corner, 1)
			expect.equal(corner[1].props.CornerRadius, 8)
			local outline = find(specs, "UIStroke", "Outline")
			expect.equal(#outline, 1)
			expect.equal(outline[1].props.Thickness, 2)
			expect.equal(outline[1].props.ApplyStrokeMode, "Border")
			expect.equal(outline[1].props.Color, "Outline")
			expect.equal(outline[1].props.Transparency, 0.15)
			expect.equal(#find(specs, "UIGradient", "Shade"), 1)
		end
		expect.equal(#UiStyle.decorations("unknown"), 0)
	end)

	t.test("card and window decorations", function()
		local card = UiStyle.decorations("card")
		expect.equal(find(card, "UICorner", "Corner")[1].props.CornerRadius, 10)
		expect.equal(find(card, "UIStroke", "Outline")[1].props.Thickness, 1)
		local window = UiStyle.decorations("window")
		expect.equal(find(window, "UICorner", "Corner")[1].props.CornerRadius, 12)
		expect.equal(find(window, "UIStroke", "Outline")[1].props.Thickness, 2)
		expect.equal(#find(window, "UIGradient", "Shade"), 1)
		expect.equal(#find(window, "UIScale", "Open"), 1)
		expect.equal(#find(window, "UIScale", "Press"), 0)
	end)

	t.test("header decorations", function()
		local specs = UiStyle.decorations("header")
		expect.equal(#specs, 2)
		local corner = find(specs, "UICorner", "Corner")
		expect.equal(#corner, 1)
		expect.equal(corner[1].props.CornerRadius, 8)
		expect.equal(#find(specs, "UIGradient", "Shade"), 1)
		expect.equal(#find(specs, "UIStroke", "Outline"), 0)
		expect.equal(#find(specs, "UIScale", "Press"), 0)
	end)

	t.test("text colour follows the fill", function()
		for _, fill in ipairs({ "Primary", "Header", "Red", "Disabled" }) do
			expect.equal(UiStyle.textOn(fill), "Cream")
		end
		for _, fill in ipairs({ "Panel", "Row", "ListWell", "Sand", "Gold", "Cream" }) do
			expect.equal(UiStyle.textOn(fill), "DarkText")
		end
	end)

	t.test("disabled buttons do not animate", function()
		expect.equal(UiStyle.interactive(true, nil), true)
		expect.equal(UiStyle.interactive(true, true), false)
		expect.equal(UiStyle.interactive(false, nil), false)
	end)

	t.test("gradient is a grey multiplier within 8 %", function()
		for _, kind in ipairs({ "button", "tab", "window" }) do
			local shade = find(UiStyle.decorations(kind), "UIGradient", "Shade")[1]
			expect.equal(shade.props.Top, 1)
			expect.truthy(shade.props.Bottom >= 0.92)
			expect.truthy(shade.props.Bottom <= 1)
		end
	end)

	t.test("motion and style tokens match 22a", function()
		local motion = UiTheme.Motion
		expect.equal(motion.hoverScale, 1.05)
		expect.equal(motion.hoverTime, 0.15)
		expect.equal(motion.pressScale, 0.95)
		expect.equal(motion.pressTime, 0.08)
		expect.equal(motion.releaseTime, 0.15)
		expect.equal(motion.openScale, 0.95)
		expect.equal(motion.openTime, 0.18)
		expect.equal(motion.closeTime, 0.12)
		expect.equal(motion.toastTime, 0.2)
		expect.equal(motion.toastSlide, 12)
		expect.equal(motion.tabTime, 0.2)
		expect.equal(motion.indicatorHeight, 4)
		local style = UiTheme.Style
		expect.equal(style.StrokeControl, 2)
		expect.equal(style.StrokeSelected, 3)
		expect.equal(style.StrokeCard, 1)
		expect.equal(style.StrokeTitle, 1.5)
		expect.equal(style.StrokeTransparency, 0.15)
		expect.equal(style.GradientBottom, 0.92)
		expect.equal(style.ShadowOffset, 4)
		expect.equal(style.ShadowTransparency, 0.7)
		expect.equal(style.DimTransparency, 0.45)
		expect.equal(string.sub(UiTheme.ClickSound.id, 1, 11), "rbxasset://")
		expect.equal(UiTheme.ClickSound.volume, 0.5)
	end)

	t.test("font roles", function()
		expect.equal(UiTheme.Fonts.Family, "rbxasset://fonts/families/Nunito.json")
		expect.equal(UiTheme.Fonts.Weights.Title, "Heavy")
		expect.equal(UiTheme.Fonts.Weights.Body, "Bold")
		expect.equal(UiTheme.Fonts.Weights.Light, "SemiBold")
	end)
end
