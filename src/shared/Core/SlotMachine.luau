-- SlotMachine: pure slot state machine (doc §8, E1, §14).
-- No Roblox globals. No data-module imports. Lune-testable.
--
-- Contract:
--   Slots are stored as a dense array where each record carries a stable `index`
--   field (1..cap). Empty slot positions are absent from the array; index is used
--   to identify a slot in C2S remotes.
--
--   Callers (SlotService) look up compound data and pass derived values:
--     baseWorkSeconds = compound.timeMins * 60
--   SlotMachine applies the stabilized multiplier (1.5, matches EconomyConstants).
--
--   startExtraction(slots, compoundId, baseWorkSeconds, now, cap) → (newSlots, newIndex?, err?)
--   startSynthesis(slots, resultId, baseWorkSeconds, stabilized, slotIndex, now, cap) → (newSlots, err?)
--   cancel(slots, slotIndex)              → (newSlots, err?)
--   reveal(slots, slotIndex, now)         → (newSlots, compoundId?, isNatural, err?)
--   skip(slots, slotIndex, now)           → (newSlots, err?)
--   tick(slots, now)                      → (newSlots, completedIndices)

export type SlotKind = "extraction" | "synthesis"

export type SlotRecord = {
	index: number,
	kind: SlotKind,
	compoundId: string,
	workRemaining: number,
	lastTickAt: number,
	mode: "online" | "offline" | "joint",
	isStabilized: boolean,
	isNatural: boolean,
	startedAt: number,
}

-- Mirrors EconomyConstants.STABILIZE_MULTIPLIER = 1.5
local STABILIZE_MULTIPLIER = 1.5

-- Work-unit settle math (canonical in TimerMath.luau; duplicated here so SlotMachine
-- carries no require() calls and stays Lune-testable).
local ONLINE_RATE = 1.0
local OFFLINE_RATE = 0.8

local function settleRun(run: SlotRecord, now: number): { compoundId: string, workRemaining: number, lastTickAt: number, mode: string }
	local elapsed = math.max(0, now - run.lastTickAt)
	local rate = if run.mode == "offline" then OFFLINE_RATE else ONLINE_RATE
	return {
		compoundId = run.compoundId,
		workRemaining = math.max(0, run.workRemaining - elapsed * rate),
		lastTickAt = now,
		mode = run.mode,
	}
end

local function isComplete(workRemaining: number): boolean
	return workRemaining <= 0
end

local SlotMachine = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function findByIndex(slots: { SlotRecord }, index: number): (SlotRecord?, number?)
	for pos, slot in ipairs(slots) do
		if slot.index == index then
			return slot, pos
		end
	end
	return nil, nil
end

local function findFreeIndex(slots: { SlotRecord }, cap: number): number?
	local used: { [number]: boolean } = {}
	for _, slot in ipairs(slots) do
		used[slot.index] = true
	end
	for i = 1, cap do
		if not used[i] then
			return i
		end
	end
	return nil
end

local function copySlots(slots: { SlotRecord }): { SlotRecord }
	local copy: { SlotRecord } = {}
	for _, s in ipairs(slots) do
		table.insert(copy, s)
	end
	return copy
end

-- ── State transitions ──────────────────────────────────────────────────────

-- Auto-picks the lowest free slot index.
function SlotMachine.startExtraction(
	slots: { SlotRecord },
	compoundId: string,
	baseWorkSeconds: number,
	now: number,
	cap: number
): ({ SlotRecord }, number?, string?)
	local freeIdx = findFreeIndex(slots, cap)
	if not freeIdx then
		return slots, nil, "no free slot"
	end
	local newSlots = copySlots(slots)
	table.insert(newSlots, {
		index = freeIdx,
		kind = "extraction",
		compoundId = compoundId,
		workRemaining = baseWorkSeconds,
		lastTickAt = now,
		mode = "online",
		isStabilized = false,
		isNatural = true,
		startedAt = now,
	})
	return newSlots, freeIdx, nil
end

-- Player specifies slotIndex; must be free and within [1, cap].
-- resultCompoundId is pre-resolved by SlotService via RecipeResolver.
function SlotMachine.startSynthesis(
	slots: { SlotRecord },
	resultCompoundId: string,
	baseWorkSeconds: number,
	stabilized: boolean,
	slotIndex: number,
	now: number,
	cap: number
): ({ SlotRecord }, string?)
	if slotIndex < 1 or slotIndex > cap then
		return slots, "slot index out of range"
	end
	local existing, _ = findByIndex(slots, slotIndex)
	if existing then
		return slots, "slot already occupied"
	end
	local workRemaining = if stabilized then baseWorkSeconds * STABILIZE_MULTIPLIER else baseWorkSeconds
	local newSlots = copySlots(slots)
	table.insert(newSlots, {
		index = slotIndex,
		kind = "synthesis",
		compoundId = resultCompoundId,
		workRemaining = workRemaining,
		lastTickAt = now,
		mode = "online",
		isStabilized = stabilized,
		isNatural = true,
		startedAt = now,
	})
	return newSlots, nil
end

-- Removes slot with no compound award (spec: "Cancel: zero out slot, no reward").
function SlotMachine.cancel(slots: { SlotRecord }, slotIndex: number): ({ SlotRecord }, string?)
	local _, pos = findByIndex(slots, slotIndex)
	if not pos then
		return slots, "no slot at index " .. slotIndex
	end
	local newSlots = copySlots(slots)
	table.remove(newSlots, pos)
	return newSlots, nil
end

-- Removes slot and returns the compound. Only succeeds when workRemaining <= 0.
function SlotMachine.reveal(
	slots: { SlotRecord },
	slotIndex: number,
	now: number
): ({ SlotRecord }, string?, boolean, string?)
	local slot, pos = findByIndex(slots, slotIndex)
	if not slot or not pos then
		return slots, nil, false, "no slot at index " .. slotIndex
	end
	local settled = settleRun(slot, now)
	if not isComplete(settled.workRemaining) then
		return slots, nil, false, "slot not complete"
	end
	local newSlots = copySlots(slots)
	table.remove(newSlots, pos)
	return newSlots, slot.compoundId, slot.isNatural, nil
end

-- Sets isNatural = false and drains workRemaining to 0 (§14 Natural Completion Rule).
function SlotMachine.skip(slots: { SlotRecord }, slotIndex: number, now: number): ({ SlotRecord }, string?)
	local slot, pos = findByIndex(slots, slotIndex)
	if not slot or not pos then
		return slots, "no slot at index " .. slotIndex
	end
	local settled = settleRun(slot, now)
	local newSlots = copySlots(slots)
	newSlots[pos] = {
		index = slot.index,
		kind = slot.kind,
		compoundId = settled.compoundId,
		workRemaining = 0,
		lastTickAt = now,
		mode = settled.mode,
		isStabilized = slot.isStabilized,
		isNatural = false,
		startedAt = slot.startedAt,
	}
	return newSlots, nil
end

-- Advances all running slots by elapsed time. Already-complete slots pass through unchanged.
-- Returns updated slots and the indices of slots that reached zero this tick.
function SlotMachine.tick(slots: { SlotRecord }, now: number): ({ SlotRecord }, { number })
	local newSlots: { SlotRecord } = {}
	local completedIndices: { number } = {}
	for _, slot in ipairs(slots) do
		if slot.workRemaining > 0 then
			local settled = settleRun(slot, now)
			table.insert(newSlots, {
				index = slot.index,
				kind = slot.kind,
				compoundId = settled.compoundId,
				workRemaining = settled.workRemaining,
				lastTickAt = settled.lastTickAt,
				mode = settled.mode,
				isStabilized = slot.isStabilized,
				isNatural = slot.isNatural,
				startedAt = slot.startedAt,
			})
			if isComplete(settled.workRemaining) then
				table.insert(completedIndices, slot.index)
			end
		else
			-- Already complete — pass through without touching lastTickAt
			table.insert(newSlots, slot)
		end
	end
	return newSlots, completedIndices
end

return SlotMachine
