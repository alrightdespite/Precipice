local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local GAMEPASS_NAMES = {
	expandedLab = "Expanded Lab (10 slots)",
	extendedOffline = "Extended Offline Income",
	compoundArchive = "Compound Archive",
}

local SettingsScreen = {}
local _scope = nil

function SettingsScreen.open()
	if _scope then return end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local musicEnabled = scope:Value(true)
	local sfxEnabled = scope:Value(true)
	local gamepassesValue = scope:Value(st.gamepasses)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.gamepasses ~= nil then gamepassesValue:set(patch.gamepasses) end
		end)
	)

	local function makeToggle(label: string, stateValue)
		local isOn = stateValue
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -64, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = label,
				}),
				-- Toggle button
				scope:New("TextButton")({
					Size = UDim2.fromOffset(52, 28),
					Position = UDim2.new(1, -52, 0.5, -14),
					BackgroundColor3 = scope:Computed(function(use)
						return use(isOn) and Theme.Colors.Success or Theme.Colors.SurfaceRaised
					end),
					BorderSizePixel = 0,
					Text = "",
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						-- Knob
						scope:New("Frame")({
							Size = UDim2.fromOffset(20, 20),
							Position = scope:Computed(function(use)
								return use(isOn) and UDim2.new(1, -24, 0.5, -10) or UDim2.new(0, 4, 0.5, -10)
							end),
							BackgroundColor3 = Color3.new(1, 1, 1),
							BorderSizePixel = 0,
							[Children] = {
								scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
							},
						}),
					},
					[OnEvent("Activated")] = function()
						isOn:set(not peek(isOn))
					end,
				}),
			},
		})
	end

	local function makeGamepassRow(key: string, name: string)
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = name,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = scope:Computed(function(use)
						local owned = use(gamepassesValue)[key]
						return owned and Theme.Colors.Success or Theme.Colors.TextSecondary
					end),
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = scope:Computed(function(use)
						return use(gamepassesValue)[key] and "Owned" or "Not owned"
					end),
				}),
			},
		})
	end

	scope:New("ScreenGui")({
		Name = "SettingsScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Header,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = "Settings",
					}),
				},
			}),
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, -24, 1, -72),
				Position = UDim2.fromOffset(12, 64),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					-- Audio section
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Label,
						TextSize = 11,
						Text = "AUDIO",
					}),
					scope:New("Frame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 4),
							}),
							makeToggle("Music", musicEnabled),
							makeToggle("Sound Effects", sfxEnabled),
						},
					}),
					-- Gamepasses section
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Label,
						TextSize = 11,
						Text = "GAMEPASSES",
					}),
					scope:New("Frame")({
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = (function()
							local rows = {
								scope:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Vertical,
									Padding = UDim.new(0, 4),
								}),
							}
							for key, name in pairs(GAMEPASS_NAMES) do
								table.insert(rows, makeGamepassRow(key, name))
							end
							return rows
						end)(),
					}),
					-- Version
					scope:New("TextLabel")({
						LayoutOrder = 5,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = "PRECIPICE — Deepwell Studios",
					}),
				},
			}),
		},
	})
end

function SettingsScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return SettingsScreen
