--!strict
-- ElementMeta: the 8 in-world "elements" PRECIPICE is themed around — single source of truth for
-- their symbol / atomic number / display name / signature colour. The map's element pylons, gardens,
-- district coins and plaques should match these; client binders (e.g. ElementSignController) read the
-- text + colour from here so the data lives in code rather than only in Studio.
--
-- ORDER is meaningful: it is the clockwise order of the 8 element pylons/gardens around the hub
-- (index 1..8). Colours are the canonical jewel tones from the world design (cobalt = blue, sulfur =
-- amber, chlorine = green, iodine = violet, etc.).

export type Element = {
	symbol: string,
	atomicNumber: number,
	name: string,
	color: Color3,
}

local ElementMeta: { Element } = {
	{ symbol = "C", atomicNumber = 6, name = "Carbon", color = Color3.fromRGB(38, 198, 188) }, -- teal
	{ symbol = "S", atomicNumber = 16, name = "Sulfur", color = Color3.fromRGB(245, 184, 49) }, -- amber
	{ symbol = "Cl", atomicNumber = 17, name = "Chlorine", color = Color3.fromRGB(70, 208, 138) }, -- emerald
	{ symbol = "Co", atomicNumber = 27, name = "Cobalt", color = Color3.fromRGB(91, 141, 239) }, -- sapphire
	{ symbol = "I", atomicNumber = 53, name = "Iodine", color = Color3.fromRGB(183, 156, 255) }, -- amethyst
	{ symbol = "Li", atomicNumber = 3, name = "Lithium", color = Color3.fromRGB(255, 122, 145) }, -- ruby
	{ symbol = "Cu", atomicNumber = 29, name = "Copper", color = Color3.fromRGB(255, 157, 77) }, -- copper
	{ symbol = "Na", atomicNumber = 11, name = "Sodium", color = Color3.fromRGB(255, 197, 61) }, -- topaz
}

return ElementMeta
