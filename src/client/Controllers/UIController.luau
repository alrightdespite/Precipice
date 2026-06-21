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
		{ label = "Contracts", screen = "Contracts" },
		{ label = "Event", screen = "Event" },
		{ label = "Leaderboard", screen = "Leaderboard" },
		{ label = "Syndicate", screen = "Syndicate" },
		{ label = "Cosmetics", screen = "Cosmetics" },
		{ label = "Prestige", screen = "Prestige" },
		{ label = "Settings", screen = "Settings" },
	}

	local drawerItems = {}
	for _, item in ipairs(MORE_ITEMS) do
		local i = item
		table.insert(
			drawerItems,
			scope:New("TextButton")({
				Size = UDim2.new(1, 0, 0, 52),
				BackgroundColor3 = Theme.Colors.Surface,
				BorderSizePixel = 0,
				Text = "",
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Layout.CornerRadius }),
					scope:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						TextColor3 = Theme.Colors.TextPrimary,
						FontFace = Theme.Font.Label,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = i.label,
					}),
				},
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
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 1,
				[OnEvent("Activated")] = closeDrawer,
			}),
			-- Drawer panel (slides up from bottom)
			scope:New("Frame")({
				Name = "Panel",
				Size = UDim2.new(1, 0, 0, 340),
				Position = UDim2.new(0, 0, 1, -340),
				BackgroundColor3 = Theme.Colors.SurfaceRaised,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 16),
						PaddingBottom = UDim.new(0, 16),
					}),
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 8),
					}),
					table.unpack(drawerItems),
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
