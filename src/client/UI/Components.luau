local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local Components = {}

-- Button(scope, { Text, OnClick, Style?, Size?, Disabled? })
-- Style: "primary" (default) | "secondary" | "danger"
function Components.Button(scope, props)
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	local style = props.Style or "primary"

	local bgGoal = scope:Computed(function(use)
		local dis = props.Disabled
		if typeof(dis) == "table" then
			dis = use(dis)
		end
		if dis then
			return Theme.Colors.SurfaceRaised
		end
		if use(pressed) then
			if style == "danger" then
				return Color3.fromHex("B91C1C")
			end
			if style == "secondary" then
				return Theme.Colors.SurfaceRaised
			end
			return Theme.Colors.AccentDim
		elseif use(hovered) then
			if style == "danger" then
				return Theme.Colors.Danger:Lerp(Color3.new(1, 1, 1), 0.1)
			end
			if style == "secondary" then
				return Theme.Colors.SurfaceRaised
			end
			return Theme.Colors.Accent:Lerp(Color3.new(1, 1, 1), 0.1)
		else
			if style == "danger" then
				return Theme.Colors.Danger
			end
			if style == "secondary" then
				return Theme.Colors.Surface
			end
			return Theme.Colors.Accent
		end
	end)
	local springBg = scope:Spring(bgGoal, 25, 1)

	local textColor = scope:Computed(function(use)
		local dis = props.Disabled
		if typeof(dis) == "table" then
			dis = use(dis)
		end
		if dis then
			return Theme.Colors.TextSecondary
		end
		if style == "secondary" then
			return Theme.Colors.Accent
		end
		return Theme.Colors.TextPrimary
	end)

	local disabledNow = scope:Computed(function(use)
		local dis = props.Disabled
		if typeof(dis) == "table" then
			dis = use(dis)
		end
		return dis and true or false
	end)

	local sheenEnabled = scope:Computed(function(use)
		return (style == "primary" or style == "secondary") and not use(disabledNow)
	end)

	return scope:New("TextButton")({
		AutoButtonColor = false,
		BackgroundColor3 = springBg,
		Size = props.Size or UDim2.new(1, 0, 0, 44),
		Text = "",
		BorderSizePixel = 0,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			scope:New("UIGradient")({
				Color = Theme.Gradient.SurfaceSheen,
				Rotation = Theme.Gradient.SurfaceSheenRotation,
				Enabled = sheenEnabled,
			}),
			style == "secondary" and scope:New("UIStroke")({
				Color = Theme.Colors.Stroke,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}) or nil,
			scope:New("TextLabel")({
				Name = "Label",
				Text = props.Text or "",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = textColor,
				FontFace = Theme.Font.Value,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
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

-- Card(scope, { Children?, Padding? }) → Frame with Surface bg + 8px corner + 1px border
function Components.Card(scope, props)
	local inner: { [any]: any } = {
		scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
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
-- Style: "header" | "label" | "body" | "value" | "secondary"
function Components.Label(scope, props)
	local style = props.Style or "body"
	local font = Theme.Font.Body
	local size = 13
	local color = Theme.Colors.TextPrimary
	if style == "header" then
		font = Theme.Font.Header
		size = 22
	elseif style == "label" then
		font = Theme.Font.Label
		size = 13
	elseif style == "value" then
		font = Theme.Font.Value
		size = 14
	elseif style == "secondary" then
		color = Theme.Colors.TextSecondary
	end
	return scope:New("TextLabel")({
		Text = props.Text or "",
		BackgroundTransparency = 1,
		TextColor3 = props.Color or color,
		FontFace = font,
		TextSize = size,
		Size = props.Size or UDim2.new(1, 0, 0, size + 4),
		TextXAlignment = props.Align or Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
end

-- TierBadge(scope, { Tier }) → 32×22 pill badge with tier color
function Components.TierBadge(scope, props)
	local tier = props.Tier or 1
	local tierColor = Theme.Colors.Tier[tier] or Theme.Colors.TextSecondary
	return scope:New("Frame")({
		Size = UDim2.fromOffset(34, 22),
		BackgroundColor3 = tierColor,
		BorderSizePixel = 0,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusPill }),
			scope:New("UIStroke")({
				Color = tierColor:Lerp(Color3.new(0, 0, 0), 0.3),
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("TextLabel")({
				Text = "T" .. tostring(tier),
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = Color3.new(1, 1, 1),
				FontFace = Theme.Font.Value,
				TextSize = 12,
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
	local springWidth = scope:Spring(fillWidth, 12, 1)
	return scope:New("Frame")({
		Size = props.Size or UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Colors.SurfaceRaised,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("Frame")({
				Size = scope:Computed(function(use)
					return UDim2.new(math.clamp(use(springWidth), 0, 1), 0, 1, 0)
				end),
				BackgroundColor3 = props.Color or Theme.Colors.Accent,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Theme.Colors.Accent),
							ColorSequenceKeypoint.new(1, Theme.Colors.Accent:Lerp(Color3.new(1, 1, 1), 0.15)),
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
		Padding = UDim.new(0, 4),
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
