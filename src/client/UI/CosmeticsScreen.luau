-- CosmeticsScreen: the §24 Lab cosmetics tab — browse / buy / equip personal cosmetics.
-- Owned + equipped state is reactive (StateController.cosmetics, refreshed by CosmeticUpdate after
-- each action). The server is the authority: Buy/Equip just issue the C2S call and surface errors.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local CosmeticCatalog = require(ReplicatedStorage.Shared.Core.CosmeticCatalog)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local CosmeticController = require(script.Parent.Parent.Controllers.CosmeticController)

local Children = Fusion.Children
local doCleanup = Fusion.doCleanup

local CATEGORY_LABELS = {
	labSkin = "LAB SKINS",
	particles = "PARTICLE SETS",
	hudAccent = "HUD ACCENT",
	patentStamp = "PATENT STAMP",
}

local CosmeticsScreen = {}
local _scope = nil

function CosmeticsScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local cosmeticsValue = scope:Value(st.cosmetics)
	local balanceValue = scope:Value(st.balance)
	local statusValue = scope:Value("")

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.cosmetics ~= nil then
				cosmeticsValue:set(patch.cosmetics)
			end
			if patch.balance ~= nil then
				balanceValue:set(patch.balance)
			end
		end)
	)

	-- One cosmetic row: name + status + a Buy or Equip action (server validates).
	local function makeItemRow(id: string, item: any)
		local isEquipped = scope:Computed(function(use)
			local c = use(cosmeticsValue)
			return c and c.equipped and c.equipped[item.category] == id
		end)
		local isExplicitlyOwned = scope:Computed(function(use)
			if item.default then
				return true
			end
			local c = use(cosmeticsValue)
			return c and c.owned and c.owned[id] == true
		end)
		-- Currency item not yet owned → it's a Buy candidate.
		local isBuyable = scope:Computed(function(use)
			return item.currency ~= nil and not use(isExplicitlyOwned)
		end)
		local canAfford = scope:Computed(function(use)
			if item.currency == nil then
				return true
			end
			local bal = use(balanceValue)
			return (bal and bal[item.currency] or 0) >= item.price
		end)

		local statusText = scope:Computed(function(use)
			if use(isEquipped) then
				return "Equipped"
			elseif use(isExplicitlyOwned) then
				return "Owned"
			elseif item.currency == "pellets" then
				return string.format("%d Pellets", item.price)
			elseif item.currency == "catalysts" then
				return string.format("%d Catalysts", item.price)
			elseif item.unlock == "prestige5" then
				return "Prestige 5 unlock"
			elseif item.unlock == "event" then
				return "Event pass"
			end
			return ""
		end)
		local statusColor = scope:Computed(function(use)
			return (use(isEquipped) or use(isExplicitlyOwned)) and Theme.Colors.Success
				or Theme.Colors.TextSecondary
		end)

		local actionLabel = scope:Computed(function(use)
			if use(isEquipped) then
				return "✓"
			elseif use(isBuyable) then
				return "Buy"
			end
			return "Equip"
		end)
		local actionDisabled = scope:Computed(function(use)
			if use(isEquipped) then
				return true
			end
			if use(isBuyable) then
				return not use(canAfford)
			end
			-- Equip path: only enabled when actually owned. Locked prestige5/event
			-- items (not owned, not buyable) keep a disabled Equip until unlocked.
			return not use(isExplicitlyOwned)
		end)

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 7),
					PaddingBottom = UDim.new(0, 7),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 20),
					Position = UDim2.fromOffset(0, 2),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = item.name,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 14),
					Position = UDim2.fromOffset(0, 22),
					BackgroundTransparency = 1,
					TextColor3 = statusColor,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = statusText,
				}),
				scope:New("Frame")({
					Size = UDim2.fromOffset(96, 36),
					Position = UDim2.new(1, -96, 0.5, -18),
					BackgroundTransparency = 1,
					[Children] = {
						Components.Button(scope, {
							Text = actionLabel,
							Style = "secondary",
							Disabled = actionDisabled,
							OnClick = function()
								local ok, err
								if Fusion.peek(isBuyable) then
									ok, err = CosmeticController.purchase(id)
								else
									ok, err = CosmeticController.equip(id)
								end
								statusValue:set(ok and "" or (item.name .. ": " .. tostring(err)))
							end,
						}),
					},
				}),
			},
		})
	end

	-- Build all category sections into the scroll list.
	local sectionChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	local order = 1
	for _, category in ipairs(CosmeticCatalog.CATEGORIES) do
		table.insert(
			sectionChildren,
			scope:New("TextLabel")({
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = CATEGORY_LABELS[category] or category,
			})
		)
		order += 1

		local rows: { any } = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
			}),
		}
		for _, entry in ipairs(CosmeticCatalog.byCategory(category)) do
			table.insert(rows, makeItemRow(entry.id, entry.item))
		end
		table.insert(
			sectionChildren,
			scope:New("Frame")({
				LayoutOrder = order,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = rows,
			})
		)
		order += 1
	end

	scope:New("ScreenGui")({
		Name = "CosmeticsScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			Components.Backdrop(scope, {}),
			Components.ScreenHeader(scope, {
				Title = "Cosmetics",
				OnClose = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			-- Status line (errors from Buy/Equip)
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 16),
				Position = UDim2.fromOffset(12, 58),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Danger,
				FontFace = Theme.Font.Body,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = statusValue,
			}),
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, -24, 1, -84),
				Position = UDim2.fromOffset(12, 76),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				[Children] = sectionChildren,
			}),
		},
	})
end

function CosmeticsScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return CosmeticsScreen
