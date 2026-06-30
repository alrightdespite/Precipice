-- Thin orchestrator: owns screen transitions, routes StateController changes to UI modules.
-- No layout or rendering logic lives here — that is each UI module's responsibility.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.UI.Theme)

local StateController = require(script.Parent.StateController)

local LoadingScreen = require(script.Parent.Parent.UI.LoadingScreen)
local HomeScreen = require(script.Parent.Parent.UI.HomeScreen)
local SynthesizeScreen = require(script.Parent.Parent.UI.SynthesizeScreen)
local MarketScreen = require(script.Parent.Parent.UI.MarketScreen)
local FormulaLogScreen = require(script.Parent.Parent.UI.FormulaLogScreen)
local LeaderboardScreen = require(script.Parent.Parent.UI.LeaderboardScreen)
local SyndicateScreen = require(script.Parent.Parent.UI.SyndicateScreen)
local PrestigeScreen = require(script.Parent.Parent.UI.PrestigeScreen)
local SettingsScreen = require(script.Parent.Parent.UI.SettingsScreen)
local CosmeticsScreen = require(script.Parent.Parent.UI.CosmeticsScreen)
local ContractsScreen = require(script.Parent.Parent.UI.ContractsScreen)
local EventScreen = require(script.Parent.Parent.UI.EventScreen)
local VaultScreen = require(script.Parent.Parent.UI.VaultScreen)
local ShopScreen = require(script.Parent.Parent.UI.ShopScreen)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local doCleanup = Fusion.doCleanup

local _screens = {
	Loading = LoadingScreen,
	Home = HomeScreen,
	Synthesize = SynthesizeScreen,
	Lab = SynthesizeScreen,
	Market = MarketScreen,
	FormulaLog = FormulaLogScreen,
	Leaderboard = LeaderboardScreen,
	Syndicate = SyndicateScreen,
	Prestige = PrestigeScreen,
	Settings = SettingsScreen,
	Cosmetics = CosmeticsScreen,
	Contracts = ContractsScreen,
	Event = EventScreen,
	Vault = VaultScreen,
	Shop = ShopScreen,
}

local _current: string? = nil
local _loaded = false
local _initAt = 0
local MIN_LOADING_SECS = 0.8

-- "More" drawer state (managed here, not a separate screen)
local _drawerScope = nil

local UIController = {}

local function closeDrawer()
	if _drawerScope then
		doCleanup(_drawerScope)
		_drawerScope = nil
	end
end

function UIController.openDrawer()
	closeDrawer()
	_drawerScope = Fusion.scoped(Fusion)
	local scope = _drawerScope

	local MORE_ITEMS = {
		{ label = "Vault", screen = "Vault", icon = "🔒" },
		{ label = "Contracts", screen = "Contracts", icon = "📋" },
		{ label = "Event", screen = "Event", icon = "◇" },
		{ label = "Leaderboard", screen = "Leaderboard", icon = "🏆" },
		{ label = "Syndicate", screen = "Syndicate", icon = "🤝" },
		{ label = "Cosmetics", screen = "Cosmetics", icon = "🎨" },
		{ label = "Prestige", screen = "Prestige", icon = "⭐" },
		{ label = "Settings", screen = "Settings", icon = "⚙" },
	}

	local drawerItems = {}
	for idx, item in ipairs(MORE_ITEMS) do
		local i = item
		local hovered = scope:Value(false)
		local bgGoal = scope:Computed(function(use)
			return use(hovered) and Theme.Colors.SurfaceRaised:Lerp(Theme.Colors.Accent, 0.12)
				or Theme.Colors.Surface
		end)
		local bgSpring = scope:Spring(bgGoal, 28, 1)
		table.insert(
			drawerItems,
			scope:New("TextButton")({
				LayoutOrder = idx,
				BackgroundColor3 = bgSpring,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusSmall }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Stroke,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("UIGradient")({
						Color = Theme.Gradient.SurfaceSheen,
						Rotation = Theme.Gradient.SurfaceSheenRotation,
					}),
					scope:New("TextLabel")({
						Name = "Icon",
						Size = UDim2.fromOffset(30, 30),
						Position = UDim2.new(0, 12, 0.5, -15),
						BackgroundTransparency = 1,
						Text = i.icon,
						TextSize = 20,
						TextColor3 = Theme.Colors.Accent,
						FontFace = Theme.Font.Value,
						TextXAlignment = Enum.TextXAlignment.Center,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -52, 1, 0),
						Position = UDim2.fromOffset(50, 0),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Display,
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = i.label,
					}),
				},
				[OnEvent("MouseEnter")] = function()
					hovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hovered:set(false)
				end,
				[OnEvent("Activated")] = function()
					closeDrawer()
					UIController.openScreen(i.screen)
				end,
			})
		)
	end

	scope:New("ScreenGui")({
		Name = "MoreDrawer",
		Enabled = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		Parent = Players.LocalPlayer.PlayerGui,
		[Children] = {
			-- Dismiss overlay
			scope:New("TextButton")({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 1,
				[OnEvent("Activated")] = closeDrawer,
			}),
			-- Drawer panel (slides up from bottom)
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.new(1, 0, 0, 372),
				Position = UDim2.new(0, 0, 1, -372),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadiusLarge }),
					scope:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Theme.Colors.SurfaceRaised),
							ColorSequenceKeypoint.new(1, Theme.Colors.Surface),
						}),
						Rotation = 90,
					}),
					scope:New("UIStroke")({
						Color = Theme.Colors.Stroke,
						Thickness = 1,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					-- grab handle
					scope:New("Frame")({
						Name = "Handle",
						Size = UDim2.fromOffset(44, 5),
						Position = UDim2.new(0.5, -22, 0, 10),
						BackgroundColor3 = Theme.Colors.TextMuted,
						BorderSizePixel = 0,
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
						},
					}),
					-- header
					scope:New("TextLabel")({
						Name = "Title",
						Size = UDim2.new(1, -36, 0, 30),
						Position = UDim2.fromOffset(20, 24),
						BackgroundTransparency = 1,
						Text = "MORE",
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Display,
						TextSize = 22,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					-- 2-column grid of items
					scope:New("Frame")({
						Name = "Grid",
						Size = UDim2.new(1, -32, 1, -84),
						Position = UDim2.fromOffset(16, 64),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIGridLayout")({
								CellSize = UDim2.new(0.5, -7, 0, 64),
								CellPadding = UDim2.fromOffset(14, 12),
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirectionMaxCells = 2,
							}),
							table.unpack(drawerItems),
						},
					}),
				},
			}),
		},
	})
end

function UIController.openScreen(name: string, ...)
	-- Close drawer on any nav
	closeDrawer()

	if _current and _current ~= name and _screens[_current] then
		_screens[_current].close()
	end
	_current = name
	if _screens[name] then
		-- Some screens take uiController as param for navigation callbacks
		local screen = _screens[name]
		if screen.open then
			screen.open(UIController, ...)
		end
	else
		warn("[UIController] unknown screen:", name)
	end
end

function UIController.closeScreen()
	UIController.openScreen("Home")
end

function UIController.init(): typeof(UIController)
	_initAt = tick()
	LoadingScreen.open()

	local s2cCount = 0
	local loadConn
	loadConn = StateController.Changed:Connect(function(patch)
		if _loaded then
			if loadConn then
				loadConn:Disconnect()
			end
			return
		end

		-- Count unique top-level keys arriving (each S2C event sets some keys)
		s2cCount += 1
		LoadingScreen.setProgress(math.min(s2cCount * 0.2, 1))

		if patch.loaded == true then
			_loaded = true
			if loadConn then
				loadConn:Disconnect()
			end
			local elapsed = tick() - _initAt
			task.delay(math.max(0, MIN_LOADING_SECS - elapsed), function()
				LoadingScreen.close()
				UIController.openScreen("Home")
			end)
		end
	end)

	-- 10-second fallback: force open Home regardless
	task.delay(10, function()
		if not _loaded then
			_loaded = true
			StateController.set({ loaded = true })
			LoadingScreen.close()
			if _current == "Loading" or _current == nil then
				UIController.openScreen("Home")
			end
		end
	end)

	return UIController
end

return UIController
