local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local TimerMath = require(ReplicatedStorage.Shared.Core.TimerMath)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SlotController = require(script.Parent.Parent.Controllers.SlotController)
local HintController = require(script.Parent.Parent.Controllers.HintController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local NAV_TABS = { "Home", "Lab", "Market", "Log", "More" }
local SLOT_HEIGHT = 68

local function formatNum(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function getDisplayTime(slot): string
	if not slot.workRemaining or not slot.lastTickAt then
		return "--:--"
	end
	local run: TimerMath.SlotRun = {
		compoundId = slot.compoundId or "",
		workRemaining = slot.workRemaining,
		lastTickAt = slot.lastTickAt,
		mode = (slot.mode or "online") :: TimerMath.RunMode,
	}
	local secs = TimerMath.displaySeconds(run, os.time(), true)
	return formatTime(secs)
end

-- Narrow slot card for 200px left panel
local function makeSlotCard(scope, slotIndex: number, slotsValue, slotCapValue, timerSkipUsesValue, uiController)
	local slotComputed = scope:Computed(function(use)
		local s = use(slotsValue)[slotIndex]
		return s or { state = "EMPTY", isActive = false }
	end)

	local slotState = scope:Computed(function(use)
		return use(slotComputed).state
	end)

	local bgColor = scope:Computed(function(use)
		local st = use(slotState)
		return (st == "RUNNING" or st == "DONE" or st == "REVEALING") and Theme.Colors.SurfaceRaised
			or Theme.Colors.Surface
	end)

	local accentColor = scope:Computed(function(use)
		local slot = use(slotComputed)
		if slot.state == "EMPTY" then
			return Theme.Colors.Surface
		end
		-- Tier-based accent could derive from Compounds[slot.compoundId].tier later; default for now.
		local tier = 1
		return Theme.Colors.Tier[tier] or Theme.Colors.Accent
	end)

	local timerValue = scope:Value("--:--")
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			local slot = peek(slotComputed)
			if slot.state == "RUNNING" then
				timerValue:set(getDisplayTime(slot))
			end
		end)
	)

	local mainText = scope:Computed(function(use)
		local slot = use(slotComputed)
		if slot.state == "EMPTY" then
			return "Slot idle"
		elseif slot.state == "RUNNING" then
			local cid = slot.compoundId
			return cid and (Compounds[cid] and Compounds[cid].name or cid) or "Running…"
		elseif slot.state == "DONE" or slot.state == "REVEALING" then
			local cid = slot.compoundId
			return cid and (Compounds[cid] and Compounds[cid].name or cid) or "Complete"
		end
		return "—"
	end)

	local showTimer = scope:Computed(function(use)
		return use(slotState) == "RUNNING"
	end)

	local showDone = scope:Computed(function(use)
		local st = use(slotState)
		return st == "DONE" or st == "REVEALING"
	end)

	local showSkip = scope:Computed(function(use)
		if use(slotState) ~= "RUNNING" then
			return false
		end
		local uses = use(timerSkipUsesValue)
		return uses > 0
	end)

	local actionLabel = scope:Computed(function(use)
		local st = use(slotState)
		if st == "EMPTY" then
			return "Start"
		end
		if st == "RUNNING" then
			return "Skip"
		end
		if st == "DONE" or st == "REVEALING" then
			return "Reveal"
		end
		return "—"
	end)

	local function onAction()
		local slot = peek(slotComputed)
		local st = slot.state
		if st == "EMPTY" then
			if uiController then
				uiController.openScreen("Lab", "extraction", slotIndex)
			end
		elseif st == "RUNNING" then
			SlotController.skip(slotIndex, "timer")
		elseif st == "DONE" or st == "REVEALING" then
			SlotController.reveal(slotIndex)
		end
	end

	return scope:New("Frame")({
		Name = "Slot" .. slotIndex,
		Size = UDim2.new(1, 0, 0, SLOT_HEIGHT),
		BackgroundColor3 = bgColor,
		BorderSizePixel = 0,
		LayoutOrder = slotIndex,
		-- Only render slots the player actually owns (§8 cap). Hidden cards
		-- collapse out of the UIListLayout.
		Visible = scope:Computed(function(use)
			return slotIndex <= use(slotCapValue)
		end),
		ClipsDescendants = false,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			-- Left accent bar (pill, vertically centered with 12px margin)
			scope:New("Frame")({
				Name = "Accent",
				Size = UDim2.new(0, 5, 1, -12),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				BackgroundColor3 = accentColor,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusPill }),
				},
			}),
			-- Slot number (#N)
			scope:New("TextLabel")({
				Name = "SlotNum",
				Text = "#" .. slotIndex,
				Size = UDim2.new(1, -16, 0, 14),
				Position = UDim2.fromOffset(12, 6),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Body,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- Compound name (middle)
			scope:New("TextLabel")({
				Name = "Main",
				Text = mainText,
				Size = UDim2.new(1, -16, 0, 18),
				Position = UDim2.fromOffset(12, 22),
				BackgroundTransparency = 1,
				TextColor3 = scope:Computed(function(use)
					if use(slotState) == "EMPTY" then
						return Theme.Colors.TextSecondary
					end
					return Theme.Colors.TextPrimary
				end),
				FontFace = Theme.Font.Label,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			-- Timer countdown (RUNNING only)
			scope:New("TextLabel")({
				Name = "Timer",
				Text = timerValue,
				Size = UDim2.new(1, -60, 0, 14),
				Position = UDim2.fromOffset(12, 44),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				FontFace = Theme.Font.Value,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = showTimer,
			}),
			-- Done label (DONE/REVEALING)
			scope:New("TextLabel")({
				Name = "DoneLabel",
				Text = "● Ready",
				Size = UDim2.new(1, -60, 0, 14),
				Position = UDim2.fromOffset(12, 44),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Success,
				FontFace = Theme.Font.Label,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = showDone,
			}),
			-- Action button (bottom-right)
			scope:New("TextButton")({
				Name = "ActionBtn",
				Size = UDim2.fromOffset(48, 24),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -6, 1, -6),
				BackgroundColor3 = scope:Computed(function(use)
					local st = use(slotState)
					if st == "DONE" or st == "REVEALING" then
						return Theme.Colors.Success
					end
					if st == "RUNNING" and use(showSkip) then
						return Theme.Colors.Warning
					end
					return Theme.Colors.Accent
				end),
				BorderSizePixel = 0,
				Text = "",
				Visible = scope:Computed(function(use)
					local st = use(slotState)
					if st == "RUNNING" then
						return use(showSkip)
					end
					return true
				end),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("TextLabel")({
						Text = actionLabel,
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Color3.new(1, 1, 1),
						FontFace = Theme.Font.Label,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
				},
				[OnEvent("Activated")] = onAction,
			}),
		},
	})
end

-- HUD bar (Zone A, 52px)
local function makeHUD(scope, balanceValue, rankValue, uiVisible)
	return scope:New("Frame")({
		Name = "HUD",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 10,
		[Children] = {
			scope:New("Frame")({
				Name = "BottomBorder",
				Size = UDim2.new(1, 0, 0, 1),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
			}),
			-- Pellets (left)
			scope:New("Frame")({
				Name = "Pellets",
				Size = UDim2.fromOffset(130, 40),
				Position = UDim2.new(0, 12, 0.5, -20),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					scope:New("Frame")({
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = Color3.fromHex("F59E0B"),
						BorderSizePixel = 0,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						},
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromOffset(106, 24),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Value,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = scope:Computed(function(use)
							return formatNum(use(balanceValue).pellets)
						end),
					}),
				},
			}),
			-- Rank (center)
			scope:New("TextLabel")({
				Name = "Rank",
				Size = UDim2.new(0.4, 0, 1, 0),
				Position = UDim2.new(0.3, 0, 0, 0),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = scope:Computed(function(use)
					local r = use(rankValue)
					return r and r.title or "Researcher"
				end),
			}),
			-- Minimize button (world mode toggle)
			scope:New("TextButton")({
				Name = "MinimizeBtn",
				Size = UDim2.fromOffset(36, 36),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "—",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 18,
				ZIndex = 11,
				[OnEvent("Activated")] = function()
					uiVisible:set(false)
				end,
			}),
		},
	})
end

-- Bottom nav bar (Zone C, 52px)
local function makeBottomNav(scope, uiController, activeTabValue)
	local tabs = {}
	for _, name in ipairs(NAV_TABS) do
		local isActive = scope:Computed(function(use)
			return use(activeTabValue) == name
		end)
		local btn = scope:New("TextButton")({
			Name = name,
			Size = UDim2.new(1 / #NAV_TABS, 0, 1, 0),
			BackgroundColor3 = scope:Computed(function(use)
				return use(isActive) and Theme.Colors.AccentDim or Theme.Colors.Surface
			end),
			BorderSizePixel = 0,
			Text = "",
			[Children] = {
				scope:New("TextLabel")({
					Text = name,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextColor3 = scope:Computed(function(use)
						return use(isActive) and Theme.Colors.Accent or Theme.Colors.TextSecondary
					end),
					FontFace = Theme.Font.Label,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				scope:New("Frame")({
					Name = "ActiveIndicator",
					Size = UDim2.new(0.6, 0, 0, 3),
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					BackgroundColor3 = Theme.Colors.Accent,
					BorderSizePixel = 0,
					Visible = isActive,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					},
				}),
			},
			[OnEvent("Activated")] = function()
				if uiController then
					local target = name
					if target == "Lab" then
						target = "Synthesize"
					end
					if target == "Log" then
						target = "FormulaLog"
					end
					if target == "More" then
						uiController.openDrawer()
						return -- drawer is overlay; do not update activeTabValue
					end
					activeTabValue:set(name)
					uiController.openScreen(target)
				end
			end,
		})
		table.insert(tabs, btn)
	end

	return scope:New("Frame")({
		Name = "BottomNav",
		Size = UDim2.new(1, 0, 0, 52),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 10,
		[Children] = {
			scope:New("Frame")({
				Name = "TopBorder",
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromOffset(0, 0),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
			}),
			scope:New("Frame")({
				Name = "Tabs",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					table.unpack(tabs),
				},
			}),
		},
	})
end

-- Hint bar
local function makeHintBar(scope, hintValue)
	return scope:New("Frame")({
		Name = "HintBar",
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 1, -52),
		BackgroundColor3 = Theme.Colors.AccentDim,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(hintValue) ~= nil
		end),
		ZIndex = 7,
		[Children] = {
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 44),
			}),
			scope:New("TextLabel")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextPrimary,
				FontFace = Theme.Font.Body,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = scope:Computed(function(use)
					local h = use(hintValue)
					return h and h.text or ""
				end),
			}),
			scope:New("TextButton")({
				Name = "Dismiss",
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.new(1, -36, 0.5, -16),
				BackgroundTransparency = 1,
				Text = "✕",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 14,
				[OnEvent("Activated")] = function()
					local h = peek(hintValue)
					if h then
						HintController.dismiss(h.id)
					end
				end,
			}),
		},
	})
end

-- Announcement marquee (floating below HUD)
local function makeMarquee(scope, announcementsValue)
	local marqueeRef = scope:Value(nil :: TextLabel?)

	local hasAnn = scope:Computed(function(use)
		local anns = use(announcementsValue)
		return anns ~= nil and #anns > 0
	end)

	local annText = scope:Computed(function(use)
		local anns = use(announcementsValue)
		if not anns or #anns == 0 then
			return ""
		end
		return anns[#anns].message or ""
	end)

	local activeTween = nil
	table.insert(scope, function()
		if activeTween then
			activeTween:Cancel()
		end
	end)

	local obs = scope:Observer(announcementsValue)
	table.insert(
		scope,
		obs:onChange(function()
			local anns = peek(announcementsValue)
			if not anns or #anns == 0 then
				return
			end
			local label = peek(marqueeRef)
			if not label then
				return
			end
			if activeTween then
				activeTween:Cancel()
			end
			label.Position = UDim2.new(1, 10, 0, 0)
			activeTween = TweenService:Create(label, TweenInfo.new(6, Enum.EasingStyle.Linear), {
				Position = UDim2.new(-1, -10, 0, 0),
			})
			activeTween:Play()
		end)
	)

	local textLabel = scope:New("TextLabel")({
		Name = "Text",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(1, 10, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Accent,
		FontFace = Theme.Font.Body,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = annText,
	})
	marqueeRef:set(textLabel)

	return scope:New("Frame")({
		Name = "Marquee",
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.fromOffset(0, 52),
		BackgroundColor3 = Theme.Colors.AccentDim,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = hasAnn,
		[Children] = { textLabel },
	})
end

-- Offline income card
local function makeOfflineCard(scope, offlineIncomeValue)
	local isVisible = scope:Computed(function(use)
		return use(offlineIncomeValue) ~= nil
	end)

	local amountText = scope:Computed(function(use)
		local oi = use(offlineIncomeValue)
		if not oi then
			return ""
		end
		return "While you were away: +" .. formatNum(oi.amount) .. " Pellets"
	end)

	return scope:New("Frame")({
		Name = "OfflineCard",
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.new(0, 8, 0, 60),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Visible = isVisible,
		ZIndex = 7,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 44),
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
			}),
			scope:New("TextLabel")({
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Success,
				FontFace = Theme.Font.Label,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				Text = amountText,
			}),
			scope:New("TextButton")({
				Name = "Dismiss",
				Size = UDim2.fromOffset(32, 32),
				Position = UDim2.new(1, -36, 0.5, -16),
				BackgroundTransparency = 1,
				Text = "✕",
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Label,
				TextSize = 14,
				[OnEvent("Activated")] = function()
					StateController.set({ offlineIncome = nil })
				end,
			}),
		},
	})
end

-- WorldHUD: always-on overlay shown when main UI is minimized
local function makeWorldHUD(scope, uiVisible, slotsValue)
	local function getStripText(slots, now)
		if not slots then
			return ""
		end
		local running = 0
		local doneCount = 0
		local nextSecs = math.huge
		for _, s in pairs(slots) do
			if s.state == "RUNNING" then
				running += 1
				if s.workRemaining and s.lastTickAt then
					local run: TimerMath.SlotRun = {
						compoundId = s.compoundId or "",
						workRemaining = s.workRemaining,
						lastTickAt = s.lastTickAt,
						mode = (s.mode or "online") :: TimerMath.RunMode,
					}
					local secs = TimerMath.displaySeconds(run, now, true)
					if secs < nextSecs then
						nextSecs = secs
					end
				end
			elseif s.state == "DONE" then
				doneCount += 1
			end
		end
		local parts = {}
		if doneCount > 0 then
			table.insert(parts, doneCount .. " ready")
		end
		if running > 0 then
			local mins = math.floor(nextSecs / 60)
			local secs2 = math.floor(nextSecs) % 60
			table.insert(parts, running .. " running · " .. string.format("%d:%02d", mins, secs2))
		end
		return table.concat(parts, "  ·  ")
	end

	local stripText = scope:Value("")
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function()
			if peek(uiVisible) then
				return
			end
			stripText:set(getStripText(peek(slotsValue), os.time()))
		end)
	)

	local openBtnVisible = scope:Computed(function(use)
		return not use(uiVisible)
	end)

	local stripVisible = scope:Computed(function(use)
		if use(uiVisible) then
			return false
		end
		local slots = use(slotsValue)
		if not slots then
			return false
		end
		for _, s in pairs(slots) do
			if s.state == "RUNNING" or s.state == "DONE" then
				return true
			end
		end
		return false
	end)

	return scope:New("Frame")({
		Name = "WorldHUDRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Children] = {
			-- Circular open button
			scope:New("TextButton")({
				Name = "OpenBtn",
				Size = UDim2.fromOffset(52, 52),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -72),
				BackgroundColor3 = Theme.Colors.Accent,
				BorderSizePixel = 0,
				ZIndex = 10,
				Text = "",
				Visible = openBtnVisible,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.AccentDim,
						Thickness = 2,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("TextLabel")({
						Text = "P",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Color3.new(1, 1, 1),
						FontFace = Theme.Font.Header,
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
				},
				[OnEvent("Activated")] = function()
					uiVisible:set(true)
				end,
			}),
			-- Minimal timer strip
			scope:New("Frame")({
				Name = "TimerStrip",
				Size = UDim2.new(1, -76, 0, 32),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 8, 1, -72),
				BackgroundColor3 = Theme.Colors.Surface,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				ZIndex = 10,
				Visible = stripVisible,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
					}),
					scope:New("TextLabel")({
						Name = "StripText",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Label,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = stripText,
					}),
				},
			}),
		},
	})
end

local HomeScreen = {}
local _scope = nil

function HomeScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local uiVisible = scope:Value(true)
	local activeTabValue = scope:Value("Home")

	-- Bridge StateController → individual Fusion Values
	local balanceValue = scope:Value(st.balance)
	local slotsValue = scope:Value(st.slots)
	local slotCapValue = scope:Value(st.slotCap or 5)
	local rankValue = scope:Value(st.rank)
	local announcementsValue = scope:Value(st.announcements)
	local offlineIncomeValue = scope:Value(st.offlineIncome)
	local revealQueueValue = scope:Value((st :: any).revealQueue or 0)
	local timerSkipUsesValue = scope:Computed(function(use)
		return use(balanceValue).timerSkipUses
	end)

	local hintValue = scope:Value(HintController.getActiveHint())

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.balance ~= nil then
				balanceValue:set(patch.balance)
			end
			if patch.slots ~= nil then
				slotsValue:set(patch.slots)
			end
			if patch.slotCap ~= nil then
				slotCapValue:set(patch.slotCap)
			end
			if patch.rank ~= nil then
				rankValue:set(patch.rank)
			end
			if patch.announcements ~= nil then
				announcementsValue:set(patch.announcements)
			end
			if patch.offlineIncome ~= nil then
				offlineIncomeValue:set(patch.offlineIncome)
			end
			if patch.hints ~= nil then
				hintValue:set(HintController.getActiveHint())
			end
			if (patch :: any).revealQueue ~= nil then
				revealQueueValue:set((patch :: any).revealQueue)
			end
		end)
	)

	-- Build slot cards
	local slotCards = {}
	for i = 1, 10 do
		table.insert(slotCards, makeSlotCard(scope, i, slotsValue, slotCapValue, timerSkipUsesValue, uiController))
	end

	-- WorldHUD ScreenGui (always visible; contents gated by uiVisible)
	scope:New("ScreenGui")({
		Name = "WorldHUD",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			makeWorldHUD(scope, uiVisible, slotsValue),
		},
	})

	-- Main HomeScreen ScreenGui (hidden when world mode active)
	scope:New("ScreenGui")({
		Name = "HomeScreen",
		Enabled = scope:Computed(function(use)
			return use(uiVisible)
		end),
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			-- Background fill
			scope:New("Frame")({
				Name = "Bg",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Colors.Background,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			-- HUD (Zone A)
			makeHUD(scope, balanceValue, rankValue, uiVisible),
			-- Marquee (floating below HUD)
			makeMarquee(scope, announcementsValue),
			-- Reveal queue banner
			scope:New("Frame")({
				Name = "RevealBanner",
				Size = UDim2.new(1, 0, 0, 26),
				Position = UDim2.new(0, 0, 0, 52),
				BackgroundColor3 = Theme.Colors.AccentDim,
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use)
					return use(revealQueueValue) > 0
				end),
				ZIndex = 8,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Label,
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = scope:Computed(function(use)
							local n = use(revealQueueValue)
							return tostring(n) .. (n == 1 and " reveal queued" or " reveals queued")
						end),
					}),
				},
			}),
			-- Offline income card
			makeOfflineCard(scope, offlineIncomeValue),
			-- Left slot panel (Zone B, 200px, visible on Home tab)
			scope:New("Frame")({
				Name = "SlotPanel",
				Size = UDim2.new(0, 200, 1, -104),
				Position = UDim2.new(0, 0, 0, 52),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				ZIndex = 8,
				Visible = scope:Computed(function(use)
					return use(activeTabValue) == "Home"
				end),
				[Children] = {
					scope:New("Frame")({
						Name = "RightBorder",
						Size = UDim2.new(0, 1, 1, 0),
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, 0),
						BackgroundColor3 = Theme.Colors.SurfaceRaised,
						BorderSizePixel = 0,
					}),
					scope:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, 32),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						[Children] = {
							scope:New("TextLabel")({
								Text = "SLOTS",
								Size = UDim2.new(1, -16, 1, 0),
								Position = UDim2.fromOffset(8, 0),
								BackgroundTransparency = 1,
								TextColor3 = Theme.Colors.TextSecondary,
								FontFace = Theme.Font.Label,
								TextSize = 10,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							scope:New("Frame")({
								Name = "BottomBorder",
								Size = UDim2.new(1, 0, 0, 1),
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.new(0, 0, 1, 0),
								BackgroundColor3 = Theme.Colors.SurfaceRaised,
								BorderSizePixel = 0,
							}),
						},
					}),
					scope:New("ScrollingFrame")({
						Name = "SlotScroll",
						Size = UDim2.new(1, 0, 1, -33),
						Position = UDim2.fromOffset(0, 33),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 1),
							}),
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, 4),
								PaddingBottom = UDim.new(0, 4),
								PaddingLeft = UDim.new(0, 6),
								PaddingRight = UDim.new(0, 6),
							}),
							table.unpack(slotCards),
						},
					}),
				},
			}),
			-- Hint bar
			makeHintBar(scope, hintValue),
			-- Bottom nav (Zone C)
			makeBottomNav(scope, uiController, activeTabValue),
		},
	})
end

function HomeScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return HomeScreen
