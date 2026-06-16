local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local PatentController = require(script.Parent.Parent.Controllers.PatentController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local doCleanup = Fusion.doCleanup

local TAB_LOG = "Formula Log"
local TAB_EXOTIC = "Exotic Registry"

local function getTier(compoundId: string): number
	local c = Compounds[compoundId]
	return c and c.tier or 1
end

local function formatNum(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	end
	if n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local FormulaLogScreen = {}
local _scope = nil

function FormulaLogScreen.open()
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local formulaLogValue = scope:Value(st.formulaLog)
	local patentsValue = scope:Value(st.patents)
	local exoticRegistryValue = scope:Value(st.exoticRegistry)
	local activeTab = scope:Value(TAB_LOG)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.formulaLog ~= nil then
				formulaLogValue:set(patch.formulaLog)
			end
			if patch.patents ~= nil then
				patentsValue:set(patch.patents)
			end
			if patch.exoticRegistry ~= nil then
				exoticRegistryValue:set(patch.exoticRegistry)
			end
		end)
	)

	local function buildLogEntry(entry: { compoundId: string, recipeId: string?, discoveredAt: number })
		local cid = entry.compoundId
		local tier = getTier(cid)
		local patent = patentsValue -- will be read below
		local patentState = (StateController.get().patents[cid] or {}).state or "UNCLAIMED"
		local patentColor = Theme.Colors.TextSecondary
		if patentState == "HELD" or patentState == "IMMUNE" then
			patentColor = Theme.Colors.Accent
		elseif patentState == "CHALLENGED" then
			patentColor = Theme.Colors.Warning
		end
		local decay = PatentController.getDecayProjection(cid)

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, decay and 56 or 44),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 84),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 2),
				}),
				scope:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = cid,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = patentColor,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = patentState,
				}),
				decay and scope:New("TextLabel")({
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 12),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = decay,
				}) or scope:New("Frame")({
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 0),
					BackgroundTransparency = 1,
				}),
				-- TierBadge positioned right
				scope:New("Frame")({
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -30, 0, 8),
					BackgroundColor3 = Theme.Colors.Tier[tier] or Theme.Colors.TextSecondary,
					BorderSizePixel = 0,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
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
			},
		})
	end

	local function buildExoticEntry(exoticId: string, data: { unitCount: number, currentValue: number })
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 12),
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
					Size = UDim2.new(1, -36, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = exoticId,
				}),
				scope:New("TextLabel")({
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = formatNum(data.currentValue) .. " ◈ · " .. tostring(data.unitCount) .. " units",
				}),
				-- T7 badge
				scope:New("Frame")({
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -30, 0, 8),
					BackgroundColor3 = Theme.Colors.Tier[7],
					BorderSizePixel = 0,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
						scope:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							TextColor3 = Color3.new(1, 1, 1),
							FontFace = Theme.Font.Label,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Center,
							Text = "T7",
						}),
					},
				}),
			},
		})
	end

	-- Tab bar
	local tabBtns = {}
	for _, t in ipairs({ TAB_LOG, TAB_EXOTIC }) do
		local tab = t
		table.insert(
			tabBtns,
			scope:New("TextButton")({
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundColor3 = scope:Computed(function(use)
					return use(activeTab) == tab and Theme.Colors.AccentDim or Theme.Colors.Surface
				end),
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = scope:Computed(function(use)
							return use(activeTab) == tab and Theme.Colors.Accent or Theme.Colors.TextSecondary
						end),
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = tab,
					}),
				},
				[OnEvent("Activated")] = function()
					activeTab:set(tab)
				end,
			})
		)
	end

	scope:New("ScreenGui")({
		Name = "FormulaLogScreen",
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
						Text = "Research Log",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Tabs",
				Size = UDim2.new(1, 0, 0, 44),
				Position = UDim2.fromOffset(0, 56),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Horizontal }),
					table.unpack(tabBtns),
				},
			}),
			-- Formula Log tab
			scope:New("ScrollingFrame")({
				Name = "LogPanel",
				Size = UDim2.new(1, -24, 1, -112),
				Position = UDim2.fromOffset(12, 108),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				Visible = scope:Computed(function(use)
					return use(activeTab) == TAB_LOG
				end),
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					scope:Computed(function(use)
						local log = use(formulaLogValue)
						local rows = {}
						for _, entry in ipairs(log) do
							table.insert(rows, buildLogEntry(entry))
						end
						return rows
					end),
				},
			}),
			-- Exotic Registry tab
			scope:New("ScrollingFrame")({
				Name = "ExoticPanel",
				Size = UDim2.new(1, -24, 1, -112),
				Position = UDim2.fromOffset(12, 108),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				Visible = scope:Computed(function(use)
					return use(activeTab) == TAB_EXOTIC
				end),
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					scope:Computed(function(use)
						local registry = use(exoticRegistryValue)
						local rows = {}
						for id, data in pairs(registry) do
							table.insert(rows, buildExoticEntry(id, data))
						end
						return rows
					end),
				},
			}),
		},
	})
end

function FormulaLogScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return FormulaLogScreen
