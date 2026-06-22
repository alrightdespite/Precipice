local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local TAGLINES = {
	"The patent won't wait.",
	"First in the world. Every time.",
	"Your lab never sleeps.",
}

local LoadingScreen = {}
local _scope = nil
local _progressValue = nil
local _bgRef = nil
local _cycling = false

function LoadingScreen.open()
	if _scope then
		return
	end
	_cycling = true
	_scope = Fusion.scoped(Fusion)
	local scope = _scope

	_progressValue = scope:Value(0)
	local progressValue = _progressValue

	local springProgress = scope:Spring(progressValue, 10, 1)

	local taglineIdx = scope:Value(1)
	local taglineAlpha = scope:Value(1)
	local springAlpha = scope:Spring(taglineAlpha, 8, 1)

	local taglineText = scope:Computed(function(use)
		return TAGLINES[use(taglineIdx)]
	end)

	local showTimeout = scope:Value(false)

	-- 8-second timeout message
	task.delay(8, function()
		if _scope then
			showTimeout:set(true)
		end
	end)

	-- Tagline cycle: fade out → swap → fade in
	local function cycleFn()
		if not _cycling then
			return
		end
		taglineAlpha:set(0)
		task.delay(0.3, function()
			if not _cycling then
				return
			end
			local next = (peek(taglineIdx) % #TAGLINES) + 1
			taglineIdx:set(next)
			taglineAlpha:set(1)
			task.delay(3, cycleFn)
		end)
	end
	task.delay(3, cycleFn)

	local bgFrame = scope:New("Frame")({
		Name = "Bg",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		[Children] = {
					scope:New("UIGradient")({
						Color = Theme.Gradient.Backdrop,
						Rotation = Theme.Gradient.BackdropRotation,
					}),
					-- Centered column
					scope:New("Frame")({
						Name = "Center",
						Size = UDim2.new(0.7, 0, 0, 200),
						Position = UDim2.new(0.15, 0, 0.3, 0),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirection = Enum.FillDirection.Vertical,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 16),
							}),
							-- Title
							scope:New("TextLabel")({
								Name = "Title",
								LayoutOrder = 1,
								Text = "PRECIPICE",
								Size = UDim2.new(1, 0, 0, 64),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextPrimary,
								FontFace = Theme.Font.Header,
								TextSize = 48,
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
							-- Tagline
							scope:New("TextLabel")({
								Name = "Tagline",
								LayoutOrder = 2,
								Text = taglineText,
								Size = UDim2.new(1, 0, 0, 28),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextSecondary,
								TextTransparency = scope:Computed(function(use)
									return 1 - use(springAlpha)
								end),
								FontFace = Theme.Font.Body,
								TextSize = 16,
								TextXAlignment = Enum.TextXAlignment.Center,
							}),
						},
					}),

					-- Progress bar (2px, full width at 20% from bottom)
					scope:New("Frame")({
						Name = "BarBg",
						Size = UDim2.new(0.7, 0, 0, 6),
						Position = UDim2.new(0.15, 0, 0.78, 0),
						BackgroundColor3 = Theme.Colors.SurfaceWell,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							scope:New("Frame")({
								Name = "Fill",
								Size = scope:Computed(function(use)
									return UDim2.new(math.clamp(use(springProgress), 0, 1), 0, 1, 0)
								end),
								BackgroundColor3 = Theme.Colors.Accent,
								BorderSizePixel = 0,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
									scope:New("UIGradient")({
										Color = ColorSequence.new({
											ColorSequenceKeypoint.new(0, Theme.Colors.Accent:Lerp(Color3.new(1, 1, 1), 0.2)),
											ColorSequenceKeypoint.new(1, Theme.Colors.Accent),
										}),
										Rotation = 90,
									}),
								},
							}),
						},
					}),

					-- Timeout label (appears after 8s)
					scope:New("TextLabel")({
						Name = "TimeoutMsg",
						Text = "Syncing your lab…",
						Size = UDim2.new(1, 0, 0, 20),
						Position = UDim2.new(0, 0, 0.82, 0),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center,
						Visible = showTimeout,
					}),
				},
			})
	_bgRef = bgFrame
	scope:New("ScreenGui")({
		Name = "LoadingScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = { bgFrame },
	})
end

function LoadingScreen.close()
	_cycling = false
	local bg = _bgRef
	local scopeToClean = _scope
	_bgRef = nil
	_scope = nil
	_progressValue = nil
	if bg and bg.Parent then
		local tween = TweenService:Create(bg, TweenInfo.new(0.3, Enum.EasingStyle.Linear), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			doCleanup(scopeToClean)
		end)
	else
		doCleanup(scopeToClean)
	end
end

function LoadingScreen.setProgress(n: number)
	if _progressValue then
		_progressValue:set(math.clamp(n, 0, 1))
	end
end

return LoadingScreen
