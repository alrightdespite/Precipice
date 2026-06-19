-- MonetizationService: gamepass cache, dev product receipts, TimerSkip routing.
-- Injection pattern for Lune testability — no Roblox globals at module level.

-- ── Injected dependencies ──────────────────────────────────────────────────

local _dataService: any = nil
local _remoteService: any = nil
local _slotService: any = nil
local _marketplaceService: any = nil
local _gameConfig: any = nil
local _players: any = nil
local _eventCompounds: any = nil

-- ── Internal state ─────────────────────────────────────────────────────────

local _loaded: { [number]: boolean } = {}
local _grantedDecision: any = nil
local _notProcessedDecision: any = nil

local MonetizationService = {}

-- ── Injection helpers ──────────────────────────────────────────────────────

function MonetizationService._setDataService(s: any) _dataService = s end
function MonetizationService._setRemoteService(s: any) _remoteService = s end
function MonetizationService._setSlotService(s: any) _slotService = s end
function MonetizationService._setMarketplaceService(s: any) _marketplaceService = s end
function MonetizationService._setGameConfig(s: any) _gameConfig = s end
function MonetizationService._setPlayers(s: any) _players = s end
function MonetizationService._setEventCompounds(s: any) _eventCompounds = s end
function MonetizationService._setDecisions(granted: any, notProcessed: any)
	_grantedDecision = granted
	_notProcessedDecision = notProcessed
end
function MonetizationService._setLoaded(t: { [number]: boolean }) _loaded = t end

-- ── Gamepass cache ─────────────────────────────────────────────────────────

function MonetizationService.refreshGamepasses(player: Player, data: any)
	local passMap = {
		expandedLab     = _gameConfig.GAMEPASS_EXPANDED_LAB,
		extendedOffline = _gameConfig.GAMEPASS_EXTENDED_OFFLINE,
		compoundArchive = _gameConfig.GAMEPASS_COMPOUND_ARCHIVE,
		eventPass       = _gameConfig.GAMEPASS_EVENT_PASS,
	}
	local passes = {}
	for passName, passId in pairs(passMap) do
		local ok, owns = pcall(function()
			return _marketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		passes[passName] = ok and owns or false
	end
	data.monetization.gamepasses = passes
	if _remoteService then
		_remoteService.getEvent("GamepassStatus"):FireClient(player, { passes = passes })
	end
	-- ExpandedLab changes the personal slot cap (§8); re-push it.
	if _slotService then
		_slotService.fireSlotCap(player, data)
	end
end

function MonetizationService.ownsGamepass(data: any, passName: string): boolean
	return data.monetization.gamepasses[passName] == true
end

-- ── Slot cap ──────────────────────────────────────────────────────────────

function MonetizationService.getSlotCap(data: any): number
	local level = data.prestige.level
	local bonus = (level >= 1 and 1 or 0) + (level >= 3 and 1 or 0) + (level >= 5 and 1 or 0)
	local expandedBonus = MonetizationService.ownsGamepass(data, "expandedLab")
		and _gameConfig.EXPANDED_LAB_BONUS
		or 0
	return math.min(
		_gameConfig.BASE_SLOTS + bonus + expandedBonus,
		_gameConfig.MAX_SLOTS
	)
end

-- ── Offline cap ───────────────────────────────────────────────────────────

function MonetizationService.getOfflineCap(data: any): number
	local base = MonetizationService.ownsGamepass(data, "extendedOffline")
		and _gameConfig.OFFLINE_CAP_EXTENDED_HOURS
		or _gameConfig.OFFLINE_CAP_BASE_HOURS
	local prestigeBonus = data.prestige.level >= 4
		and _gameConfig.OFFLINE_CAP_PRESTIGE4_BONUS_HOURS
		or 0
	return base + prestigeBonus
end

-- ── Catalyst skip deduction ───────────────────────────────────────────────

function MonetizationService.deductCatalystSkip(data: any): boolean
	if data.balances.catalysts >= _gameConfig.CATALYST_SKIP_COST then
		data.balances.catalysts -= _gameConfig.CATALYST_SKIP_COST
		return true
	end
	return false
end

-- ── TimerSkip routing ─────────────────────────────────────────────────────

function MonetizationService.applyTimerSkip(player: Player, data: any)
	local runningIdx: number? = nil
	for _, slot in ipairs(data.slots) do
		if slot.workRemaining > 0 then
			if runningIdx == nil or slot.index < (runningIdx :: number) then
				runningIdx = slot.index
			end
		end
	end
	if runningIdx then
		_slotService.applySkipToSlot(player, runningIdx)
	else
		data.monetization.timerSkipUses = (data.monetization.timerSkipUses or 0) + 1
	end
end

-- ── CompoundArchive monthly grant ─────────────────────────────────────────

function MonetizationService.grantArchiveUses(player: Player, data: any, now: number)
	local monthKey = os.date("!%Y-%m", now) :: string
	if data.monetization.archiveUsesByMonth[monthKey] then
		return
	end
	data.monetization.archiveUsesByMonth[monthKey] = true
	data.formulaLog.archiveAccess = data.formulaLog.archiveAccess or {}
	for compoundId in pairs(_eventCompounds) do
		data.formulaLog.archiveAccess[compoundId] = true
	end
	if _remoteService and player then
		_remoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			data.balances.pellets,
			data.balances.catalysts,
			data.monetization.rushUses,
			data.monetization.timerSkipUses or 0
		)
	end
end

-- ── ProcessReceipt ────────────────────────────────────────────────────────

function MonetizationService._processReceipt(receiptInfo: any): any
	local userId: number = receiptInfo.PlayerId
	local player = _players:GetPlayerByUserId(userId)

	if not _loaded[userId] then
		return _notProcessedDecision
	end

	local purchaseKey = tostring(receiptInfo.PurchaseId)
	local productId: number = receiptInfo.ProductId

	local capturedBalances: any = nil
	local capturedMonetization: any = nil
	local alreadyGranted = false

	_dataService.updateProfile(userId, function(data: any)
		if data.monetization.receiptLedger[purchaseKey] then
			alreadyGranted = true
			capturedBalances = data.balances
			capturedMonetization = data.monetization
			return
		end

		if productId == _gameConfig.PRODUCT_TIMER_SKIP then
			MonetizationService.applyTimerSkip(player, data)
		elseif productId == _gameConfig.PRODUCT_CATALYST_S then
			data.balances.catalysts += _gameConfig.PRODUCT_CATALYST_S_AMOUNT
		elseif productId == _gameConfig.PRODUCT_CATALYST_L then
			data.balances.catalysts += _gameConfig.PRODUCT_CATALYST_L_AMOUNT
		elseif productId == _gameConfig.PRODUCT_RUSH_ANALYSIS then
			data.monetization.rushUses = math.min(9, data.monetization.rushUses + _gameConfig.PRODUCT_RUSH_USES_AMOUNT)
		else
			warn("MonetizationService: unknown productId", productId)
		end

		data.monetization.receiptLedger[purchaseKey] = true
		capturedBalances = data.balances
		capturedMonetization = data.monetization
	end)

	if not alreadyGranted and player and _remoteService and capturedBalances then
		_remoteService.getEvent("BalanceUpdate"):FireClient(
			player,
			capturedBalances.pellets,
			capturedBalances.catalysts,
			capturedMonetization.rushUses,
			capturedMonetization.timerSkipUses or 0
		)
	end

	return _grantedDecision
end

-- ── Init ──────────────────────────────────────────────────────────────────

function MonetizationService.init()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	_dataService = require(ServerScriptService.Server.Services.DataService)
	_remoteService = require(ServerScriptService.Server.Services.RemoteService)
	_slotService = require(ServerScriptService.Server.Services.SlotService)
	_marketplaceService = game:GetService("MarketplaceService")
	_gameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
	_players = game:GetService("Players")
	_eventCompounds = require(ReplicatedStorage.Shared.Data.EventCompounds)

	_grantedDecision = Enum.ProductPurchaseDecision.PurchaseGranted
	_notProcessedDecision = Enum.ProductPurchaseDecision.NotProcessedYet

	_dataService.onProfileLoaded:Connect(function(userId: number)
		_loaded[userId] = true
	end)
	_dataService.onProfileReleased:Connect(function(userId: number)
		_loaded[userId] = nil
	end)

	_marketplaceService.ProcessReceipt = MonetizationService._processReceipt
end

return MonetizationService
