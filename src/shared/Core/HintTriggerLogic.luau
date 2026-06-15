-- Pure hint trigger evaluation. No Roblox globals. Lune-testable.
-- HintController wires this to StateController.Changed; tests call it directly.

local HintTriggerLogic = {}

export type HintDef = {
	id: string,
	text: string,
	dismissAfter: number,
}

-- Order determines display priority (oldest = first in list).
local HINT_DEFS: { HintDef } = {
	{
		id = "lab_intro",
		text = "Try the Formula Lab while you wait \xe2\x86\x92",
		dismissAfter = 6,
	},
	{
		id = "market_intro",
		text = "Market is open \xe2\x80\x94 see what your compounds are worth \xe2\x86\x92",
		dismissAfter = 6,
	},
	{
		id = "tier_system",
		text = "Higher tier compounds earn more \xe2\x80\x94 keep experimenting.",
		dismissAfter = 6,
	},
	{
		id = "syndicate_intro",
		text = "Form a Syndicate to unlock Tier 6 synthesis.",
		dismissAfter = 6,
	},
	{
		id = "patent_mechanics",
		text = "Your patent pays weekly dividends. Defend it.",
		dismissAfter = 6,
	},
	{
		id = "event_intro",
		text = "The event is running. Synthesize to earn Flux.",
		dismissAfter = 8,
	},
}

HintTriggerLogic.HINT_DEFS = HINT_DEFS

export type HintState = {
	slots: { [number]: { state: string } }?,
	formulaLog: { { compoundId: string } }?,
	syndicate: any?,
	streak: { day: number, safeUntil: number }?,
	patents: { [string]: any }?,
	flux: any?,
}

local function allSlotsRunning(slots: { [number]: { state: string } }?): boolean
	if not slots or next(slots) == nil then
		return false
	end
	for _, slot in pairs(slots) do
		if slot.state ~= "RUNNING" then
			return false
		end
	end
	return true
end

local function formulaLogCount(log: { any }?): number
	if not log then
		return 0
	end
	return #log
end

-- Returns all hint defs whose trigger conditions are met and that have not been shown.
function HintTriggerLogic.evaluate(state: HintState, shownHints: { [string]: boolean }): { HintDef }
	local triggered: { HintDef } = {}
	local logCount = formulaLogCount(state.formulaLog)

	for _, def in ipairs(HINT_DEFS) do
		if shownHints[def.id] then
			continue
		end

		local fires = false
		local id = def.id

		if id == "lab_intro" then
			fires = allSlotsRunning(state.slots) and logCount == 0
		elseif id == "market_intro" then
			fires = logCount >= 1
		elseif id == "tier_system" then
			fires = logCount == 1 -- first discovery only; shown-once logic prevents re-fire
		elseif id == "syndicate_intro" then
			local day = state.streak and state.streak.day or 0
			fires = day >= 7 and state.syndicate == nil
		elseif id == "patent_mechanics" then
			fires = state.patents ~= nil and next(state.patents) ~= nil
		elseif id == "event_intro" then
			fires = state.flux ~= nil
		end

		if fires then
			table.insert(triggered, def)
		end
	end

	return triggered
end

return HintTriggerLogic
