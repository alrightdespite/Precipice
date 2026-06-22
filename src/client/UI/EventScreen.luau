-- EventScreen: §29 seasonal event — Flux balance + blueprint purchases. Visible in the
-- More drawer. Flux balance comes from StateController.flux (set by FluxUpdate); the event
-- is "active" iff flux ~= nil. Blueprints come from Data/EventCompounds (cost = blueprintFlux).
-- Ownership comes from the server (FluxUpdate.blueprintsOwned, sent at login + on purchase,
-- so it survives reopen) merged with a local optimistic set (covers the instant between a
-- buy and the server echo); the server is authoritative and rejects double-buys.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local EventCompounds = require(ReplicatedStorage.Shared.Data.EventCompounds)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local EventController = require(script.Parent.Parent.Controllers.EventController)

local Children = Fusion.Children
local doCleanup = Fusion.doCleanup

-- Stable blueprint list (by tier then id) from the authored event-compound data.
local BLUEPRINTS: { any } = {}
for _, bp in pairs(EventCompounds) do
	table.insert(BLUEPRINTS, bp)
end
table.sort(BLUEPRINTS, function(a, b)
	if a.tier ~= b.tier then
		return a.tier < b.tier
	end
	return a.id < b.id
end)

local EventScreen = {}
local _scope = nil

function EventScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local fluxValue = scope:Value(st.flux)
	local ownedLocal = scope:Value({} :: { [string]: boolean })
	local statusValue = scope:Value("")

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.flux ~= nil then
				fluxValue:set(patch.flux)
			end
		end)
	)

	local isActive = scope:Computed(function(use)
		return use(fluxValue) ~= nil
	end)
	local fluxTotal = scope:Computed(function(use)
		local f = use(fluxValue)
		return (f and f.total) or 0
	end)

	local function makeRow(bp: any)
		local cost = bp.blueprintFlux or 0

		local owned = scope:Computed(function(use)
			-- Server-persisted ownership (FluxUpdate.blueprintsOwned) survives reopen; the
			-- local optimistic set covers the instant between a buy and the server echo.
			local f = use(fluxValue)
			local server = (f and (f :: any).blueprintsOwned) or {}
			return server[bp.id] == true or use(ownedLocal)[bp.id] == true
		end)
		local canAfford = scope:Computed(function(use)
			return use(fluxTotal) >= cost
		end)
		local actionLabel = scope:Computed(function(use)
			return use(owned) and "Owned" or "Buy"
		end)
		local actionDisabled = scope:Computed(function(use)
			if use(owned) then
				return true
			end
			return not use(canAfford)
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
					Text = string.format("%s  (T%d)", bp.name or bp.id, bp.tier or 1),
				}),
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 14),
					Position = UDim2.fromOffset(0, 22),
					BackgroundTransparency = 1,
					TextColor3 = scope:Computed(function(use)
						return (use(owned) and Theme.Colors.Success)
							or (use(canAfford) and Theme.Colors.TextSecondary)
							or Theme.Colors.Danger
					end),
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = scope:Computed(function(use)
						if use(owned) then
							return "Blueprint owned"
						end
						return string.format("%d Flux", cost)
					end),
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
								task.spawn(function()
									local ok, err = EventController.purchaseBlueprint(bp.id)
									if ok then
										local set = table.clone(Fusion.peek(ownedLocal))
										set[bp.id] = true
										ownedLocal:set(set)
										statusValue:set("")
									else
										statusValue:set((bp.name or bp.id) .. ": " .. tostring(err))
									end
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	local rows: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	for _, bp in ipairs(BLUEPRINTS) do
		table.insert(rows, makeRow(bp))
	end

	scope:New("ScreenGui")({
		Name = "EventScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			Components.Backdrop(scope, {}),
			Components.ScreenHeader(scope, {
				Title = "Seasonal Event",
				OnClose = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			-- Flux balance / event status
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 20),
				Position = UDim2.fromOffset(12, 62),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				FontFace = Theme.Font.Label,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local f = use(fluxValue)
					if f == nil then
						return "No active event right now."
					end
					return string.format("◇ %d Flux · %s", f.total or 0, tostring(f.seasonKey or "event"))
				end),
			}),
			-- Status line (purchase errors)
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 16),
				Position = UDim2.fromOffset(12, 84),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Danger,
				FontFace = Theme.Font.Body,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = statusValue,
			}),
			-- Blueprint list (hidden until an event is active)
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, -24, 1, -108),
				Position = UDim2.fromOffset(12, 102),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 0,
				Visible = isActive,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				[Children] = rows,
			}),
			-- Empty-state hint when no event is active
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 40),
				Position = UDim2.fromOffset(12, 120),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.TextSecondary,
				FontFace = Theme.Font.Body,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				Visible = scope:Computed(function(use)
					return not use(isActive)
				end),
				Text = "No event is running. Event blueprints appear here when a season is active.",
			}),
		},
	})
end

function EventScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return EventScreen
