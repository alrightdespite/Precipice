local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local LabAnalysis = require(ReplicatedStorage.Shared.Core.LabAnalysis)
local RecipeResolver = require(ReplicatedStorage.Shared.Core.RecipeResolver)
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
	local slotsValue = scope:Value(st.slots)
	local slotCapValue = scope:Value(st.slotCap)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.vault ~= nil then
				vaultValue:set(patch.vault)
			end
			if patch.formulaLog ~= nil then
				formulaLogValue:set(patch.formulaLog)
			end
			if patch.slots ~= nil then
				slotsValue:set(patch.slots)
			end
			if patch.slotCap ~= nil then
				slotCapValue:set(patch.slotCap)
			end
		end)
	)

	local input1 = scope:Value(nil :: string?)
	local input2 = scope:Value(nil :: string?)
	local showBrowser = scope:Value(false)
	local pickerTarget = scope:Value(1) -- which picker is open (1 or 2)
	local statusMsg = scope:Value("")
	local isLoading = scope:Value(false)

	-- Synthesis config modal (slot routing + variant picker + Stabilized toggle, §7/§8).
	local showSynthConfig = scope:Value(false)
	local selectedSlot = scope:Value(nil :: number?)
	local stabilized = scope:Value(false)
	local selectedVariant = scope:Value(nil :: string?)
	local synthStatus = scope:Value("")

	-- Slot indices that are free to take a new run (EMPTY or absent), within the personal cap.
	local freeSlots = scope:Computed(function(use)
		local slots = use(slotsValue) or {}
		local cap = use(slotCapValue) or 5
		local free = {}
		for i = 1, cap do
			local slot = slots[i]
			if slot == nil or (slot :: any).state == "EMPTY" then
				table.insert(free, i)
			end
		end
		return free
	end)

	local buttonState = scope:Computed(function(use)
		return LabController.getButtonState(use(input1), use(input2))
	end)

	local feeText = scope:Computed(function(use)
		local bs = use(buttonState)
		if bs == "ANALYZE" then
			local i1, i2 = use(input1), use(input2)
			if i1 and i2 then
				-- getFee takes the lower input tier + prestige level (not compound IDs).
				local minTier = math.min(getTier(i1), getTier(i2))
				local ok, fee = pcall(LabAnalysis.getFee, minTier, 0)
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
			if v == nil then
				return "Select compound"
			end
			return (Compounds[v] and Compounds[v].name) or v
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

	-- ── Synthesis config modal ────────────────────────────────────────────────
	local function nameOf(id: string): string
		return (Compounds[id] and Compounds[id].name) or id
	end

	local isVariable = scope:Computed(function(use)
		local i1, i2 = use(input1), use(input2)
		return i1 ~= nil and i2 ~= nil and RecipeResolver.isVariablePair(i1, i2)
	end)

	-- Discovered result variants of the current pair (drives the variant picker).
	local discoveredVariants = scope:Computed(function(use)
		local i1, i2 = use(input1), use(input2)
		if not i1 or not i2 then
			return {}
		end
		local discovered = {}
		for _, e in ipairs(use(formulaLogValue)) do
			discovered[e.compoundId] = true
		end
		local out = {}
		for _, rid in ipairs(RecipeResolver.getResultIds(i1, i2)) do
			if discovered[rid] then
				table.insert(out, rid)
			end
		end
		return out
	end)

	local resultPreview = scope:Computed(function(use)
		local i1, i2 = use(input1), use(input2)
		if not i1 or not i2 then
			return ""
		end
		local names = {}
		for _, rid in ipairs(RecipeResolver.getResultIds(i1, i2)) do
			table.insert(names, nameOf(rid))
		end
		return "→ " .. table.concat(names, "  /  ")
	end)

	local confirmDisabled = scope:Computed(function(use)
		if use(selectedSlot) == nil then
			return true
		end
		-- Forcing a specific variant requires choosing one (Stabilized only, §8).
		if use(isVariable) and use(stabilized) and use(selectedVariant) == nil then
			return true
		end
		return false
	end)

	local slotChips = scope:Computed(function(use)
		local free = use(freeSlots)
		if #free == 0 then
			return {
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.Danger,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "All slots are busy — finish or cancel a run first.",
				}),
			}
		end
		local chips = {}
		for i, idx in ipairs(free) do
			local thisIdx = idx
			chips[i] = scope:New("TextButton")({
				Size = UDim2.fromOffset(46, 36),
				LayoutOrder = i,
				BackgroundColor3 = scope:Computed(function(u)
					return u(selectedSlot) == thisIdx and Theme.Colors.Accent or Theme.Colors.SurfaceRaised
				end),
				BorderSizePixel = 0,
				FontFace = Theme.Font.Value,
				TextSize = 14,
				Text = "#" .. thisIdx,
				TextColor3 = scope:Computed(function(u)
					return u(selectedSlot) == thisIdx and Theme.Colors.TextPrimary or Theme.Colors.TextSecondary
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				},
				[OnEvent("Activated")] = function()
					selectedSlot:set(thisIdx)
				end,
			})
		end
		return chips
	end)

	local variantRows = scope:Computed(function(use)
		if not use(stabilized) then
			return {}
		end
		local rows = {}
		for i, rid in ipairs(use(discoveredVariants)) do
			local thisRid = rid
			rows[i] = scope:New("TextButton")({
				Size = UDim2.new(1, 0, 0, 36),
				LayoutOrder = i,
				BackgroundColor3 = scope:Computed(function(u)
					return u(selectedVariant) == thisRid and Theme.Colors.AccentDim or Theme.Colors.SurfaceRaised
				end),
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -40, 1, 0),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = nameOf(thisRid),
					}),
					Components.TierBadge(scope, { Tier = getTier(thisRid) }),
				},
				[OnEvent("Activated")] = function()
					selectedVariant:set(thisRid)
				end,
			})
		end
		return rows
	end)

	local variantNote = scope:Computed(function(use)
		if use(stabilized) then
			return "Forces your chosen variant — ×1.5 timer (§8)."
		end
		return "Produces this week's active variant (standard timer)."
	end)

	local function confirmSynth()
		local slot = peek(selectedSlot)
		local i1, i2 = peek(input1), peek(input2)
		if not slot or not i1 or not i2 then
			return
		end
		local stab = peek(stabilized)
		local desired = if stab then peek(selectedVariant) else nil
		synthStatus:set("Starting…")
		local ok, err = SlotController.startSynthesis(slot, i1, i2, stab, desired)
		if ok then
			synthStatus:set("")
			showSynthConfig:set(false)
			statusMsg:set(string.format("Synthesis started in slot #%d.", slot))
			if uiController then
				uiController.openScreen("Home")
			end
		else
			synthStatus:set(tostring(err))
		end
	end

	local synthConfigOverlay = scope:New("Frame")({
		Name = "SynthConfigOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		ZIndex = 22,
		Visible = showSynthConfig,
		[Children] = {
			scope:New("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				ZIndex = 23,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 16),
						PaddingRight = UDim.new(0, 16),
						PaddingTop = UDim.new(0, 16),
						PaddingBottom = UDim.new(0, 16),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					scope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Header,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Synthesize",
					}),
					scope:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Body,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = resultPreview,
					}),
					-- Target slot section
					scope:New("TextLabel")({
						LayoutOrder = 3,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextSecondary,
						FontFace = Theme.Font.Label,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "TARGET SLOT",
					}),
					scope:New("Frame")({
						LayoutOrder = 4,
						Size = UDim2.new(1, 0, 0, 36),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							slotChips,
						},
					}),
					-- Variant section (variable pairs only)
					scope:New("Frame")({
						Name = "VariantSection",
						LayoutOrder = 5,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Visible = isVariable,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 6),
							}),
							-- Stabilized toggle
							scope:New("TextButton")({
								LayoutOrder = 1,
								Size = UDim2.new(1, 0, 0, 36),
								BackgroundColor3 = scope:Computed(function(use)
									return use(stabilized) and Theme.Colors.AccentDim or Theme.Colors.SurfaceRaised
								end),
								BorderSizePixel = 0,
								Text = "",
								[Children] = {
									scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
									scope:New("UIPadding")({
										PaddingLeft = UDim.new(0, 10),
										PaddingRight = UDim.new(0, 10),
									}),
									scope:New("TextLabel")({
										Size = UDim2.new(1, -44, 1, 0),
										BackgroundTransparency = 1,
										TextColor3 = Theme.Colors.TextPrimary,
										FontFace = Theme.Font.Label,
										TextSize = 13,
										TextXAlignment = Enum.TextXAlignment.Left,
										Text = "Stabilized Synthesis (×1.5 timer)",
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(1, 0.5),
										Position = UDim2.fromScale(1, 0.5),
										Size = UDim2.fromOffset(40, 20),
										BackgroundTransparency = 1,
										TextColor3 = scope:Computed(function(use)
											return use(stabilized) and Theme.Colors.Accent or Theme.Colors.TextSecondary
										end),
										FontFace = Theme.Font.Value,
										TextSize = 13,
										TextXAlignment = Enum.TextXAlignment.Right,
										Text = scope:Computed(function(use)
											return use(stabilized) and "ON" or "OFF"
										end),
									}),
								},
								[OnEvent("Activated")] = function()
									local n = not peek(stabilized)
									stabilized:set(n)
									if not n then
										selectedVariant:set(nil)
									end
								end,
							}),
							scope:New("TextLabel")({
								LayoutOrder = 2,
								Size = UDim2.new(1, 0, 0, 16),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextSecondary,
								FontFace = Theme.Font.Body,
								TextSize = 11,
								TextXAlignment = Enum.TextXAlignment.Left,
								Text = variantNote,
							}),
							-- Variant picker (shown when Stabilized)
							scope:New("Frame")({
								LayoutOrder = 3,
								Size = UDim2.fromScale(1, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								[Children] = {
									scope:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										SortOrder = Enum.SortOrder.LayoutOrder,
										Padding = UDim.new(0, 4),
									}),
									variantRows,
								},
							}),
						},
					}),
					-- Status
					scope:New("TextLabel")({
						LayoutOrder = 6,
						Size = UDim2.new(1, 0, 0, 16),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Danger,
						FontFace = Theme.Font.Body,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = synthStatus,
					}),
					-- Action buttons
					scope:New("Frame")({
						LayoutOrder = 7,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 8),
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
							}),
							scope:New("Frame")({
								LayoutOrder = 1,
								Size = UDim2.fromOffset(110, 44),
								BackgroundTransparency = 1,
								[Children] = {
									Components.Button(scope, {
										Text = "Cancel",
										Style = "secondary",
										OnClick = function()
											showSynthConfig:set(false)
										end,
									}),
								},
							}),
							scope:New("Frame")({
								LayoutOrder = 2,
								Size = UDim2.fromOffset(150, 44),
								BackgroundTransparency = 1,
								[Children] = {
									Components.Button(scope, {
										Text = "Synthesize",
										Disabled = confirmDisabled,
										OnClick = confirmSynth,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	})

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
									if bs == "ANALYZE" then
										isLoading:set(true)
										statusMsg:set("")
										local ok, result = LabController.analyze(i1, i2)
										isLoading:set(false)
										statusMsg:set(ok and "Analysis complete." or tostring(result))
									elseif bs == "SYNTHESIZE" or bs == "SYNTHESIZE_VARIABLE" then
										-- Open the synthesis config modal: slot routing + (variable pairs)
										-- variant picker + Stabilized toggle (§7/§8). Prefer the slot the
										-- player launched from (if still free), else the first free slot.
										local free = peek(freeSlots)
										local default = nil
										if slotIndex and table.find(free, slotIndex) then
											default = slotIndex
										elseif #free > 0 then
											default = free[1]
										end
										selectedSlot:set(default)
										stabilized:set(false)
										selectedVariant:set(nil)
										synthStatus:set("")
										showSynthConfig:set(true)
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
			-- Synthesis config modal overlay
			synthConfigOverlay,
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
