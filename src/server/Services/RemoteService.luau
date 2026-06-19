-- RemoteService: creates every remote at boot from Remotes/Manifest.
-- No remote instance may ever be authored outside this service (doc E13).
-- Boot order: called by GameInit after Config and Data tables load.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Manifest = require(ReplicatedStorage.Shared.Remotes.Manifest)

local REMOTES_FOLDER_NAME = "Remotes"

local RemoteService = {}

local _remotesFolder: Folder

function RemoteService.init()
	assert(not _remotesFolder, "RemoteService.init called twice")

	_remotesFolder = Instance.new("Folder")
	_remotesFolder.Name = REMOTES_FOLDER_NAME
	_remotesFolder.Parent = ReplicatedStorage

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
		created += 1
	end

	print(string.format("RemoteService: created %d remotes", created))
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
