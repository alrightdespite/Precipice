-- ContractsScreen: §19 daily contracts + daily streak. Shows the player's 5 contract
-- slots (description / progress / reward) with a Claim button on completed-unclaimed
-- slots, plus a streak-day indicator. Server-authoritative: Claim issues the C2S call
-- and surfaces errors; progress/claimed state arrives via ContractUpdate (StateController
-- .contracts) and StreakUpdate (StateController.streak), so rows rebuild reactively.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local ContractPool = require(ReplicatedStorage.Shared.Data.ContractPool)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local ContractController = require(script.Parent.Parent.Controllers.ContractController)

local Children = Fusion.Children
local doCleanup = Fusion.doCleanup

-- The server contract slots carry only { templateId, progress, target, completed,
-- claimed }; description / reward / difficulty live in the authored pool, keyed by id.
local TEMPLATE_BY_ID: { [string]: { name: string, pelletReward: number, difficulty: string } } = {}
for _, difficulty in ipairs({ "easy", "medium", "hard" }) do
	for _, t in ipairs(ContractPool[difficulty] or {}) do
		TEMPLATE_BY_ID[t.id] = { name = t.name, pelletReward = t.pelletReward, difficulty = difficulty }
	end
end

local DIFFICULTY_LABEL = { easy = "EASY", medium = "MEDIUM", hard = "HARD" }
local DIFFICULTY_COLOR = {
	easy = Theme.Colors.Success,
	medium = Theme.Colors.Accent,
	hard = Theme.Colors.Danger,
}

local ContractsScreen = {}
local _scope = nil

function ContractsScreen.open(uiController)
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local contractsValue = scope:Value(st.contracts or {})
	local streakValue = scope:Value(st.streak)
	local statusValue = scope:Value("")

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.contracts ~= nil then
				contractsValue:set(patch.contracts)
			end
			if patch.streak ~= nil then
				streakValue:set(patch.streak)
			end
		end)
	)

	-- One contract slot. The whole list rebuilds when contractsValue changes, so this
	-- renders a plain snapshot (no inner reactive state needed).
	local function makeRow(slotIndex: number, contract: any)
		local tmpl = TEMPLATE_BY_ID[contract.templateId] or {}
		local desc = tmpl.name or contract.templateId or "Contract"
		local reward = tmpl.pelletReward or 0
		local diff = tmpl.difficulty or "easy"
		local target = contract.target or 1
		local progress = math.min(contract.progress or 0, target)
		local completed = (contract.completed == true) or ((contract.progress or 0) >= target)
		local claimed = contract.claimed == true

		local actionLabel = if claimed then "Claimed" elseif completed then "Claim" else "In progress"

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundColor3 = Theme.Colors.Surface,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 8),
					PaddingBottom = UDim.new(0, 8),
				}),
				-- Difficulty tag
				scope:New("TextLabel")({
					Size = UDim2.fromOffset(70, 14),
					Position = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					TextColor3 = DIFFICULTY_COLOR[diff] or Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Label,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = DIFFICULTY_LABEL[diff] or "",
				}),
				-- Description
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 18),
					Position = UDim2.fromOffset(0, 14),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = desc,
				}),
				-- Progress bar (positioned mid-row; ProgressBar has no Position prop)
				scope:New("Frame")({
					Size = UDim2.new(1, -120, 0, 6),
					Position = UDim2.fromOffset(0, 34),
					BackgroundTransparency = 1,
					[Children] = {
						Components.ProgressBar(scope, {
							ValueState = progress,
							MaxState = target,
							Size = UDim2.fromScale(1, 1),
						}),
					},
				}),
				-- Progress + reward text
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 0, 14),
					Position = UDim2.fromOffset(0, 44),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = string.format("%d / %d · %d ◈", progress, target, reward),
				}),
				-- Claim action
				scope:New("Frame")({
					Size = UDim2.fromOffset(96, 36),
					Position = UDim2.new(1, -96, 0.5, -18),
					BackgroundTransparency = 1,
					[Children] = {
						Components.Button(scope, {
							Text = actionLabel,
							Style = "secondary",
							Disabled = claimed or not completed,
							OnClick = function()
								task.spawn(function()
									local ok, err = ContractController.claim(slotIndex)
									statusValue:set(ok and "" or (desc .. ": " .. tostring(err)))
								end)
							end,
						}),
					},
				}),
			},
		})
	end

	scope:New("ScreenGui")({
		Name = "ContractsScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			Components.Backdrop(scope, {}),
			Components.ScreenHeader(scope, {
				Title = "Daily Contracts",
				OnClose = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			-- Streak indicator
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 18),
				Position = UDim2.fromOffset(12, 60),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Accent,
				FontFace = Theme.Font.Label,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = scope:Computed(function(use)
					local s = use(streakValue)
					if s and type(s.day) == "number" and s.day > 0 then
						return "🔥 Daily streak: day " .. tostring(s.day)
					end
					return "No active streak — extract or synthesize today to start one."
				end),
			}),
			-- Status line (claim errors)
			scope:New("TextLabel")({
				Size = UDim2.new(1, -24, 0, 16),
				Position = UDim2.fromOffset(12, 80),
				BackgroundTransparency = 1,
				TextColor3 = Theme.Colors.Danger,
				FontFace = Theme.Font.Body,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = statusValue,
			}),
			-- Contract list
			scope:New("ScrollingFrame")({
				Size = UDim2.new(1, -24, 1, -104),
				Position = UDim2.fromOffset(12, 98),
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
					scope:Computed(function(use)
						local list = use(contractsValue)
						local rows: { any } = {}
						for i, c in ipairs(list) do
							table.insert(rows, makeRow(i, c))
						end
						if #rows == 0 then
							table.insert(
								rows,
								scope:New("TextLabel")({
									Size = UDim2.new(1, 0, 0, 40),
									BackgroundTransparency = 1,
									TextColor3 = Theme.Colors.TextSecondary,
									FontFace = Theme.Font.Body,
									TextSize = 13,
									Text = "No contracts yet — check back after your next login.",
								})
							)
						end
						return rows
					end),
				},
			}),
		},
	})
end

function ContractsScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return ContractsScreen
