-- Client boot. Initializes all controllers in dependency order, then wires UI.
-- No yields in boot path; all S2C connections are fire-and-forget.

local StateController = require(script.Parent.Controllers.StateController)
local RemoteController = require(script.Parent.Controllers.RemoteController)
local SlotController = require(script.Parent.Controllers.SlotController)
local VaultController = require(script.Parent.Controllers.VaultController)
local LabController = require(script.Parent.Controllers.LabController)
local MarketController = require(script.Parent.Controllers.MarketController)
local PatentController = require(script.Parent.Controllers.PatentController)
local SyndicateController = require(script.Parent.Controllers.SyndicateController)
local JointController = require(script.Parent.Controllers.JointController)
local RankController = require(script.Parent.Controllers.RankController)
local ContractController = require(script.Parent.Controllers.ContractController)
local StreakController = require(script.Parent.Controllers.StreakController)
local LeaderboardController = require(script.Parent.Controllers.LeaderboardController)
local PrestigeController = require(script.Parent.Controllers.PrestigeController)
local EventController = require(script.Parent.Controllers.EventController)
local HintController = require(script.Parent.Controllers.HintController)
local UIController = require(script.Parent.Controllers.UIController)

-- Dependency-ordered init
StateController.init()
RemoteController.init() -- resolves remotes + wires all S2C events
SlotController.init()
VaultController.init()
LabController.init()
MarketController.init()
PatentController.init()
SyndicateController.init()
JointController.init()
RankController.init()
ContractController.init()
StreakController.init()
LeaderboardController.init()
PrestigeController.init()
EventController.init()
HintController.init()
UIController.init()

-- After one frame, mark loaded so UIController transitions from Loading → Home.
-- Phase 12B: replace with server-driven initial-state confirmation event.
task.defer(function()
	StateController.set({ loaded = true })
end)
