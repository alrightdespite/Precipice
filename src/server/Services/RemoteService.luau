-- RemoteService: creates every remote at boot from Remotes/Manifest.
-- No remote instance may ever be authored outside this service (doc E13).
-- Boot order: called by GameInit after Config and Data tables load.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Manifest = require(ReplicatedStorage.Shared.Remotes.Manifest)
local RateLimiter = require(ReplicatedStorage.Shared.Core.RateLimiter)

local REMOTES_FOLDER_NAME = "Remotes"

local RemoteService = {}

local _remotesFolder: Folder

-- name → Manifest entry, built at init for O(1) rateLimit lookup in setInvoke.
local _entryByName: { [string]: any } = {}

-- Token buckets keyed "<userId>:<remoteName>" for C2S throttling (§D). os.clock() is a
-- monotonic high-resolution server timer — correct for sub-second rates (os.time's 1s
-- resolution is too coarse).
local _buckets: { [string]: { tokens: number, lastRefill: number } } = {}

function RemoteService.init()
	assert(not _remotesFolder, "RemoteService.init called twice")

	-- Build the folder fully BEFORE parenting it into ReplicatedStorage, so the client never
	-- observes a half-populated Remotes folder (the children replicate as one subtree). The
	-- client still WaitForChilds each remote as the definitive guard against progressive
	-- replication; this just makes the common case arrive complete.
	_remotesFolder = Instance.new("Folder")
	_remotesFolder.Name = REMOTES_FOLDER_NAME

	local created = 0
	for _, entry in ipairs(Manifest) do
		-- studioOnly remotes (e.g. the debug hook) never exist in production.
		if entry.studioOnly and not RunService:IsStudio() then
			continue
		end

		local existing = _remotesFolder:FindFirstChild(entry.name)
		if existing then
			error(string.format("RemoteService: duplicate remote '%s' in Manifest", entry.name))
		end

		local remote: RemoteEvent | RemoteFunction
		if entry.kind == "Event" then
			remote = Instance.new("RemoteEvent")
		else
			remote = Instance.new("RemoteFunction")
		end
		remote.Name = entry.name
		remote.Parent = _remotesFolder
		_entryByName[entry.name] = entry
		created += 1
	end

	-- Parent last: the folder enters ReplicatedStorage already holding all remotes.
	_remotesFolder.Parent = ReplicatedStorage

	-- Drop a leaving player's throttle buckets so the table never grows without bound.
	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.clear(_buckets, tostring(player.UserId) .. ":")
	end)

	print(string.format("RemoteService: created %d remotes", created))
end

-- Register a C2S RemoteFunction handler with server-side rate limiting (§D). The Manifest
-- rateLimit (requests/sec/player) is enforced per (player, remote): a request over the limit
-- is rejected with (nil, "rate_limited") and the handler never runs. rateLimit = nil means no
-- throttle. Every C2S handler must register through this — never assign OnServerInvoke directly.
function RemoteService.setInvoke(name: string, handler: (Player, ...any) -> ...any)
	local fn = RemoteService.getFunction(name)
	local entry = _entryByName[name]
	local rate = entry and entry.rateLimit

	if not rate then
		fn.OnServerInvoke = handler
		return
	end

	-- Capacity = the rate rounded up to at least one whole token, so a 2/s remote may burst 2
	-- and a 0.1/s remote allows a single call then refills slowly.
	local capacity = math.max(1, math.ceil(rate))

	fn.OnServerInvoke = function(player: Player, ...)
		local key = tostring(player.UserId) .. ":" .. name
		-- Drop silently when over the limit — emitting a log per dropped request would itself
		-- be a log-flood vector under spam.
		if not RateLimiter.allow(_buckets, key, rate, capacity, os.clock()) then
			return nil, "rate_limited"
		end
		return handler(player, ...)
	end
end

function RemoteService.getEvent(name: string): RemoteEvent
	assert(_remotesFolder, "RemoteService not initialized")
	local remote = _remotesFolder:FindFirstChild(name)
	assert(remote and remote:IsA("RemoteEvent"), string.format("RemoteService: no RemoteEvent named '%s'", name))
	return remote :: RemoteEvent
end

function RemoteService.getFunction(name: string): RemoteFunction
	assert(_remotesFolder, "RemoteService not initialized")
	local remote = _remotesFolder:FindFirstChild(name)
	assert(remote and remote:IsA("RemoteFunction"), string.format("RemoteService: no RemoteFunction named '%s'", name))
	return remote :: RemoteFunction
end

return RemoteService
