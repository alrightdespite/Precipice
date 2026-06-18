local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local TimerMath = require(ReplicatedStorage.Shared.Core.TimerMath)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local SlotController = require(script.Parent.Parent.Controllers.SlotController)
local HintController = require(script.Parent.Parent.Controllers.HintController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local NAV_TABS = { "Home", "Lab", "Market", "Log", "More" }
local SLOT_HEIGHT = 80

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

-- Single slot card — scope-owned, reacts to slotsValue
local function makeSlotCard(scope, slotIndex: number, slotsValue, timerSkipUsesValue, uiController)
	local slotComputed = scope:Computed(function(use)
		local s = use(slotsValue)[slotIndex]
		return s or { state = "EMPTY", isActive = false }
	end)

	local slotState = scope:Computed(function(use)
		return use(slotComputed).state
	end)

	local bgColor = scope:Computed(function(use)
		local st = use(slotState)
		return (st == "RUNNING" or st == "DONE" or st == "REVEALING") and Theme.Colors.SurfaceRaised or Theme.Colors.Surface
	end)

	local accentColor = scope:Computed(function(use)
		local slot = use(slotComputed)
		if slot.state == "EMPTY" then
			return Theme.Colors.Surface
		end
		local tier = 1
		if slot.compoundId then
			-- Tier lookup: derive from compound data if available (Phase 12C wires compounds)
			-- For now approximate from mode
		end
		return Theme.Colors.Tier[tier] or Theme.Colors.Accent
	end)

	local timerValue = scope:Value("--:--")
	-- Heartbeat: update timer each frame while slot is running
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
			return "Slot idle — tap to start"
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

	-- Action button label
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
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
			-- Left tier accent bar
			scope:New("Frame")({
				Name = "Accent",
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = accentColor,
				BorderSizePixel = 0,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				},
			}),
			-- Content area
			scope:New("Frame")({
				Name = "Content",
				Size = UDim2.new(1, -56, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("TextLabel")({
						Name = "Main",
						Text = mainText,
						Size = UDim2.new(1, 0, 0, 24),
						Position = UDim2.fromOffset(0, 14),
						BackgroundTransparency = 1,
						TextColor3 = scope:Computed(function(use)
							if use(slotState) == "EMPTY" then
								return Theme.Colors.TextSecondary
							end
							return Theme.Colors.TextPrimary
						end),
						FontFace = Theme.Font.Label,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					-- Timer countdown (RUNNING only)
					scope:New("TextLabel")({
						Name = "Timer",
						Text = timerValue,
						Size = UDim2.new(1, 0, 0, 18),
						Position = UDim2.fromOffset(0, 42),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Value,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = showTimer,
					}),
					-- "Ready to reveal" pulse (DONE only)
					scope:New("TextLabel")({
						Name = "DoneLabel",
						Text = "Ready to reveal",
						Size = UDim2.new(1, 0, 0, 18),
						Position = UDim2.fromOffset(0, 42),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Success,
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						Visible = showDone,
					}),
				},
			}),
			-- Action button (right side, 44px wide)
			scope:New("TextButton")({
				Name = "ActionBtn",
				Size = UDim2.fromOffset(44, 44),
				Position = UDim2.new(1, -48, 0.5, -22),
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

-- HUD bar
local function makeHUD(scope, balanceValue, rankValue)
	return scope:New("Frame")({
		Name = "HUD",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 5,
		[Children] = {
			scope:New("UIStroke")({
				Color = Theme.Colors.SurfaceRaised,
				Thickness = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			-- Pellets (left)
			scope:New("Frame")({
				Name = "Pellets",
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(0, 8, 0.5, -20),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
					}),
					-- Yellow circle icon
					scope:New("Frame")({
						Size = UDim2.fromOffset(16, 16),
						BackgroundColor3 = Color3.fromHex("F59E0B"),
						BorderSizePixel = 0,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						},
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromOffset(96, 24),
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
			-- Rank title (center)
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
			-- Catalysts (right)
			scope:New("TextLabel")({
				Name = "Catalysts",
				Size = UDim2.fromOffset(100, 40),
				Position = UDim2.new(1, -108, 0.5, -20),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				FontFace = Theme.Font.Value,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = scope:Computed(function(use)
					return "◈ " .. formatNum(use(balanceValue).catalysts)
				end),
			}),
		},
	})
end

-- Bottom nav bar
local function makeBottomNav(scope, uiController)
	local tabs = {}
	for _, name in ipairs(NAV_TABS) do
		local isHome = name == "Home"
		local btn = scope:New("TextButton")({
			Name = name,
			Size = UDim2.new(1 / #NAV_TABS, 0, 1, 0),
			BackgroundColor3 = isHome and Theme.Colors.AccentDim or Theme.Colors.Surface,
			BorderSizePixel = 0,
			Text = "",
			[Children] = {
				scope:New("TextLabel")({
					Text = name,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					TextColor3 = isHome and Theme.Colors.Accent or Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Label,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center,
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
						return
					end
					uiController.openScreen(target)
				end
			end,
		})
		table.insert(tabs, btn)
	end

	return scope:New("Frame")({
		Name = "BottomNav",
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 5,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			table.unpack(tabs),
		},
	})
end

-- Hint bar
local function makeHintBar(scope, hintValue)
	return scope:New("Frame")({
		Name = "HintBar",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 1, -100),
		BackgroundColor3 = Theme.Colors.AccentDim,
		BorderSizePixel = 0,
		Visible = scope:Computed(function(use)
			return use(hintValue) ~= nil
		end),
		ZIndex = 4,
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

-- Announcement marquee
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

	-- Watch for new announcements and run marquee tween
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
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 56),
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
		Position = UDim2.fromOffset(12, 92),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		Visible = isVisible,
		ZIndex = 3,
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

local HomeScreen = {}
local _scope = nil

function HomeScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	-- Bridge StateController → individual Fusion Values
	local balanceValue = scope:Value(st.balance)
	local slotsValue = scope:Value(st.slots)
	local rankValue = scope:Value(st.rank)
	local announcementsValue = scope:Value(st.announcements)
	local offlineIncomeValue = scope:Value(st.offlineIncome)
	local revealQueueValue = scope:Value((st :: any).revealQueue or 0)
	local timerSkipUsesValue = scope:Computed(function(use)
		return use(balanceValue).timerSkipUses
	end)

	-- Active hint (from HintController, not StateController)
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
		table.insert(slotCards, makeSlotCard(scope, i, slotsValue, timerSkipUsesValue, uiController))
	end

	-- Top offset changes if offline card visible or marquee visible
	local hudHeight = 56
	local marqueeHeight = 28
	local topPad = hudHeight + marqueeHeight + 4

	scope:New("ScreenGui")({
		Name = "HomeScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			makeHUD(scope, balanceValue, rankValue),
			makeMarquee(scope, announcementsValue),
			-- Queued-reveal counter ("N reveals queued") — §13 multi-reveal spec
			scope:New("Frame")({
				Name = "RevealBanner",
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.new(0, 0, 0, 88),
				BackgroundColor3 = Theme.Colors.AccentDim,
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use)
					return use(revealQueueValue) > 0
				end),
				ZIndex = 4,
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Label,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = scope:Computed(function(use)
							local n = use(revealQueueValue)
							return tostring(n) .. (n == 1 and " reveal queued" or " reveals queued")
						end),
					}),
				},
			}),
			makeOfflineCard(scope, offlineIncomeValue),
			-- Slot panel toggle
			(function()
				local slotPanelVisible = scope:Value(true)
				return {
					scope:New("TextButton")({
						Name = "SlotToggle",
						Size = UDim2.new(0, 88, 0, 28),
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -12, 1, -220),
						BackgroundColor3 = Theme.Colors.Surface,
						BorderSizePixel = 0,
						Text = scope:Computed(function(use)
							return use(slotPanelVisible) and "Hide" or "Show Slots"
						end),
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Label,
						TextSize = 13,
						ZIndex = 5,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
						},
						[OnEvent("Activated")] = function()
							slotPanelVisible:set(not peek(slotPanelVisible))
						end,
					}),
					-- Slot scroll panel
					scope:New("ScrollingFrame")({
						Name = "SlotPanel",
						Size = UDim2.new(1, -24, 0, 200),
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 12, 1, -12),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 0,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.fromScale(0, 0),
						Visible = scope:Computed(function(use)
							return use(slotPanelVisible)
						end),
						[Children] = {
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirection = Enum.FillDirection.Vertical,
								Padding = UDim.new(0, 6),
							}),
							table.unpack(slotCards),
						},
					}),
				}
			end)(),
			makeHintBar(scope, hintValue),
			makeBottomNav(scope, uiController),
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
