local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local Components = {}

local WHITE = Color3.new(1, 1, 1)

-- Per-style color sets for the signature 3D pill.
local STYLES = {
	primary = {
		fill = Theme.Colors.Accent,
		shadow = Theme.Colors.AccentShadow,
		text = Theme.Colors.AccentText,
		gloss = true,
	},
	secondary = {
		fill = Theme.Colors.Secondary,
		shadow = Theme.Colors.SecondaryShadow,
		text = Theme.Colors.TextPrimary,
		gloss = true,
	},
	danger = {
		fill = Theme.Colors.Danger,
		shadow = Theme.Colors.DangerShadow,
		text = WHITE,
		gloss = true,
	},
	success = {
		fill = Theme.Colors.Success,
		shadow = Theme.Colors.SuccessShadow,
		text = Theme.Colors.AccentText,
		gloss = true,
	},
}

-- dropShadow(scope, { Corner?, Transparency?, Spread?, OffsetY? }) → ImageLabel
-- A soft rounded drop-shadow that sits BEHIND its parent (ZIndex 0). Add as a child of
-- a non-clipping Frame; the shadow bleeds past the frame edges. Single asset, themed.
function Components.dropShadow(scope, props)
	props = props or {}
	local spread = props.Spread or Theme.Shadow.Spread
	return scope:New("ImageLabel")({
		Name = "DropShadow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, props.OffsetY or Theme.Shadow.OffsetY),
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		ZIndex = 0,
		Image = Theme.Shadow.Image,
		ImageColor3 = Theme.Shadow.Color,
		ImageTransparency = props.Transparency or Theme.Shadow.Transparency,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Shadow.Slice,
	})
end

-- Backdrop(scope, { Children?, Size? }) → full-screen gradient wash Frame.
function Components.Backdrop(scope, props)
	props = props or {}
	local inner: { [any]: any } = {
		scope:New("UIGradient")({
			Color = Theme.Gradient.Backdrop,
			Rotation = Theme.Gradient.BackdropRotation,
		}),
	}
	if props.Children then
		for _, child in ipairs(props.Children) do
			table.insert(inner, child)
		end
	end
	return scope:New("Frame")({
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		[Children] = inner,
	})
end

-- Button(scope, { Text, OnClick, Style?, Size?, Disabled? })
-- Signature 3D pill: a darker shadow "lip" peeks below a glossy face; the face springs
-- DOWN onto the lip on press (juicy sink) and lightens on hover.
-- Style: "primary" (default) | "secondary" | "danger" | "success"
function Components.Button(scope, props)
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	local style = STYLES[props.Style or "primary"] or STYLES.primary
	local lift = Theme.Layout.PillLift
	local radius = props.Corner or Theme.Layout.CornerRadius

	local function resolveDisabled(use)
		local dis = props.Disabled
		if typeof(dis) == "table" then
			dis = use(dis)
		end
		return dis and true or false
	end

	-- face fill: disabled grey, else hover-lightened style fill
	local faceGoal = scope:Computed(function(use)
		if resolveDisabled(use) then
			return Theme.Colors.SurfaceRaised
		end
		if use(hovered) then
			return style.fill:Lerp(WHITE, 0.12)
		end
		return style.fill
	end)
	local faceColor = scope:Spring(faceGoal, 30, 1)

	local lipColor = scope:Computed(function(use)
		if resolveDisabled(use) then
			return Theme.Colors.SurfaceWell
		end
		return style.shadow
	end)

	local textColor = scope:Computed(function(use)
		if resolveDisabled(use) then
			return Theme.Colors.TextMuted
		end
		return style.text
	end)

	-- face vertical position: raised (0) → sunk (lift) on press. Disabled never sinks.
	local faceY = scope:Computed(function(use)
		if not resolveDisabled(use) and use(pressed) then
			return UDim2.new(0, 0, 0, lift)
		end
		return UDim2.new(0, 0, 0, 0)
	end)
	local faceSpring = scope:Spring(faceY, 40, 0.8)

	local glossEnabled = scope:Computed(function(use)
		return style.gloss and not resolveDisabled(use)
	end)

	return scope:New("TextButton")({
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 0, Theme.Layout.ButtonHeight),
		Text = "",
		BorderSizePixel = 0,
		[Children] = {
			-- shadow lip (the 3D bottom edge)
			scope:New("Frame")({
				Name = "Lip",
				BackgroundColor3 = lipColor,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = radius }),
				},
			}),
			-- glossy face
			scope:New("Frame")({
				Name = "Face",
				BackgroundColor3 = faceColor,
				BorderSizePixel = 0,
				Position = faceSpring,
				Size = UDim2.new(1, 0, 1, -lift),
				ZIndex = 2,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = radius }),
					scope:New("UIGradient")({
						Color = Theme.Gradient.AccentGloss,
						Transparency = Theme.Gradient.AccentGlossTransparency,
						Rotation = 90,
						Enabled = glossEnabled,
					}),
					scope:New("TextLabel")({
						Name = "Label",
						Text = props.Text or "",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = textColor,
						FontFace = Theme.Font.Value,
						TextSize = props.TextSize or 16,
						TextXAlignment = Enum.TextXAlignment.Center,
						ZIndex = 3,
					}),
				},
			}),
		},
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
			pressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		[OnEvent("Activated")] = function()
			local dis = props.Disabled
			if typeof(dis) == "table" then
				dis = peek(dis)
			end
			if not dis and props.OnClick then
				props.OnClick()
			end
		end,
	})
end

-- Card(scope, { Children?, Padding?, Size?, Shadow?, Corner? })
-- Rounded surface with a top-sheen gradient, rim-light stroke, and (default) a soft
-- drop shadow behind it for real depth.
function Components.Card(scope, props)
	local radius = props.Corner or Theme.Layout.CornerRadius
	local inner: { [any]: any } = {
		scope:New("UICorner")({ CornerRadius = radius }),
		scope:New("UIGradient")({
			Color = Theme.Gradient.SurfaceSheen,
			Rotation = Theme.Gradient.SurfaceSheenRotation,
		}),
		scope:New("UIStroke")({
			Color = Theme.Colors.Stroke,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}
	if props.Shadow ~= false then
		table.insert(inner, Components.dropShadow(scope))
	end
	if props.Padding then
		table.insert(
			inner,
			scope:New("UIPadding")({
				PaddingTop = Theme.Layout.Padding,
				PaddingBottom = Theme.Layout.Padding,
				PaddingLeft = Theme.Layout.Padding,
				PaddingRight = Theme.Layout.Padding,
			})
		)
	end
	if props.Children then
		for _, child in ipairs(props.Children) do
			table.insert(inner, child)
		end
	end
	return scope:New("Frame")({
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		[Children] = inner,
	})
end

-- Label(scope, { Text, Style? })
-- Style: "display" | "header" | "label" | "body" | "value" | "secondary"
function Components.Label(scope, props)
	local style = props.Style or "body"
	local font = Theme.Font.Body
	local size = 14
	local color = Theme.Colors.TextPrimary
	if style == "display" then
		font = Theme.Font.Display
		size = 28
	elseif style == "header" then
		font = Theme.Font.Header
		size = 22
	elseif style == "label" then
		font = Theme.Font.Label
		size = 13
	elseif style == "value" then
		font = Theme.Font.Value
		size = 15
	elseif style == "secondary" then
		color = Theme.Colors.TextSecondary
	end
	return scope:New("TextLabel")({
		Text = props.Text or "",
		BackgroundTransparency = 1,
		TextColor3 = props.Color or color,
		FontFace = props.Font or font,
		TextSize = props.TextSize or size,
		Size = props.Size or UDim2.new(1, 0, 0, size + 4),
		TextXAlignment = props.Align or Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
end

-- TierBadge(scope, { Tier }) → pill badge with tier color + 3D-ish darker rim.
function Components.TierBadge(scope, props)
	local tier = props.Tier or 1
	local tierColor = Theme.Colors.Tier[tier] or Theme.Colors.TextSecondary
	return scope:New("Frame")({
		Size = UDim2.fromOffset(36, 24),
		BackgroundColor3 = tierColor,
		BorderSizePixel = 0,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusPill }),
			scope:New("UIStroke")({
				Color = tierColor:Lerp(Color3.new(0, 0, 0), 0.35),
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("TextLabel")({
				Text = "T" .. tostring(tier),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = WHITE,
				FontFace = Theme.Font.Value,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})
end

-- Divider(scope) → 1px horizontal separator
function Components.Divider(scope)
	return scope:New("Frame")({
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Colors.Stroke,
		BorderSizePixel = 0,
	})
end

-- ProgressBar(scope, { ValueState, MaxState?, Color? })
-- ValueState/MaxState: Values/Computeds or plain numbers
function Components.ProgressBar(scope, props)
	local fillColor = props.Color or Theme.Colors.Accent
	local fillWidth = scope:Computed(function(use)
		local val = props.ValueState
		local mx = props.MaxState
		if typeof(val) == "table" then
			val = use(val)
		end
		if typeof(mx) == "table" then
			mx = use(mx)
		end
		mx = mx or 1
		if mx <= 0 then
			return 0
		end
		return math.clamp(val / mx, 0, 1)
	end)
	local springWidth = scope:Spring(fillWidth, 18, 1)
	return scope:New("Frame")({
		Size = props.Size or UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Theme.Colors.SurfaceWell,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({
				Color = Theme.Colors.Stroke,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("Frame")({
				Size = scope:Computed(function(use)
					return UDim2.new(math.clamp(use(springWidth), 0, 1), 0, 1, 0)
				end),
				BackgroundColor3 = fillColor,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, fillColor:Lerp(WHITE, 0.18)),
							ColorSequenceKeypoint.new(1, fillColor),
						}),
						Rotation = 90,
					}),
				},
			}),
		},
	})
end

-- ScrollFrame(scope, { Children, Size? })
function Components.ScrollFrame(scope, props)
	local listLayout = scope:New("UIListLayout")({
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = Theme.Layout.GapSmall,
	})

	local inner: { [any]: any } = { listLayout }
	if props.Children then
		for _, child in ipairs(props.Children) do
			table.insert(inner, child)
		end
	end

	local contentSize = scope:Value(Vector2.new(0, 0))
	local canvasSize = scope:Computed(function(use)
		return UDim2.fromOffset(0, use(contentSize).Y)
	end)

	return scope:New("ScrollingFrame")({
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = canvasSize,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		[Children] = inner,
		[Fusion.OnChange("AbsoluteContentSize")] = function()
			-- handled by AutomaticCanvasSize
		end,
	})
end

return Components
