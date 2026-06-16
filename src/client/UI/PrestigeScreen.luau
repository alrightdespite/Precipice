local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local PrestigeController = require(script.Parent.Parent.Controllers.PrestigeController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

-- §22 prestige bonus table (hardcoded per spec)
local PRESTIGE_BONUSES = {
	{ level = 1, desc = "+1 slot, -40% lab fees" },
	{ level = 2, desc = "+10% passive income" },
	{ level = 3, desc = "+1 slot" },
	{ level = 4, desc = "+5% passive income" },
	{ level = 5, desc = "+1 slot" },
	{ level = 6, desc = "+5% passive income" },
}

local RESET_ITEMS = {
	"Vault contents",
	"Active slots",
	"Daily streak",
	"Contracts",
	"Current rank run",
}

local KEEP_ITEMS = {
	"Formula log",
	"Lifetime rank",
	"Sprint history",
	"Cosmetics",
	"Pellets (floored to 500)",
}

local PrestigeScreen = {}
local _scope = nil
local _uiController = nil

function PrestigeScreen.open(uiController)
	if _scope then
		return
	end
	_uiController = uiController
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local rankValue = scope:Value(st.rank)
	local prestigeLevel = scope:Computed(function(use)
		-- Prestige level not yet in state schema (Phase 12C); stub to 0
		return 0
	end)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.rank ~= nil then
				rankValue:set(patch.rank)
			end
		end)
	)

	local blockers = scope:Value({} :: { string })
	local isLoading = scope:Value(false)
	local confirmStep = scope:Value(false) -- two-step confirm
	local statusMsg = scope:Value("")

	local hasBlockers = scope:Computed(function(use)
		return #use(blockers) > 0
	end)

	-- Check blockers on open
	task.spawn(function()
		local ok, result = PrestigeController.request()
		if ok then
			if type(result) == "table" then
				blockers:set(result)
			else
				blockers:set({})
			end
		end
	end)

	local function buildListItem(text: string, color: Color3, icon: string)
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
				}),
				scope:New("TextLabel")({
					Size = UDim2.fromOffset(16, 16),
					BackgroundTransparency = 1,
					TextColor3 = color,
					FontFace = Theme.Font.Label,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = icon,
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -24, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = color,
					FontFace = Theme.Font.Body,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = text,
				}),
			},
		})
	end

	local function buildSection(title: string, items: { string }, color: Color3, icon: string)
		local rows = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
		}
		for _, item in ipairs(items) do
			table.insert(rows, buildListItem(item, color, icon))
		end
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Label,
					TextSize = 11,
					Text = title,
				}),
				scope:New("Frame")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = rows,
				}),
			},
		})
	end

	-- Bonus rows for next prestige level
	local nextBonus = scope:Computed(function(use)
		local lvl = use(prestigeLevel) + 1
		for _, b in ipairs(PRESTIGE_BONUSES) do
			if b.level == lvl then
				return b.desc
			end
		end
		return "+5% passive income"
	end)

	scope:New("ScreenGui")({
		Name = "PrestigeScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Bg",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Background,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				[Children] = {
					-- Close X
					scope:New("TextButton")({
						Name = "Close",
						Size = UDim2.fromOffset(44, 44),
						Position = UDim2.new(1, -48, 0, 4),
						BackgroundTransparency = 1,
						Text = "✕",
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Header,
						TextSize = 20,
						ZIndex = 10,
						[OnEvent("Activated")] = function()
							if uiController then
								uiController.openScreen("Home")
							end
						end,
					}),
					scope:New("ScrollingFrame")({
						Size = UDim2.new(1, -24, 1, 0),
						Position = UDim2.fromOffset(12, 0),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						[Children] = {
							scope:New("UIPadding")({ PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 24) }),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 16),
							}),
							-- Title
							scope:New("TextLabel")({
								LayoutOrder = 1,
								Size = UDim2.new(1, 0, 0, 56),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextPrimary,
								FontFace = Theme.Font.Header,
								TextSize = 36,
								TextXAlignment = Enum.TextXAlignment.Center,
								Text = "Prestige",
							}),
							-- Level
							scope:New("TextLabel")({
								LayoutOrder = 2,
								Size = UDim2.new(1, 0, 0, 28),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextSecondary,
								FontFace = Theme.Font.Label,
								TextSize = 14,
								TextXAlignment = Enum.TextXAlignment.Center,
								Text = scope:Computed(function(use)
									return "Level " .. use(prestigeLevel) .. " → " .. (use(prestigeLevel) + 1)
								end),
							}),
							-- Next bonus
							scope:New("Frame")({
								LayoutOrder = 3,
								Size = UDim2.new(1, 0, 0, 44),
								BackgroundColor3 = Theme.Colors.AccentDim,
								BorderSizePixel = 0,
								[Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
										PaddingTop = UDim.new(0, 8),
									}),
									scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 2) }),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 14),
										BackgroundTransparency = 1,
										TextColor3 = Theme.Colors.TextSecondary,
										FontFace = Theme.Font.Label,
										TextSize = 10,
										Text = "NEXT LEVEL BONUS",
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, 0, 0, 18),
										BackgroundTransparency = 1,
										TextColor3 = Theme.Colors.Accent,
										FontFace = Theme.Font.Label,
										TextSize = 13,
										Text = nextBonus,
									}),
								},
							}),
							-- Reset / Keep sections
							scope:New("Frame")({
								LayoutOrder = 4,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										VerticalAlignment = Enum.VerticalAlignment.Top,
										Padding = UDim.new(0, 12),
									}),
									scope:New("Frame")({
										Size = UDim2.new(0.5, -6, 0, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										[Children] = {
											buildSection("YOU LOSE", RESET_ITEMS, Theme.Colors.TextSecondary, "–"),
										},
									}),
									scope:New("Frame")({
										Size = UDim2.new(0.5, -6, 0, 0),
										AutomaticSize = Enum.AutomaticSize.Y,
										BackgroundTransparency = 1,
										[Children] = {
											buildSection("YOU KEEP", KEEP_ITEMS, Theme.Colors.Accent, "✓"),
										},
									}),
								},
							}),
							-- Blockers
							scope:New("Frame")({
								LayoutOrder = 5,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Visible = hasBlockers,
								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 4),
									}),
									scope:New("TextLabel")({
										LayoutOrder = 1,
										Size = UDim2.new(1, 0, 0, 18),
										BackgroundTransparency = 1,
										TextColor3 = Theme.Colors.Warning,
										FontFace = Theme.Font.Label,
										TextSize = 11,
										Text = "BLOCKERS",
									}),
									scope:Computed(function(use)
										local bList = use(blockers)
										local rows = {}
										for _, b in ipairs(bList) do
											table.insert(
												rows,
												scope:New("Frame")({
													Size = UDim2.new(1, 0, 0, 28),
													BackgroundColor3 = Color3.fromHex("3B2600"),
													BorderSizePixel = 0,
													[Children] = {
														scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
														scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10) }),
														scope:New("TextLabel")({
															Size = UDim2.fromScale(1, 1),
															BackgroundTransparency = 1,
															TextColor3 = Theme.Colors.Warning,
															FontFace = Theme.Font.Body,
															TextSize = 12,
															TextXAlignment = Enum.TextXAlignment.Left,
															Text = b,
														}),
													},
												})
											)
										end
										return rows
									end),
								},
							}),
							-- Status
							scope:New("TextLabel")({
								LayoutOrder = 6,
								Size = UDim2.new(1, 0, 0, 20),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextSecondary,
								FontFace = Theme.Font.Body,
								TextSize = 12,
								TextXAlignment = Enum.TextXAlignment.Center,
								Text = statusMsg,
							}),
							-- Confirm / Prestige button
							scope:New("Frame")({
								LayoutOrder = 7,
								Size = UDim2.new(1, 0, 0, 44),
								BackgroundTransparency = 1,
								[Children] = {
									Components.Button(scope, {
										Text = scope:Computed(function(use)
											return use(confirmStep) and "Confirm — cannot be undone" or "Prestige"
										end),
										Style = scope:Computed(function(use)
											return use(confirmStep) and "danger" or "primary"
										end) :: any,
										Disabled = hasBlockers,
										OnClick = function()
											if peek(confirmStep) then
												isLoading:set(true)
												task.spawn(function()
													local ok, err = PrestigeController.confirm()
													isLoading:set(false)
													if ok then
														if uiController then
															uiController.openScreen("Home")
														end
													else
														statusMsg:set(tostring(err))
													end
													confirmStep:set(false)
												end)
											else
												confirmStep:set(true)
												statusMsg:set("Are you sure? This cannot be undone.")
											end
										end,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})
end

function PrestigeScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return PrestigeScreen
