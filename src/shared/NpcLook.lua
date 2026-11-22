--!strict
-- Deterministic winter look of a customer NPC per visit sequence (CM2-N1). Every colour
-- comes from the own palette in GameConfig.Customers.Npc.Look (RGB 0..255).
local GameConfig = require(script.Parent.GameConfig)

local NpcLook = {}

export type Rgb = { number }
export type Look = {
	skin: Rgb,
	coat: Rgb,
	pants: Rgb,
	scarf: Rgb,
	beanie: Rgb,
	boots: Rgb,
	pompom: boolean,
	scale: number,
}

function NpcLook.forVisit(n: number): Look
	local look = GameConfig.Customers.Npc.Look
	return {
		skin = look.Skin[((5 * n) % #look.Skin) + 1],
		coat = look.Coat[(n % #look.Coat) + 1],
		pants = look.Pants[((3 * n) % #look.Pants) + 1],
		scarf = look.Scarf[((7 * n) % #look.Scarf) + 1],
		beanie = look.Beanie[((11 * n) % #look.Beanie) + 1],
		boots = look.Boots,
		pompom = n % 2 == 0,
		scale = look.Scales[((13 * n) % #look.Scales) + 1],
	}
end

return NpcLook
