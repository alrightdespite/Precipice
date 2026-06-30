local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local LeaderboardController = require(script.Parent.Parent.Controllers.LeaderboardController)

local Children = Fusion.Children
local peek = Fusion.peek
local doCleanup = Fusion.doCleanup

local TAB_SPRINT = "sprint"
local TAB_CHIEF = "chiefs"
local TAB_LABELS = { sprint = "Weekly Sprint", chiefs = "Chief's Board" }

local function formatNum(n: number): string
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	end
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	end
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	end
	if n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end
	return tostring(math.floor(n))
end

local LeaderboardScreen = {}
local _scope = nil

function LeaderboardScreen.open(uiController)
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
	local championshipsValue = scope:Value(st.championships or {})

	table.insert(
		scope,
		StateController.Changed:Connect(function(patch)
			if patch.leaderboard ~= nil then
				leaderboardValue:set(patch.leaderboard)
			end
			if patch.ownRows ~= nil then
				ownRowsValue:set(patch.ownRows)
			end
			if patch.championships ~= nil then
				championshipsValue:set(patch.championships)
			end
		end)
	)

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0

	-- Server sends entries with userId only (displayName nil); resolve names client-side and
	-- cache them. A miss kicks off an async GetNameFromUserIdAsync and updates the reactive
	-- cache so the rows re-render with the name in place of the raw id.
	local nameCache = scope:Value({} :: { [number]: string })
	local _resolving: { [number]: boolean } = {}
	local function resolveName(userId: number)
		if userId <= 0 or _resolving[userId] or peek(nameCache)[userId] then
			return -- skip invalid/test ids and ones already resolved/in-flight
		end
		_resolving[userId] = true
		task.spawn(function()
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if ok and name then
				local next = table.clone(peek(nameCache))
				next[userId] = name
				nameCache:set(next)
			end
			_resolving[userId] = nil
		end)
	end

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
			BackgroundColor3 = isOwn and Theme.Colors.SurfaceRaised:Lerp(Theme.Colors.Accent, 0.16)
				or Theme.Colors.SurfaceRaised,
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
					Text = scope:Computed(function(use)
						-- Prefer a server-sent name, else the resolved cache, else the raw id.
						if entry.displayName and entry.displayName ~= "" then
							return entry.displayName
						end
						resolveName(entry.userId)
						return use(nameCache)[entry.userId] or tostring(entry.userId)
					end),
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
					Text = formatNum(entry.score or 0),
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

	loadBoard(TAB_SPRINT)

	scope:New("ScreenGui")({
		Name = "LeaderboardScreen",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			Components.Backdrop(scope, {}),
			Components.ScreenHeader(scope, {
				Title = "Leaderboard",
				OnClose = function()
					if uiController then
						uiController.openScreen("Home")
					end
				end,
			}),
			Components.TabBar(scope, {
				Position = UDim2.fromOffset(0, 56),
				Active = activeBoard,
				OnSelect = function(k)
					activeBoard:set(k)
					loadBoard(k)
				end,
				Items = {
					{ key = TAB_SPRINT, label = TAB_LABELS[TAB_SPRINT] },
					{ key = TAB_CHIEF, label = TAB_LABELS[TAB_CHIEF] },
				},
			}),
			-- §18 Hall of Fame banner — the player's Sprint championships (hidden if none).
			scope:New("Frame")({
				Name = "ChampionBanner",
				Size = UDim2.new(1, 0, 0, 28),
				Position = UDim2.fromOffset(0, 100),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use)
					return #use(championshipsValue) > 0
				end),
				[Children] = {
					scope:New("Frame")({
						Name = "Underline",
						Size = UDim2.new(1, 0, 0, 2),
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 0, 1, 0),
						BackgroundColor3 = Theme.Colors.Accent,
						BorderSizePixel = 0,
					}),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Label,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = scope:Computed(function(use)
							local champs = use(championshipsValue)
							local n = #champs
							if n == 0 then
								return ""
							end
							local bestRank, bestWeek = math.huge, 0
							for _, c in ipairs(champs) do
								if c.rank < bestRank then
									bestRank = c.rank
									bestWeek = c.weekEpoch
								end
							end
							return string.format(
								"🏆 %d-time Sprint Champion · best #%d (week %d)",
								n, bestRank, bestWeek
							)
						end),
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Boards",
				Size = scope:Computed(function(use)
					return #use(championshipsValue) > 0 and UDim2.new(1, 0, 1, -128)
						or UDim2.new(1, 0, 1, -100)
				end),
				Position = scope:Computed(function(use)
					return #use(championshipsValue) > 0 and UDim2.fromOffset(0, 128)
						or UDim2.fromOffset(0, 100)
				end),
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
