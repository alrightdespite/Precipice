-- DataService: ProfileStore session management, schema migrations, PendingCredits drain.
-- All other services read/write player data exclusively through this module.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local ProfileStore = require(game:GetService("ServerScriptService").ServerPackages.ProfileStore)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)
local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local ProfileTemplate = require(game:GetService("ReplicatedStorage").Shared.Core.ProfileTemplate)

-- Add migration functions here as the schema evolves.
-- Each entry [N] upgrades profile.Data from schemaVersion N to N+1.
-- Mutations must be in-place — never replace the data table.
local migrations: { [number]: (data: any) -> () } = {
	[1] = function(data)
		if data.streak and data.streak.lastLoginUnix ~= nil then
			data.streak.lastLoginAt = data.streak.lastLoginUnix
			data.streak.lastLoginUnix = nil
		end
		if data.contracts and data.contracts.list ~= nil then
			data.contracts.slots = data.contracts.list
			data.contracts.list = nil
		end
	end,
	[2] = function(data)
		if data.eventState then
			if data.eventState.extractionFluxToday == nil then
				data.eventState.extractionFluxToday = { date = "", count = 0 }
			end
			if data.eventState.milestoneClaimed == nil then
				data.eventState.milestoneClaimed = {}
			end
		end
	end,
	[3] = function(_data)
		-- syndicate field added in schemaVersion 4.
		-- Reconcile() handles new fields; no action needed here.
	end,
	[4] = function(data)
		-- championships field (§18 Sprint champions) added in schemaVersion 5.
		if data.championships == nil then
			data.championships = {}
		end
	end,
}

local STORE_NAME = "PlayerData_v1"
local KEY_PREFIX = "Player_"
local PENDING_CREDITS_STORE = "PendingCredits"

type Session = { profile: any }
local activeSessions: { [number]: Session } = {}
local profileStore: any

local DataService = {}
DataService.onProfileLoaded = Signal.new() -- (userId: number)
DataService.onProfileReleased = Signal.new() -- (userId: number)

local function flushPendingCredits(userId: number, data: any)
	local store = DataStoreService:GetDataStore(PENDING_CREDITS_STORE)
	local key = "PendingCredits/" .. tostring(userId)
	local toApply: { { creditId: string, amount: number, source: string } } = {}

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(stored)
			if stored == nil or #(stored.credits or {}) == 0 then
				return nil -- nothing to drain; abort write
			end
			local applied: { [string]: boolean } = {}
			for _, id in ipairs(data.pendingCreditsApplied) do
				applied[id] = true
			end
			for _, credit in ipairs(stored.credits) do
				if not applied[credit.creditId] then
					table.insert(toApply, credit)
				end
			end
			return { credits = {} } -- wipe store atomically
		end)
	end)

	if not ok then
		warn("DataService: PendingCredits flush failed for", userId, "—", err)
		return -- never block EndSession on a secondary DS failure
	end

	for _, credit in ipairs(toApply) do
		data.balances.pellets += credit.amount
		table.insert(data.pendingCreditsApplied, credit.creditId)
	end
end

-- Public wrapper for PrestigeService to drain PendingCredits before reset.
function DataService.drainPending(userId: number, data: any)
	flushPendingCredits(userId, data)
end

function DataService.init()
	assert(profileStore == nil, "DataService.init called twice")
	profileStore = ProfileStore.New(STORE_NAME, ProfileTemplate.DEFAULT)

	game:BindToClose(function()
		local remaining = 0
		for userId, session in pairs(activeSessions) do
			remaining += 1
			task.spawn(function()
				flushPendingCredits(userId, session.profile.Data)
				session.profile:EndSession()
				remaining -= 1
			end)
		end
		while remaining > 0 do
			task.wait(0.1)
		end
	end)
end

function DataService.openSession(player: Player)
	local userId = player.UserId

	local profile = profileStore:StartSessionAsync(KEY_PREFIX .. tostring(userId), {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})

	if profile == nil then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	if not player:IsDescendantOf(Players) then
		-- Player left while we were loading
		profile:EndSession()
		return
	end

	profile:AddUserId(userId)
	profile:Reconcile()
	ProfileTemplate.migrate(profile.Data, migrations, GameConfig.SCHEMA_VERSION)

	-- Session stolen by another server (e.g. player rejoined elsewhere)
	profile.OnSessionEnd:Connect(function()
		activeSessions[userId] = nil
		player:Kick("Your session was claimed by another server. Please rejoin.")
		DataService.onProfileReleased:Fire(userId)
	end)

	activeSessions[userId] = { profile = profile }
	DataService.onProfileLoaded:Fire(userId)
end

function DataService.closeSession(player: Player)
	local userId = player.UserId
	local session = activeSessions[userId]
	if session == nil then
		return
	end
	activeSessions[userId] = nil
	flushPendingCredits(userId, session.profile.Data)
	session.profile:EndSession()
	DataService.onProfileReleased:Fire(userId)
end

-- Returns true if a session is active for userId.
function DataService.isLoaded(userId: number): boolean
	return activeSessions[userId] ~= nil
end

-- Returns profile.Data for userId. Errors if not loaded — never returns nil.
function DataService.getProfile(userId: number): any
	local session = activeSessions[userId]
	assert(session ~= nil, "DataService.getProfile: no session for userId " .. tostring(userId))
	return session.profile.Data
end

-- Runs fn(profileData) synchronously under the active session.
-- Other services call this to mutate player data; ProfileStore autosaves.
function DataService.updateProfile(userId: number, fn: (data: any) -> ())
	local session = activeSessions[userId]
	assert(session ~= nil, "DataService.updateProfile: no session for userId " .. tostring(userId))
	fn(session.profile.Data)
end

return DataService
