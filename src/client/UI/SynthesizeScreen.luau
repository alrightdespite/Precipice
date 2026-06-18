local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local LabAnalysis = require(ReplicatedStorage.Shared.Core.LabAnalysis)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local LabController = require(script.Parent.Parent.Controllers.LabController)
local SlotController = require(script.Parent.Parent.Controllers.SlotController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local function getTier(compoundId: string): number
	local c = Compounds[compoundId]
	return c and c.tier or 1
end

-- Compact vault browser popup
local function makeVaultBrowser(scope, vaultValue, onSelect, onClose, mode, formulaLogValue)
	local entries = scope:Computed(function(use)
		local vault = use(vaultValue)
		if not vault then
			return {}
		end
		local list = {}
		if mode == "extraction" then
			local log = formulaLogValue and use(formulaLogValue) or {}
			local seen = {}
			for id, entry in pairs(Compounds) do
				if entry.starter then
					table.insert(list, { id = id, qty = vault[id] or 0, tier = getTier(id) })
					seen[id] = true
				end
			end
			for _, logEntry in ipairs(log) do
				local cid = logEntry.compoundId
				local compound = Compounds[cid]
				if compound and compound.tier == 1 and not seen[cid] then
					table.insert(list, { id = cid, qty = vault[cid] or 0, tier = 1 })
					seen[cid] = true
				end
			end
		else
			for id, qty in pairs(vault) do
				if qty > 0 then
					table.insert(list, { id = id, qty = qty, tier = getTier(id) })
				end
			end
		end
		table.sort(list, function(a, b)
			local ta = (Compounds[a.id] and Compounds[a.id].tier) or 0
			local tb = (Compounds[b.id] and Compounds[b.id].tier) or 0
			if ta ~= tb then
				return ta < tb
			end
			return a.id < b.id
		end)
		return list
	end)

	local rows = scope:Computed(function(use)
		local list = use(entries)
		local result = {}
		for i, entry in ipairs(list) do
			local tier = entry.tier
			table.insert(
				result,
				scope:New("TextButton")({
					Size = UDim2.new(1, 0, 0, 40),
					BackgroundColor3 = Theme.Colors.SurfaceRaised,
					BorderSizePixel = 0,
					Text = "",
					LayoutOrder = i,
					[OnEvent("Activated")] = function()
						onSelect(entry.id)
						onClose()
					end,
					[Children] = {
						scope:New("TextLabel")({
							Size = UDim2.new(1, -52, 1, 0),
							Position = UDim2.fromOffset(8, 0),
							BackgroundTransparency = 1,
							TextColor3 = Theme.Colors.TextPrimary,
							FontFace = Theme.Font.Label,
							TextSize = 13,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = (Compounds[entry.id] and Compounds[entry.id].name or entry.id) .. " ×" .. entry.qty,
						}),
						scope:New("Frame")({
							Size = UDim2.fromOffset(28, 20),
							Position = UDim2.new(1, -32, 0.5, -10),
							BackgroundColor3 = Theme.Colors.Tier[tier] or Theme.Colors.TextSecondary,
							BorderSizePixel = 0,
							[Children] = {
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
			)
		end
		return result
	end)

	local listFrame = scope:New("ScrollingFrame")({
		Name = "List",
		Size = UDim2.new(1, -16, 1, -56),
		Position = UDim2.fromOffset(8, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ZIndex = 21,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
			}),
			rows,
		},
	})

	return scope:New("Frame")({
		Name = "VaultBrowser",
		Size = UDim2.new(0.9, 0, 0.6, 0),
		Position = UDim2.new(0.05, 0, 0.2, 0),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 20,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			scope:New("TextButton")({
				Name = "Close",
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.new(1, -36, 0, 4),
				BackgroundTransparency = 1,
				Text = "✕",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 16,
				ZIndex = 21,
				[OnEvent("Activated")] = onClose,
			}),
			scope:New("TextLabel")({
				Name = "Title",
				Text = "Select compound",
				Size = UDim2.new(1, -44, 0, 40),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Header,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				[Children] = {
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 12) }),
				},
			}),
			listFrame,
		},
	})
end

local SynthesizeScreen = {}
local _scope = nil

function SynthesizeScreen.open(uiController, slotMode, slotIndex)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local vaultValue = scope:Value(st.vault)
	local formulaLogValue = scope:Value(st.formulaLog)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.vault ~= nil then
				vaultValue:set(patch.vault)
			end
			if patch.formulaLog ~= nil then
				formulaLogValue:set(patch.formulaLog)
			end
		end)
	)

	local input1 = scope:Value(nil :: string?)
	local input2 = scope:Value(nil :: string?)
	local showBrowser = scope:Value(false)
	local pickerTarget = scope:Value(1) -- which picker is open (1 or 2)
	local statusMsg = scope:Value("")
	local isLoading = scope:Value(false)

	local buttonState = scope:Computed(function(use)
		return LabController.getButtonState(use(input1), use(input2))
	end)

	local feeText = scope:Computed(function(use)
		local bs = use(buttonState)
		if bs == "ANALYZE" then
			local i1, i2 = use(input1), use(input2)
			if i1 and i2 then
				local ok, fee = pcall(LabAnalysis.getFee, i1, i2)
				if ok then
					return string.format("Analyze — %d ◈", fee)
				end
			end
		end
		if bs == "SYNTHESIZE" or bs == "SYNTHESIZE_VARIABLE" then
			return "Synthesize"
		end
		if bs == "SELECT_INPUTS" then
			return "Select two compounds"
		end
		if bs == "JOINT_REQUIRED" then
			return "Joint research required"
		end
		return "Cannot analyze"
	end)

	local actionDisabled = scope:Computed(function(use)
		local bs = use(buttonState)
		return bs == "SELECT_INPUTS" or bs == "JOINT_REQUIRED" or bs == "INVALID" or use(isLoading)
	end)

	-- Formula log rows (bottom panel)
	local logEntries = scope:Computed(function(use)
		local log = use(formulaLogValue)
		local sorted = table.clone(log)
		table.sort(sorted, function(a, b)
			return a.discoveredAt > b.discoveredAt
		end)
		return sorted
	end)

	local function buildLogRow(entry: { compoundId: string, recipeId: string?, discoveredAt: number })
		local tier = getTier(entry.compoundId)
		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 80),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = entry.compoundId,
				}),
				Components.TierBadge(scope, { Tier = tier }),
				Components.Button(scope, {
					Text = "Synth →",
					Size = UDim2.fromOffset(72, 30),
					Style = "secondary",
					OnClick = function()
						-- Pre-fill inputs if a valid recipe is known
						if entry.recipeId then
							local parts = entry.recipeId:split("+")
							if parts[1] and parts[2] then
								input1:set(parts[1])
								input2:set(parts[2])
							end
						end
					end,
				}),
			},
		})
	end

	local logRows = scope:Computed(function(use)
		local entries = use(logEntries)
		local rows = {}
		for _, entry in ipairs(entries) do
			table.insert(rows, buildLogRow(entry))
		end
		return rows
	end)

	-- Picker card
	local function makePickerCard(pickerIdx: number, inputValue)
		local label = scope:Computed(function(use)
			local v = use(inputValue)
			return v or "Select compound"
		end)
		local hasValue = scope:Computed(function(use)
			return use(inputValue) ~= nil
		end)
		local tierVal = scope:Computed(function(use)
			local v = use(inputValue)
			return v and getTier(v) or nil
		end)

		return scope:New("TextButton")({
			Name = "Picker" .. pickerIdx,
			Size = UDim2.new(0.48, 0, 0, 64),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			Text = "",
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIStroke")({
					Color = Theme.Colors.SurfaceRaised,
					Thickness = 1,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -36, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = scope:Computed(function(use)
						return use(hasValue) and Theme.Colors.TextPrimary or Theme.Colors.TextSecondary
					end),
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = label,
				}),
				-- Tier badge (shown if compound selected)
				scope:New("Frame")({
					Size = UDim2.fromOffset(28, 20),
					Position = UDim2.new(1, -28, 0.5, -10),
					BackgroundColor3 = scope:Computed(function(use)
						local t = use(tierVal)
						return t and Theme.Colors.Tier[t] or Theme.Colors.Surface
					end),
					BorderSizePixel = 0,
					Visible = hasValue,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
						scope:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							TextColor3 = Color3.new(1, 1, 1),
							FontFace = Theme.Font.Label,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Center,
							Text = scope:Computed(function(use)
								local t = use(tierVal)
								return t and ("T" .. t) or ""
							end),
						}),
					},
				}),
			},
			[OnEvent("Activated")] = function()
				pickerTarget:set(pickerIdx)
				showBrowser:set(true)
			end,
		})
	end

	scope:New("ScreenGui")({
		Name = "SynthesizeScreen",
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
			-- Header
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
						Text = "Lab",
					}),
				},
			}),
			-- Input panel
			scope:New("Frame")({
				Name = "InputPanel",
				Size = UDim2.new(1, -24, 0, 180),
				Position = UDim2.fromOffset(12, 64),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 12),
						PaddingBottom = UDim.new(0, 12),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 10),
					}),
					-- Pickers row
					scope:New("Frame")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 64),
						BackgroundTransparency = 1,
						[Children] = {
							makePickerCard(1, input1),
							scope:New("Frame")({ Size = UDim2.new(0.04, 0, 1, 0), BackgroundTransparency = 1 }),
							makePickerCard(2, input2),
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 0),
							}),
						},
					}),
					-- Action button
					scope:New("Frame")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							Components.Button(scope, {
								Text = feeText,
								Disabled = actionDisabled,
								OnClick = function()
									local bs = peek(buttonState)
									local i1, i2 = peek(input1), peek(input2)
									if not i1 or not i2 then
										return
									end
									isLoading:set(true)
									statusMsg:set("")
									if bs == "ANALYZE" then
										local ok, result = LabController.analyze(i1, i2)
										isLoading:set(false)
										if ok then
											statusMsg:set("Analysis complete.")
										else
											statusMsg:set(tostring(result))
										end
									elseif bs == "SYNTHESIZE" or bs == "SYNTHESIZE_VARIABLE" then
										-- Phase 12B: just analyze for now; full synth needs slot selection
										local ok, result = LabController.analyze(i1, i2)
										isLoading:set(false)
										if ok then
											statusMsg:set("Done.")
										else
											statusMsg:set(tostring(result))
										end
									end
								end,
							}),
						},
					}),
					-- Status message
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = statusMsg,
					}),
				},
			}),
			-- Formula Log
			scope:New("Frame")({
				Name = "FormulaLog",
				Size = UDim2.new(1, -24, 1, -276),
				Position = UDim2.fromOffset(12, 256),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Label,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "FORMULA LOG",
					}),
					scope:New("ScrollingFrame")({
						Size = UDim2.new(1, 0, 1, -28),
						Position = UDim2.fromOffset(0, 28),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 4),
							}),
							scope:Computed(function(use)
								return use(logRows)
							end),
						},
					}),
				},
			}),
			-- Vault browser overlay
			scope:New("Frame")({
				Name = "BrowserOverlay",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ZIndex = 19,
				Visible = showBrowser,
				[Children] = {
					makeVaultBrowser(scope, vaultValue, function(id)
						if slotMode == "extraction" then
							SlotController.startExtraction(slotIndex, id)
							showBrowser:set(false)
							if uiController then
								uiController.openScreen("Home")
							end
						else
							local target = peek(pickerTarget)
							if target == 1 then
								input1:set(id)
							else
								input2:set(id)
							end
						end
					end, function()
						showBrowser:set(false)
					end, slotMode, formulaLogValue),
				},
			}),
		},
	})
end

function SynthesizeScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return SynthesizeScreen
