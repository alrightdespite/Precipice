-- ShopScreen: the hub Shop pavilion's HUD (design §30 storefront). Two tabs —
-- Boosts (dev products) and Passes (gamepasses) — built on the Phase B UI system
-- (Theme / Components Backdrop / ScreenHeader / TabBar / signature pill Button).
--
-- Catalog metadata (label/desc/price) lives here; the live Robux IDs come from
-- GameConfig (placeholder 0 until real IDs ship — see Phase 14 manual follow-ups).
-- Owned-pass state is read reactively from StateController.gamepasses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Children = Fusion.Children
local doCleanup = Fusion.doCleanup

local TAB_BOOSTS = "boosts"
local TAB_PASSES = "passes"

-- Dev products: one-shot Robux purchases. `productId` keys into GameConfig.
local BOOSTS = {
	{
		name = "Timer Skip",
		desc = "Instantly finish your running slot",
		price = 75,
		productId = "PRODUCT_TIMER_SKIP",
	},
	{
		name = "Rush Analysis ×3",
		desc = "3 Rush Analysis uses for faster reveals",
		price = 100,
		productId = "PRODUCT_RUSH_ANALYSIS",
	},
	{
		name = "Catalyst Pack",
		desc = "+" .. tostring(GameConfig.PRODUCT_CATALYST_S_AMOUNT) .. " Catalysts",
		price = 200,
		productId = "PRODUCT_CATALYST_S",
	},
	{
		name = "Catalyst Crate",
		desc = "+" .. tostring(GameConfig.PRODUCT_CATALYST_L_AMOUNT) .. " Catalysts",
		price = 500,
		productId = "PRODUCT_CATALYST_L",
	},
}

-- Gamepasses: permanent unlocks. `gamepassId` keys into GameConfig; `ownKey` keys
-- into StateController.gamepasses for the Owned badge.
local PASSES = {
	{
		name = "Expanded Lab",
		desc = "+" .. tostring(GameConfig.EXPANDED_LAB_BONUS) .. " synthesis slots",
		price = 250,
		gamepassId = "GAMEPASS_EXPANDED_LAB",
		ownKey = "expandedLab",
	},
	{
		name = "Extended Offline",
		desc = "Offline income cap 12h → 24h",
		price = 150,
		gamepassId = "GAMEPASS_EXTENDED_OFFLINE",
		ownKey = "extendedOffline",
	},
	{
		name = "Compound Archive",
		desc = "One archive synthesis per compound, monthly",
		price = 300,
		gamepassId = "GAMEPASS_COMPOUND_ARCHIVE",
		ownKey = "compoundArchive",
	},
	{
		name = "Event Pass",
		desc = "2× Flux + exclusive event cosmetics",
		price = 400,
		gamepassId = "GAMEPASS_EVENT_PASS",
		ownKey = "eventPass",
	},
}

local ShopScreen = {}
local _scope = nil

local function promptProduct(productKey: string)
	local id = GameConfig[productKey]
	if type(id) ~= "number" or id <= 0 then
		warn("[ShopScreen] product not configured yet:", productKey)
		return
	end
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	SoundController.playSfx("purchase")
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(lp, id)
	end)
	if not ok then
		warn("[ShopScreen] PromptProductPurchase failed:", err)
	end
end

local function promptGamepass(passKey: string)
	local id = GameConfig[passKey]
	if type(id) ~= "number" or id <= 0 then
		warn("[ShopScreen] gamepass not configured yet:", passKey)
		return
	end
	local lp = Players.LocalPlayer
	if not lp then
		return
	end
	SoundController.playSfx("purchase")
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(lp, id)
	end)
	if not ok then
		warn("[ShopScreen] PromptGamePassPurchase failed:", err)
	end
end

function ShopScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local activeTab = scope:Value(TAB_BOOSTS)
	local gamepassesValue = scope:Value(st.gamepasses)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.gamepasses ~= nil then
				gamepassesValue:set(patch.gamepasses)
			end
		end)
	)

	-- One catalog row: name + desc on the left, a signature pill on the right.
	-- For passes, the pill flips to a flat "Owned" badge once owned.
	local function buildItem(item: any, isPass: boolean)
		local owned = isPass
			and scope:Computed(function(use)
				return use(gamepassesValue)[item.ownKey] == true
			end)
			or nil

		local rightControl
		if isPass then
			rightControl = scope:New("Frame")({
				Name = "Action",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(96, 38),
				BackgroundTransparency = 1,
				[Children] = {
					-- Owned badge
					scope:New("Frame")({
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.SurfaceWell,
						BorderSizePixel = 0,
						Visible = owned,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusSmall }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Success,
								Thickness = 1,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							scope:New("TextLabel")({
								Size = UDim2.fromScale(1, 1),
								BackgroundTransparency = 1,
								Text = "Owned",
								TextColor3 = Theme.Colors.Success,
								FontFace = Theme.Font.Value,
								TextSize = 13,
							}),
						},
					}),
					-- Buy pill (hidden once owned)
					scope:New("Frame")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Visible = scope:Computed(function(use)
							return not use(owned)
						end),
						[Children] = {
							Components.Button(scope, {
								Style = "primary",
								Size = UDim2.fromScale(1, 1),
								Text = "R$ " .. tostring(item.price),
								TextSize = 14,
								OnClick = function()
									promptGamepass(item.gamepassId)
								end,
							}),
						},
					}),
				},
			})
		else
			rightControl = scope:New("Frame")({
				Name = "Action",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(96, 38),
				BackgroundTransparency = 1,
				[Children] = {
					Components.Button(scope, {
						Style = "secondary",
						Size = UDim2.fromScale(1, 1),
						Text = "R$ " .. tostring(item.price),
						TextSize = 14,
						OnClick = function()
							promptProduct(item.productId)
						end,
					}),
				},
			})
		end

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			[Children] = {
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
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 20),
					Position = UDim2.fromOffset(0, 12),
					BackgroundTransparency = 1,
					Text = item.name,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 16),
					Position = UDim2.fromOffset(0, 32),
					BackgroundTransparency = 1,
					Text = item.desc,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				rightControl,
			},
		})
	end -- buildItem

	local function buildList(items: { any }, isPass: boolean)
		local rows: { [any]: any } = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
		}
		for idx, item in ipairs(items) do
			local row = buildItem(item, isPass)
			row.LayoutOrder = idx
			table.insert(rows, row)
		end
		return rows
	end

	local function buildPanel(tab: string, items: { any }, isPass: boolean)
		return scope:New("ScrollingFrame")({
			Name = tab .. "Panel",
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.fromScale(0, 0),
			Visible = scope:Computed(function(use)
				return use(activeTab) == tab
			end),
			[Children] = buildList(items, isPass),
		})
	end

	scope:New("ScreenGui")({
		Name = "ShopScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			Components.Backdrop(scope, {}),
			Components.ScreenHeader(scope, {
				Title = "Shop",
				Subtitle = "Support the lab",
				OnClose = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			Components.TabBar(scope, {
				Position = UDim2.fromOffset(0, 72),
				Active = activeTab,
				OnSelect = function(k)
					activeTab:set(k)
				end,
				Items = {
					{ key = TAB_BOOSTS, label = "Boosts" },
					{ key = TAB_PASSES, label = "Passes" },
				},
			}),
			scope:New("Frame")({
				Name = "Body",
				Size = UDim2.new(1, 0, 1, -128),
				Position = UDim2.fromOffset(0, 124),
				BackgroundTransparency = 1,
				[Children] = {
					buildPanel(TAB_BOOSTS, BOOSTS, false),
					buildPanel(TAB_PASSES, PASSES, true),
				},
			}),
		},
	})
end

function ShopScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return ShopScreen
