-- VaultScreen: §16 inventory — lists every compound held in the player's vault with an
-- Instant-Sell action (100% of base value). Opened from the in-world Vault station and the
-- More drawer. Pure UI over existing state/remotes: reads StateController.vault + balance
-- (kept live by VaultUpdate / BalanceUpdate) and calls VaultController.instantSell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local VaultController = require(script.Parent.Parent.Controllers.VaultController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local function formatNum(n: number): string
	local abs = math.abs(n)
	if abs >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	end
	if abs >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	end
	if abs >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	end
	if abs >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function compoundName(id: string): string
	local c = Compounds[id]
	return (c and c.name) or id
end

local function tierOf(id: string): number
	local c = Compounds[id]
	return (c and c.tier) or 1
end

local function baseValueOf(id: string): number
	local c = Compounds[id]
	return (c and c.baseValue) or 0
end

local VaultScreen = {}
local _scope = nil

function VaultScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local vaultValue = scope:Value(st.vault)
	local balanceValue = scope:Value(st.balance)
	local statusMsg = scope:Value("")

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.vault ~= nil then
				vaultValue:set(patch.vault)
			end
			if patch.balance ~= nil then
				balanceValue:set(patch.balance)
			end
		end)
	)

	local function setStatus(msg: string)
		statusMsg:set(msg)
		task.delay(3, function()
			if peek(statusMsg) == msg then
				statusMsg:set("")
			end
		end)
	end

	-- One inventory row: name + held qty + sell value, with a Sell-all button.
	local function buildRow(id: string, qty: number)
		local tier = tierOf(id)
		local value = baseValueOf(id) * qty
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				-- Tier badge (left)
				scope:New("Frame")({
					Size = UDim2.fromOffset(30, 22),
					Position = UDim2.fromOffset(0, 6),
					BackgroundColor3 = Theme.Colors.Tier[tier] or Theme.Colors.TextSecondary,
					BorderSizePixel = 0,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
						scope:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							TextColor3 = Color3.new(1, 1, 1),
							FontFace = Theme.Font.Label,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Center,
							Text = "T" .. tier,
						}),
					},
				}),
				-- Name + qty/value
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(40, 4),
					Size = UDim2.new(1, -150, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = compoundName(id) .. "  ×" .. tostring(qty),
				}),
				scope:New("TextLabel")({
					Position = UDim2.fromOffset(40, 24),
					Size = UDim2.new(1, -150, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Instant-sell value: " .. formatNum(value) .. " ◈",
				}),
				-- Sell-all button (right)
				scope:New("Frame")({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(96, 36),
					BackgroundTransparency = 1,
					[Children] = {
						Components.Button(scope, {
							Text = "Sell ×" .. tostring(qty),
							OnClick = function()
								task.spawn(function()
									local earned, err = VaultController.instantSell(id, qty)
									if type(earned) == "number" and earned > 0 then
										setStatus("Sold " .. compoundName(id) .. " for " .. formatNum(earned) .. " ◈")
									else
										setStatus(tostring(err or "sell failed"))
									end
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	scope:New("ScreenGui")({
		Name = "VaultScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			scope:New("TextButton")({
				Name = "CloseBtn",
				Size = UDim2.fromOffset(36, 36),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				BackgroundTransparency = 1,
				Text = "✕",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Header,
				TextSize = 20,
				ZIndex = 20,
				[OnEvent("Activated")] = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 30),
						Position = UDim2.fromOffset(0, 6),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Header,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = "Vault",
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 16),
						Position = UDim2.fromOffset(0, 36),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Body,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = scope:Computed(function(use)
							local bal = use(balanceValue) or {}
							return formatNum(bal.pellets or 0) .. " ◈ Pellets"
						end),
					}),
				},
			}),
			-- Status line
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 18),
				Position = UDim2.fromOffset(12, 58),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				FontFace = Theme.Font.Body,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = statusMsg,
			}),
			-- Inventory list
			scope:New("ScrollingFrame")({
				Name = "InventoryPanel",
				Size = UDim2.new(1, -24, 1, -92),
				Position = UDim2.fromOffset(12, 80),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					scope:Computed(function(use)
						local vault = use(vaultValue) or {}
						local ids = {}
						for id, qty in pairs(vault) do
							if type(qty) == "number" and qty > 0 then
								table.insert(ids, id)
							end
						end
						table.sort(ids)
						if #ids == 0 then
							return {
								scope:New("TextLabel")({
									Size = UDim2.new(1, 0, 0, 40),
									BackgroundTransparency = 1,
									TextColor3 = Theme.Colors.TextSecondary,
									FontFace = Theme.Font.Body,
									TextSize = 13,
									Text = "Your vault is empty. Extract or synthesize compounds to fill it.",
								}),
							}
						end
						local rows = {}
						for _, id in ipairs(ids) do
							table.insert(rows, buildRow(id, vault[id]))
						end
						return rows
					end),
				},
			}),
		},
	})
end

function VaultScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return VaultScreen
