local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local LeaderboardController = require(script.Parent.Parent.Controllers.LeaderboardController)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local TAB_SPRINT = "sprint"
local TAB_CHIEF = "chief"
local TAB_LABELS = { sprint = "Weekly Sprint", chief = "Chief's Board" }

local LeaderboardScreen = {}
local _scope = nil

function LeaderboardScreen.open()
	if _scope then
		return
	end
	_scope = Fusion.scoped(Fusion)
	local scope = _scope
	local st = StateController.get()

	local activeBoard = scope:Value(TAB_SPRINT)
	local isLoading = scope:Value(false)
	local leaderboardValue = scope:Value(st.leaderboard)
	local ownRowsValue = scope:Value(st.ownRows)

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.leaderboard ~= nil then
				leaderboardValue:set(patch.leaderboard)
			end
			if patch.ownRows ~= nil then
				ownRowsValue:set(patch.ownRows)
			end
		end)
	)

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	local function loadBoard(board: string)
		isLoading:set(true)
		task.spawn(function()
			LeaderboardController.request(board)
			isLoading:set(false)
		end)
	end

	local function buildRow(entry: { userId: number, displayName: string, score: number, rank: number }, isOwn: boolean)
		local rankStr: string
		if entry.rank > 0 and entry.rank <= 1000 then
			rankStr = "#" .. tostring(entry.rank)
		elseif entry.rank == -1 then
			rankStr = "—"
		else
			rankStr = "Top " .. string.format("%.0f%%", math.ceil(entry.rank / 100))
		end

		return scope:New("Frame")({
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = isOwn and Theme.Colors.AccentDim or Theme.Colors.SurfaceRaised,
			BorderSizePixel = 0,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 4),
					PaddingBottom = UDim.new(0, 4),
				}),
				-- Rank
				scope:New("TextLabel")({
					Size = UDim2.fromOffset(48, 36),
					BackgroundTransparency = 1,
					TextColor3 = isOwn and Theme.Colors.Accent or Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Value,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = rankStr,
				}),
				-- Name
				scope:New("TextLabel")({
					Size = UDim2.new(1, -120, 1, 0),
					Position = UDim2.fromOffset(52, 0),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Label,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = entry.displayName ~= "" and entry.displayName or tostring(entry.userId),
				}),
				-- Score
				scope:New("TextLabel")({
					Size = UDim2.fromOffset(80, 36),
					Position = UDim2.new(1, -80, 0, 4),
					BackgroundTransparency = 1,
					TextColor3 = isOwn and Theme.Colors.Accent or Theme.Colors.TextPrimary,
					FontFace = Theme.Font.Value,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = tostring(entry.score),
				}),
			},
		})
	end

	local function buildBoardPanel(board: string)
		local entries = scope:Computed(function(use)
			local lb = use(leaderboardValue)
			return lb[board] or {}
		end)
		local ownRow = scope:Computed(function(use)
			return use(ownRowsValue)[board]
		end)

		local ownInTop = scope:Computed(function(use)
			local own = use(ownRow)
			if not own then
				return false
			end
			for _, e in ipairs(use(entries)) do
				if e.userId == localUserId then
					return true
				end
			end
			return false
		end)

		return scope:New("Frame")({
			Name = board .. "Panel",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use)
				return use(activeBoard) == board
			end),
			[Children] = {
				-- Loading indicator
				scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, 32),
					BackgroundTransparency = 1,
					TextColor3 = Theme.Colors.TextSecondary,
					FontFace = Theme.Font.Body,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = "Loading…",
					Visible = isLoading,
				}),
				-- Entry list
				scope:New("ScrollingFrame")({
					Size = UDim2.new(1, -24, 1, -60),
					Position = UDim2.fromOffset(12, 0),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 0,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.fromScale(0, 0),
					[Children] = {
						scope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 4),
						}),
						scope:Computed(function(use)
							local rows = {}
							for _, e in ipairs(use(entries)) do
								table.insert(rows, buildRow(e, e.userId == localUserId))
							end
							return rows
						end),
					},
				}),
				-- Own row pinned at bottom
				scope:New("Frame")({
					Size = UDim2.new(1, -24, 0, 48),
					Position = UDim2.new(0, 12, 1, -52),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use)
						return not use(ownInTop) and use(ownRow) ~= nil
					end),
					[Children] = {
						scope:New("UIListLayout")({ FillDirection = Enum.FillDirection.Vertical }),
						scope:New("Frame")({
							Size = UDim2.new(1, 0, 0, 1),
							BackgroundColor3 = Theme.Colors.SurfaceRaised,
							BorderSizePixel = 0,
						}),
						scope:Computed(function(use)
							local own = use(ownRow)
							if not own then
								return scope:New("Frame")({ Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
							end
							return buildRow(own, true)
						end),
					},
				}),
			},
		})
	end

	-- Tab buttons
	local tabBtns = {}
	for _, board in ipairs({ TAB_SPRINT, TAB_CHIEF }) do
		local b = board
		table.insert(
			tabBtns,
			scope:New("TextButton")({
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundColor3 = scope:Computed(function(use)
					return use(activeBoard) == b and Theme.Colors.AccentDim or Theme.Colors.Surface
				end),
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = scope:Computed(function(use)
							return use(activeBoard) == b and Theme.Colors.Accent or Theme.Colors.TextSecondary
						end),
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = TAB_LABELS[b],
					}),
				},
				[OnEvent("Activated")] = function()
					activeBoard:set(b)
					loadBoard(b)
				end,
			})
		)
	end

	loadBoard(TAB_SPRINT)

	scope:New("ScreenGui")({
		Name = "LeaderboardScreen",
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
						Text = "Leaderboard",
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
			scope:New("Frame")({
				Name = "Boards",
				Size = UDim2.new(1, 0, 1, -100),
				Position = UDim2.fromOffset(0, 100),
				BackgroundTransparency = 1,
				[Children] = {
					buildBoardPanel(TAB_SPRINT),
					buildBoardPanel(TAB_CHIEF),
				},
			}),
		},
	})
end

function LeaderboardScreen.close()
	if _scope then
		doCleanup(_scope)
		_scope = nil
	end
end

return LeaderboardScreen
