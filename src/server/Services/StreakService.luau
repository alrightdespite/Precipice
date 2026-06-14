-- StreakService: daily login streak, grace window, milestone rewards.
-- Doc §20. Called by GameInit on profile load via DataService.onProfileLoaded.

local _remoteService: any = nil
local _econConstants: any = nil

local StreakService = {}

function StreakService._setRemoteService(rs: any)
	_remoteService = rs
end

function StreakService._setEconConstants(ec: any)
	_econConstants = ec
end

function StreakService.init()
	if _remoteService == nil then
		_remoteService = require(game:GetService("ServerScriptService").Server.Services.RemoteService)
	end
	if _econConstants == nil then
		_econConstants = require(game:GetService("ReplicatedStorage").Shared.Config.EconomyConstants)
	end
end

function StreakService.onLogin(player: any, data: any, now: number)
	local EC = _econConstants
	if EC == nil then
		return
	end

	if data.streak == nil then
		data.streak = { day = 0, lastLoginAt = 0 }
	end

	local currentDay = math.floor(now / 86400)
	local lastDay = math.floor(data.streak.lastLoginAt / 86400)
	local daysSinceLogin = currentDay - lastDay

	if daysSinceLogin == 0 then
		if _remoteService then
			_remoteService.getEvent("StreakUpdate"):FireClient(player, {
				day = data.streak.day,
				safeUntil = now + EC.STREAK_WINDOW_HOURS * 3600,
			})
		end
		return
	end

	local streakContinues = false
	if daysSinceLogin == 1 then
		streakContinues = true
	elseif daysSinceLogin == 2 and now < data.streak.lastLoginAt + EC.STREAK_WINDOW_HOURS * 3600 then
		streakContinues = true
	end

	if not streakContinues then
		data.streak.day = 0
	end

	data.streak.day += 1
	data.streak.lastLoginAt = now

	-- Award Pellets (milestone days have 0 in the table)
	local pellets
	if data.streak.day <= 28 then
		pellets = EC.STREAK_DAILY_PELLETS[data.streak.day] or 0
	else
		pellets = EC.STREAK_PELLETS_REPEATING
	end
	if pellets > 0 then
		data.balances.pellets += pellets
	end

	-- Milestone rewards (days 7, 14, 28)
	for i, milestoneDay in ipairs(EC.STREAK_MILESTONE_DAYS) do
		if data.streak.day == milestoneDay then
			data.balances.catalysts += EC.STREAK_MILESTONE_CATALYSTS[i]
			data.rank.currentRun += EC.STREAK_MILESTONE_RANK[i]
			data.rank.lifetime += EC.STREAK_MILESTONE_RANK[i]
			break
		end
	end

	-- Repeating reward (day 35+, every 7 days)
	if data.streak.day >= 35 and (data.streak.day - 35) % EC.STREAK_REPEATING_INTERVAL == 0 then
		data.balances.catalysts += EC.STREAK_REPEATING_CATALYSTS
		data.rank.currentRun += EC.STREAK_REPEATING_RANK
		data.rank.lifetime += EC.STREAK_REPEATING_RANK
	end

	if _remoteService then
		_remoteService.getEvent("StreakUpdate"):FireClient(player, {
			day = data.streak.day,
			safeUntil = now + EC.STREAK_WINDOW_HOURS * 3600,
		})
	end
end

return StreakService
