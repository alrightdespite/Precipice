-- Thin orchestrator: owns screen transitions, routes StateController changes to UI modules.
-- No layout or rendering logic lives here — that is each UI module's responsibility.

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

local _screens = {
	Loading = LoadingScreen,
	Home = HomeScreen,
	Synthesize = SynthesizeScreen,
	Market = MarketScreen,
	FormulaLog = FormulaLogScreen,
	Leaderboard = LeaderboardScreen,
	Syndicate = SyndicateScreen,
	Prestige = PrestigeScreen,
	Settings = SettingsScreen,
}

local _current: string? = nil

local UIController = {}

function UIController.openScreen(name: string)
	if _current and _screens[_current] then
		_screens[_current].close()
	end
	_current = name
	if _screens[name] then
		_screens[name].open()
	else
		warn("[UIController] unknown screen:", name)
	end
end

function UIController.closeScreen()
	UIController.openScreen("Home")
end

function UIController.init(): typeof(UIController)
	-- Show loading until state.loaded = true
	UIController.openScreen("Loading")

	StateController.Changed:Connect(function(patch)
		if patch.loaded == true then
			UIController.openScreen("Home")
		end
	end)

	return UIController
end

return UIController
