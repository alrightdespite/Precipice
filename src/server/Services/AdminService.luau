-- AdminService: server-side, chat-driven admin/moderation commands.
-- Per docs/specs/AdminService.md: NO client remote — commands arrive via Player.Chatted and are
-- parsed server-side. Gated by a UserId whitelist (GameConfig.ADMIN_USER_IDS) plus the place
-- owner (game.CreatorId). Every accepted action is logged to the server console with the issuing
-- admin's UserId. Non-whitelisted players' messages are ignored outright.
--
-- Commands (prefix "/"):
--   /give <compoundId> [qty]   grant compound units to yourself
--   /setbalance <amount>       set your own Pellet balance
--   /kick <player>             kick a player (name prefix or UserId)
--   /inspect [player]          print a profile snapshot to the console (self if omitted)
--   /tp <player>               teleport your character to a player

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TextChatService = game:GetService("TextChatService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local DataService = require(ServerScriptService.Server.Services.DataService)
local VaultService = require(ServerScriptService.Server.Services.VaultService)

local AdminService = {}

-- ── Permission ───────────────────────────────────────────────────────────────

function AdminService.isAdmin(userId: number): boolean
	-- The place owner is always an admin (covers solo dev/testing with no committed IDs).
	if game.CreatorType == Enum.CreatorType.User and userId == game.CreatorId then
		return true
	end
	for _, id in ipairs(GameConfig.ADMIN_USER_IDS) do
		if id == userId then
			return true
		end
	end
	return false
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

-- Resolve a player from a token: exact UserId, or case-insensitive name/displayName prefix.
local function findPlayer(token: string): Player?
	local asId = tonumber(token)
	if asId then
		local p = Players:GetPlayerByUserId(asId)
		if p then
			return p
		end
	end
	local lower = token:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == lower or p.DisplayName:lower() == lower then
			return p
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #lower) == lower then
			return p
		end
	end
	return nil
end

-- ── Command dispatch ─────────────────────────────────────────────────────────

local function handleCommand(admin: Player, message: string)
	if message:sub(1, 1) ~= "/" then
		return
	end
	-- Re-check permission at execution time (membership can't change, but defensive).
	if not AdminService.isAdmin(admin.UserId) then
		return
	end

	local args = string.split(message, " ")
	local cmd = args[1]:lower()
	local handled = true

	if cmd == "/give" then
		local compoundId = args[2]
		local qty = math.max(1, math.floor(tonumber(args[3]) or 1))
		if not compoundId or not Compounds[compoundId] then
			warn("[Admin] /give: unknown compound", tostring(compoundId))
			return
		end
		if not DataService.isLoaded(admin.UserId) then
			return
		end
		DataService.updateProfile(admin.UserId, function(data)
			VaultService.applyAward(data, compoundId, qty)
		end)
		VaultService.fireVaultUpdate(admin, DataService.getProfile(admin.UserId))
	elseif cmd == "/setbalance" then
		local amount = tonumber(args[2])
		if amount == nil or not DataService.isLoaded(admin.UserId) then
			return
		end
		DataService.updateProfile(admin.UserId, function(data)
			data.balances.pellets = math.max(0, math.floor(amount))
		end)
	elseif cmd == "/kick" then
		local target = args[2] and findPlayer(args[2])
		if target then
			target:Kick("Kicked by an administrator.")
		end
	elseif cmd == "/inspect" then
		local target = (args[2] and findPlayer(args[2])) or admin
		if DataService.isLoaded(target.UserId) then
			local data = DataService.getProfile(target.UserId)
			print(string.format(
				"[Admin] inspect %s(%d): pellets=%d catalysts=%d rank.lifetime=%d prestige=%d slots=%d",
				target.Name,
				target.UserId,
				data.balances.pellets,
				data.balances.catalysts,
				data.rank.lifetime,
				data.prestige.level,
				#data.slots
			))
		end
	elseif cmd == "/tp" then
		local target = args[2] and findPlayer(args[2])
		local adminChar = admin.Character
		local targetChar = target and target.Character
		if adminChar and targetChar and targetChar.PrimaryPart then
			adminChar:PivotTo(targetChar:GetPivot())
		end
	else
		handled = false
	end

	if handled then
		-- Audit log: every accepted admin action, with the issuing admin's UserId.
		print(string.format("[Admin] %s(%d): %s", admin.Name, admin.UserId, message))
	end
end

-- ── Init ───────────────────────────────────────────────────────────────────

function AdminService.init()
	-- Primary path: register server-side TextChatCommands. TextChatService routes a typed "/"
	-- message to the matching command and fires Triggered ON THE SERVER (textSource = sender).
	-- This is the reliable way to catch "/" commands under TextChatService — Player.Chatted does
	-- not fire for "/" messages there, and client-created commands trigger unreliably.
	local ALIASES = { "/give", "/setbalance", "/kick", "/inspect", "/tp" }
	for _, alias in ipairs(ALIASES) do
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "Admin_" .. string.sub(alias, 2)
		cmd.PrimaryAlias = alias
		cmd.AutocompleteVisible = false
		cmd.Triggered:Connect(function(textSource: TextSource, unfilteredText: string)
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if not player or not AdminService.isAdmin(player.UserId) then
				return
			end
			local ok, err = pcall(handleCommand, player, unfilteredText)
			if not ok then
				warn("[Admin] command error:", err)
			end
		end)
		cmd.Parent = TextChatService
	end

	-- Fallback: Player.Chatted still catches non-"/" / legacy / programmatic messages.
	local function wire(player: Player)
		player.Chatted:Connect(function(message)
			if AdminService.isAdmin(player.UserId) then
				local ok, err = pcall(handleCommand, player, message)
				if not ok then
					warn("[Admin] command error:", err)
				end
			end
		end)
	end

	Players.PlayerAdded:Connect(wire)
	for _, player in ipairs(Players:GetPlayers()) do
		wire(player)
	end
end

return AdminService
