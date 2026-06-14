-- ContractService: daily contract draw, progress tracking, reward claims.
-- Doc §19, R8, R9. Draw rule: 3 standard (60% Easy/40% Medium) + 2 bonus (30% Medium/70% Hard).

local _remoteService: any = nil
local _dataService: any = nil
local _contractPool: any = nil
local _poolById: { [string]: any } = {}
local _compounds: any = nil

local ContractService = {}

-- ── Injection (for Lune tests) ─────────────────────────────────────────────

function ContractService._setRemoteService(rs: any)
	_remoteService = rs
end

function ContractService._setDataService(ds: any)
	_dataService = ds
end

function ContractService._setCompounds(c: any)
	_compounds = c
end

function ContractService._setContractPool(p: any)
	_contractPool = p
	_poolById = {}
	if p then
		for _, t in ipairs(p.easy) do
			_poolById[t.id] = t
		end
		for _, t in ipairs(p.medium) do
			_poolById[t.id] = t
		end
		for _, t in ipairs(p.hard) do
			_poolById[t.id] = t
		end
	end
end

-- ── Filter evaluation ──────────────────────────────────────────────────────

local function hasDiscoveredTier(data: any, tier: number): boolean
	for compoundId in pairs(data.formulaLog.discovered) do
		local compound = _compounds and _compounds[compoundId]
		if compound and compound.tier == tier then
			return true
		end
	end
	return false
end

local function hasDiscoveredMinTier(data: any, minTier: number): boolean
	for compoundId in pairs(data.formulaLog.discovered) do
		local compound = _compounds and _compounds[compoundId]
		if compound and compound.tier >= minTier then
			return true
		end
	end
	return false
end

local function evaluateFilter(filter: string, data: any): boolean
	if filter == "none" then
		return true
	elseif filter == "t2recipe" then
		return hasDiscoveredTier(data, 2)
	elseif filter == "t3recipe" then
		return hasDiscoveredTier(data, 3)
	elseif filter == "t4recipe" then
		return hasDiscoveredTier(data, 4)
	elseif filter == "t5recipe_syndicate" then
		return hasDiscoveredTier(data, 5) and data.syndicate ~= nil
	elseif filter == "syndicate" then
		return data.syndicate ~= nil
	elseif filter == "syndicate_t4qual" then
		return data.syndicate ~= nil
			and data.prestige ~= nil
			and data.prestige.jointQualLifetime == true
	elseif filter == "undiscovered_pair" then
		return true
	elseif filter == "stabilized_pair" then
		return next(data.formulaLog.validatedPairs) ~= nil
	elseif filter == "t2plus_recipe" then
		return hasDiscoveredMinTier(data, 2)
	end
	return false
end

-- ── Weighted random draw ───────────────────────────────────────────────────

local function weightedDraw(
	pool: { { id: string, weight: number, template: any } }
): (any?, string?)
	local total = 0
	for _, c in ipairs(pool) do
		total += c.weight
	end
	if total == 0 then
		return nil, nil
	end
	local roll = math.random(1, total)
	local cum = 0
	for _, c in ipairs(pool) do
		cum += c.weight
		if roll <= cum then
			return c.template, c.id
		end
	end
	local last = pool[#pool]
	return last.template, last.id
end

-- ── Remote push ────────────────────────────────────────────────────────────

local function fireContractUpdate(player: any, data: any)
	if _remoteService then
		_remoteService.getEvent("ContractUpdate"):FireClient(player, data.contracts.slots)
	end
end

-- ── Public API ─────────────────────────────────────────────────────────────

function ContractService.drawContracts(data: any, now: number)
	if _contractPool == nil then
		return
	end

	local currentDayKey = os.date("!%Y-%m-%d", now) :: string

	local eligibleEasy = {}
	for _, t in ipairs(_contractPool.easy) do
		if evaluateFilter(t.filter, data) then
			table.insert(eligibleEasy, t)
		end
	end

	local eligibleMedium = {}
	for _, t in ipairs(_contractPool.medium) do
		if evaluateFilter(t.filter, data) then
			table.insert(eligibleMedium, t)
		end
	end

	local eligibleHard = {}
	for _, t in ipairs(_contractPool.hard) do
		if evaluateFilter(t.filter, data) then
			table.insert(eligibleHard, t)
		end
	end

	local drawnIds: { [string]: boolean } = {}
	local slots: { any } = {}

	-- Standard slots: 3 from Easy(60) + Medium(40). Fallback to other pool if one is empty.
	for _ = 1, 3 do
		local pool: { { id: string, weight: number, template: any } } = {}
		for _, t in ipairs(eligibleEasy) do
			if not drawnIds[t.id] then
				table.insert(pool, { id = t.id, weight = 60, template = t })
			end
		end
		for _, t in ipairs(eligibleMedium) do
			if not drawnIds[t.id] then
				table.insert(pool, { id = t.id, weight = 40, template = t })
			end
		end
		if #pool == 0 then
			break
		end
		local template, id = weightedDraw(pool)
		if template then
			drawnIds[id :: string] = true
			table.insert(slots, {
				templateId = template.id,
				progress = 0,
				target = template.target,
				completed = false,
				claimed = false,
			})
		end
	end

	-- Bonus slots: 2 from Medium(30) + Hard(70), excluding already drawn.
	for _ = 1, 2 do
		local pool: { { id: string, weight: number, template: any } } = {}
		for _, t in ipairs(eligibleMedium) do
			if not drawnIds[t.id] then
				table.insert(pool, { id = t.id, weight = 30, template = t })
			end
		end
		for _, t in ipairs(eligibleHard) do
			if not drawnIds[t.id] then
				table.insert(pool, { id = t.id, weight = 70, template = t })
			end
		end
		if #pool == 0 then
			break
		end
		local template, id = weightedDraw(pool)
		if template then
			drawnIds[id :: string] = true
			table.insert(slots, {
				templateId = template.id,
				progress = 0,
				target = template.target,
				completed = false,
				claimed = false,
			})
		end
	end

	data.contracts = { dayKey = currentDayKey, slots = slots }
end

function ContractService.refreshIfStale(player: any, data: any, now: number)
	local currentDayKey = os.date("!%Y-%m-%d", now) :: string

	if data.contracts == nil then
		data.contracts = { dayKey = "", slots = {} }
	end

	if data.contracts.dayKey == currentDayKey then
		fireContractUpdate(player, data)
		return
	end

	ContractService.drawContracts(data, now)
	fireContractUpdate(player, data)
end

function ContractService.recordProgress(
	player: any,
	data: any,
	progressType: string,
	amount: number
)
	if data.contracts == nil then
		return
	end

	local changed = false
	for _, slot in ipairs(data.contracts.slots) do
		if slot.completed or slot.claimed then
			continue
		end
		local template = _poolById[slot.templateId]
		if template and template.progressType == progressType then
			slot.progress += amount
			if slot.progress >= slot.target then
				slot.completed = true
			end
			changed = true
		end
	end

	if changed then
		fireContractUpdate(player, data)
	end
end

function ContractService.claimReward(
	player: any,
	data: any,
	slotIndex: number
): (boolean, string?)
	if slotIndex < 1 or slotIndex > 5 then
		return false, "invalid slot index"
	end

	if data.contracts == nil or data.contracts.slots == nil then
		return false, "no contracts"
	end

	local slot = data.contracts.slots[slotIndex]
	if slot == nil then
		return false, "slot not found"
	end
	if not slot.completed then
		return false, "contract not completed"
	end
	if slot.claimed then
		return false, "already claimed"
	end

	local template = _poolById[slot.templateId]
	if template == nil then
		return false, "unknown template"
	end

	data.balances.pellets += template.pelletReward
	data.rank.currentRun += template.rankReward
	data.rank.lifetime += template.rankReward
	slot.claimed = true

	fireContractUpdate(player, data)
	return true, nil
end

function ContractService.init()
	if _remoteService == nil then
		_remoteService = require(game:GetService("ServerScriptService").Server.Services.RemoteService)
	end
	if _dataService == nil then
		_dataService = require(game:GetService("ServerScriptService").Server.Services.DataService)
	end
	if _contractPool == nil then
		ContractService._setContractPool(
			require(game:GetService("ReplicatedStorage").Shared.Data.ContractPool)
		)
	end
	if _compounds == nil then
		_compounds = require(game:GetService("ReplicatedStorage").Shared.Data.Compounds)
	end

	local claimFn = _remoteService.getFunction("ContractClaim")
	claimFn.OnServerInvoke = function(player: any, slotIndex: any)
		if type(slotIndex) ~= "number" then
			return { ok = false, err = "invalid args" }
		end
		slotIndex = math.floor(slotIndex)
		local data = _dataService.getProfile(player.UserId)
		local ok, err = ContractService.claimReward(player, data, slotIndex)
		return ok and { ok = true } or { ok = false, err = err }
	end
end

return ContractService
