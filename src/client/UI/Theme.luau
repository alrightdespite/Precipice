--!strict
-- PRECIPICE theme — Modern rounded "sim-game" look (Phase B).
-- One cohesive custom palette: deep indigo-ink surfaces + a signature warm "honey"
-- accent with a darker shadow edge for the 3D pill button. Cool-blue secondary,
-- coral danger, mint success. Every action color ships as a {fill, shadow, text}
-- triple so the signature pill reads the same everywhere.
--
-- NOTE: a few legacy keys (Surface/SurfaceSheen/...) are preserved for compatibility.
-- The muddy AccentDim/SecondaryDim tokens were pruned after the Phase B migration.

local Theme = {}

Theme.Colors = {
	-- backdrop / surfaces (deep indigo ink, layered for depth)
	Background = Color3.fromHex("13121A"),
	BackdropTop = Color3.fromHex("211F30"),
	BackdropBottom = Color3.fromHex("0F0E15"),
	Surface = Color3.fromHex("211F2E"), -- card body
	SurfaceRaised = Color3.fromHex("2B2940"), -- chips, hovered, raised wells
	SurfaceWell = Color3.fromHex("181721"), -- inset wells / progress tracks

	-- signature accent: warm honey + 3D shadow edge + dark on-pill text
	Accent = Color3.fromHex("FFB23E"),
	AccentShadow = Color3.fromHex("C2761A"),
	AccentText = Color3.fromHex("3A2408"),

	-- secondary action: cool blue
	Secondary = Color3.fromHex("5B8DEF"),
	SecondaryShadow = Color3.fromHex("2F5BAE"),

	-- status
	Success = Color3.fromHex("46D08A"),
	SuccessShadow = Color3.fromHex("248B57"),
	Warning = Color3.fromHex("FFC53D"),
	Danger = Color3.fromHex("FF5F6E"),
	DangerShadow = Color3.fromHex("B8323F"),

	-- text
	TextPrimary = Color3.fromHex("F4F2F8"),
	TextSecondary = Color3.fromHex("9A96AD"),
	TextMuted = Color3.fromHex("6A6680"),

	-- borders / rim light
	Stroke = Color3.fromHex("353349"),
	StrokeStrong = Color3.fromHex("46435E"),

	Tier = {
		[1] = Color3.fromHex("8A93A6"),
		[2] = Color3.fromHex("46D08A"),
		[3] = Color3.fromHex("5B8DEF"),
		[4] = Color3.fromHex("B79CFF"),
		[5] = Color3.fromHex("FFC53D"),
		[6] = Color3.fromHex("FF7A91"),
		[7] = Color3.fromHex("FF9D4D"),
	},
}

Theme.Font = {
	-- chunky rounded display face for headers + big numbers (signature)
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Header = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	HeaderBold = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	-- clean UI face for body / labels / values
	Label = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.SemiBold),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Regular),
	Value = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	ValueHeavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
}

Theme.Layout = {
	CornerRadius = UDim.new(0, 14), -- cards / panels (rounded sim-game)
	CornerRadiusSmall = UDim.new(0, 10), -- chips, rows
	CornerRadiusLarge = UDim.new(0, 20), -- big modals / hero cards
	CornerRadiusPill = UDim.new(1, 0),
	Padding = UDim.new(0, 18),
	PaddingSmall = UDim.new(0, 10),
	CardPadding = UDim.new(0, 18),
	GapSmall = UDim.new(0, 8),
	GapMedium = UDim.new(0, 14),
	GapLarge = UDim.new(0, 20),
	TapTarget = UDim.new(0, 48),
	ButtonHeight = 50, -- signature pill height
	PillLift = 4, -- 3D bottom-edge thickness
}

-- Soft drop-shadow token. Single point of change: if this asset isn't approved in a
-- given place, swap Image here and every shadow updates. 9-slice rounded soft shadow.
Theme.Shadow = {
	Image = "rbxassetid://6014261993",
	Slice = Rect.new(49, 49, 450, 450),
	Color = Color3.fromHex("000000"),
	-- transparency of the shadow image (0 = solid black, 1 = invisible)
	Transparency = 0.55,
	-- how far the shadow bleeds past the card edge, in px
	Spread = 22,
	-- vertical offset (shadow falls down/right)
	OffsetY = 8,
}

Theme.Gradient = {
	-- full-screen backdrop wash (top lighter → bottom darker)
	Backdrop = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Colors.BackdropTop),
		ColorSequenceKeypoint.new(1, Theme.Colors.BackdropBottom),
	}),
	BackdropRotation = 90,
	-- subtle top-sheen on card surfaces (legacy key name kept)
	SurfaceSheen = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("2C2A3D")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("211F2E")),
	}),
	SurfaceSheenRotation = 90,
	-- glossy top-light on the accent pill (subtle vertical highlight)
	AccentGloss = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFFFFF")),
		ColorSequenceKeypoint.new(0.5, Color3.fromHex("FFFFFF")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("E8E8E8")),
	}),
	AccentGlossTransparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.78),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	}),
}

return Theme
