-- RevealCard: §13 result card overlay.
-- Called by RevealController after the VFX sequence completes.
-- DisplayOrder 50 — above all game screens.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local RemoteController = require(script.Parent.Parent.Controllers.RemoteController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local doCleanup = Fusion.doCleanup

local TIER_NAMES: { [number]: string } = {
	[1] = "Basic",
	[2] = "Refined",
	[3] = "Compound",
	[4] = "Advanced",
	[5] = "Exotic Precursor",
	[6] = "Exotic Base",
	[7] = "Exotic",
}

local RevealCard = {}
local _scope = nil

export type RevealCardProps = {
	compoundId: string,
	compound: { name: string?, tier: number?, baseValue: number?, flavor: string? }?,
	tier: number,
	isNatural: boolean,
	isWorldFirst: boolean,
	onDone: () -> (),
}

function RevealCard.show(props: RevealCardProps)
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end

	_scope = Fusion.scoped(Fusion)
	local scope = _scope

	local compound = props.compound or {}
	local tier = props.tier
	local tierColor = Theme.Colors.Tier[tier] or Theme.Colors.Accent
	local compoundName = (compound :: any).name or props.compoundId
	local tierLabel = TIER_NAMES[tier] or ("T" .. tier)
	local baseValue: number = (compound :: any).baseValue or 0
	local flavorText: string = (compound :: any).flavor or ""

	local borderColor = if props.isWorldFirst then Color3.fromHex("F59E0B") else tierColor
	local cardHeight = if props.isWorldFirst then 400 else 320

	local function doKeep()
		RevealCard.hide()
		props.onDone()
	end

	local function doSell()
		task.spawn(function()
			RemoteController.invoke("VaultInstantSell", props.compoundId, 1)
		end)
		RevealCard.hide()
		props.onDone()
	end

	-- Patent banner (world-first only)
	local patentBanner = nil
	if props.isWorldFirst then
		patentBanner = scope:New("Frame")({
			Name = "PatentBanner",
			Size = UDim2.new(1, 0, 0, 88),
			BackgroundColor3 = Color3.fromHex("78350F"),
			BorderSizePixel = 0,
			LayoutOrder = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 4),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Text = "PATENT CLAIMED",
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromHex("FCD34D"),
					FontFace = Theme.Font.Header,
					TextSize = 22,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Text = "FIRST IN THE WORLD",
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromHex("F59E0B"),
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 3,
					Text = "+5 Catalysts bonus awarded",
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
			},
		})
	end

	-- Tier badge
	local tierBadge = scope:New("Frame")({
		Name = "TierBadge",
		Size = UDim2.new(0, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = tierColor,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
			scope:New("TextLabel")({
				Text = "T" .. tier .. " · " .. tierLabel,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				TextColor3 = Color3.new(1, 1, 1),
				FontFace = Theme.Font.Label,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		},
	})

	-- Button row children
	local keepBtn = scope:New("TextButton")({
		Name = "Keep",
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Text = "Keep",
		TextColor3 = Theme.Colors.TextPrimary,
		FontFace = Theme.Font.Label,
		TextSize = 14,
		LayoutOrder = 1,
		[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }) },
		[OnEvent("Activated")] = doKeep,
	})

	local sellLabel = "Sell for " .. tostring(baseValue) .. " Pellets"
	local sellBtn = scope:New("TextButton")({
		Name = "Sell",
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Theme.Colors.Success,
		BorderSizePixel = 0,
		Text = sellLabel,
		TextColor3 = Color3.new(1, 1, 1),
		FontFace = Theme.Font.Label,
		TextSize = 12,
		LayoutOrder = 2,
		[Children] = { scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }) },
		[OnEvent("Activated")] = doSell,
	})

	local cardChildren: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
		scope:New("UIStroke")({
			Color = borderColor,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIPadding")({
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
		}),
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
		tierBadge,
		scope:New("TextLabel")({
			Name = "CompoundName",
			Text = compoundName,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.TextPrimary,
			FontFace = Theme.Font.Header,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
		}),
		scope:New("TextLabel")({
			Name = "Flavor",
			Text = flavorText,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Colors.TextSecondary,
			FontFace = Theme.Font.Body,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			LayoutOrder = 3,
		}),
		scope:New("TextLabel")({
			Name = "Value",
			Text = "Base value: " .. tostring(baseValue) .. " Pellets",
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromHex("F59E0B"),
			FontFace = Theme.Font.Value,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 4,
		}),
		scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			LayoutOrder = 5,
		}),
		scope:New("Frame")({
			Name = "Buttons",
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			LayoutOrder = 6,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				}),
				keepBtn,
				sellBtn,
			},
		}),
	}

	if patentBanner then
		table.insert(cardChildren, patentBanner)
	end

	-- Card starts below screen; tween slides it to center
	local card = scope:New("Frame")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -32, 0, cardHeight),
		Position = UDim2.new(0.5, 0, 1.5, 0),
		BackgroundColor3 = Theme.Colors.SurfaceRaised,
		BorderSizePixel = 0,
		ZIndex = 2,
		[Children] = cardChildren,
	})

	scope:New("ScreenGui")({
		Name = "RevealCard",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			card,
		},
	})

	-- Slide card up to vertical center
	TweenService:Create(
		card,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }
	):Play()
end

function RevealCard.hide()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return RevealCard
