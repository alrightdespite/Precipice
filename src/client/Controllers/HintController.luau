-- Drives the NPE hint system. Tracks shown hints per-session (not persisted to DataStore).
-- Subscribes to StateController.Changed; auto-dismisses hints after their timeout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HintTriggerLogic = require(ReplicatedStorage.Shared.Core.HintTriggerLogic)
local StateController = require(script.Parent.StateController)

local HintController = {}

local _activeHints: { { id: string, text: string } } = {}

local function refresh()
	local state = StateController.get()
	local triggered = HintTriggerLogic.evaluate({
		slots = state.slots,
		formulaLog = state.formulaLog,
		syndicate = state.syndicate,
		streak = state.streak,
		patents = state.patents,
		flux = state.flux,
	}, state.hints)

	for _, def in ipairs(triggered) do
		-- Guard: not already queued
		local already = false
		for _, active in ipairs(_activeHints) do
			if active.id == def.id then
				already = true
				break
			end
		end
		if not already then
			table.insert(_activeHints, { id = def.id, text = def.text })
			-- Auto-dismiss after timeout
			task.delay(def.dismissAfter, function()
				HintController.dismiss(def.id)
			end)
		end
	end
end

function HintController.getActiveHint(): { id: string, text: string }?
	return _activeHints[1]
end

function HintController.dismiss(id: string)
	-- Mark as shown in persistent session state
	local hints = table.clone(StateController.get().hints)
	hints[id] = true
	StateController.set({ hints = hints })

	-- Remove from active queue
	for i, hint in ipairs(_activeHints) do
		if hint.id == id then
			table.remove(_activeHints, i)
			break
		end
	end
end

function HintController.init(): typeof(HintController)
	StateController.Changed:Connect(function(_patch)
		refresh()
	end)
	-- Evaluate immediately against initial state
	refresh()
	return HintController
end

return HintController
