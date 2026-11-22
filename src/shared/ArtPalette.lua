--!strict
-- Original palette for Blender-made art (CM2-AP; PROVISIONAL). Blender objects are named
-- <PartName>__<PaletteKey>; the pipeline paints MeshParts from this table, so models need
-- no textures. Pure data: usable from Lune tools and the game. Add keys freely; never
-- change an existing value without a DECISION_LOG entry.
export type PaletteEntry = { rgb: { number }, material: string }

local ArtPalette: { [string]: PaletteEntry } = {
	NeedleGreen = { rgb = { 46, 107, 69 }, material = "SmoothPlastic" },
	NeedleGreenShade = { rgb = { 28, 74, 50 }, material = "SmoothPlastic" },
	NeedleFrost = { rgb = { 196, 222, 214 }, material = "SmoothPlastic" },
	-- Tree species needles (CM2-12, PROVISIONAL)
	NeedleDeep = { rgb = { 30, 84, 66 }, material = "SmoothPlastic" },
	NeedleDeepShade = { rgb = { 18, 58, 46 }, material = "SmoothPlastic" },
	NeedleSage = { rgb = { 72, 120, 100 }, material = "SmoothPlastic" },
	NeedleSageShade = { rgb = { 48, 88, 74 }, material = "SmoothPlastic" },
	NeedleBlue = { rgb = { 88, 128, 146 }, material = "SmoothPlastic" },
	NeedleBlueShade = { rgb = { 58, 92, 112 }, material = "SmoothPlastic" },
	NeedleSilver = { rgb = { 150, 190, 186 }, material = "SmoothPlastic" },
	NeedleSilverShade = { rgb = { 104, 146, 146 }, material = "SmoothPlastic" },
	BarkBrown = { rgb = { 110, 72, 45 }, material = "SmoothPlastic" },
	BarkBrownShade = { rgb = { 78, 50, 32 }, material = "SmoothPlastic" },
	WoodWarm = { rgb = { 168, 112, 66 }, material = "SmoothPlastic" },
	WoodWarmShade = { rgb = { 122, 78, 44 }, material = "SmoothPlastic" },
	RoofRed = { rgb = { 170, 46, 46 }, material = "SmoothPlastic" },
	RoofRedShade = { rgb = { 122, 32, 36 }, material = "SmoothPlastic" },
	SnowWhite = { rgb = { 240, 244, 248 }, material = "SmoothPlastic" },
	SnowShade = { rgb = { 206, 218, 230 }, material = "SmoothPlastic" },
	StoneGray = { rgb = { 132, 138, 146 }, material = "SmoothPlastic" },
	StoneGrayShade = { rgb = { 96, 102, 112 }, material = "SmoothPlastic" },
	MetalDark = { rgb = { 52, 58, 64 }, material = "SmoothPlastic" },
	FabricCream = { rgb = { 232, 220, 196 }, material = "SmoothPlastic" },
	-- HQ tiers (CM2-13a, PROVISIONAL)
	FabricCreamShade = { rgb = { 200, 186, 160 }, material = "SmoothPlastic" },
	RoofGreen = { rgb = { 58, 104, 88 }, material = "SmoothPlastic" },
	RoofGreenShade = { rgb = { 40, 76, 64 }, material = "SmoothPlastic" },
	RoofSlate = { rgb = { 86, 94, 108 }, material = "SmoothPlastic" },
	RoofSlateShade = { rgb = { 62, 68, 82 }, material = "SmoothPlastic" },
	GoldAccent = { rgb = { 214, 170, 72 }, material = "SmoothPlastic" },
	LightWarm = { rgb = { 255, 214, 140 }, material = "Neon" },
	-- Vehicles (CM2-14, PROVISIONAL)
	CarPaint = { rgb = { 176, 52, 48 }, material = "SmoothPlastic" },
	GlassBlue = { rgb = { 150, 186, 204 }, material = "SmoothPlastic" },
	TruckGreen = { rgb = { 66, 124, 72 }, material = "SmoothPlastic" },
	TruckGreenShade = { rgb = { 44, 90, 52 }, material = "SmoothPlastic" },
}

return ArtPalette
