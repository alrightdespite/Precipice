-- SeedService: weekly seed management (doc §7, SeedService spec).
-- Reads salt from DataStore Config/SeedSalt; generates on first boot.
-- Salt is NEVER sent to the client (design doc constraint).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SeedResolver = require(ReplicatedStorage.Shared.Core.SeedResolver)
local Sha256 = require(ReplicatedStorage.Shared.Core.Sha256)

local CONFIG_STORE = "Config"

local SeedService = {}

function SeedService.init()
	local store = DataStoreService:GetDataStore(CONFIG_STORE)
	local salt: string?

	local readOk, readErr = pcall(function()
		salt = store:GetAsync(GameConfig.SEED_SALT_KEY)
	end)
	if not readOk then
		error("SeedService: salt read failed — " .. tostring(readErr))
	end

	if not salt or salt == "" then
		salt = SeedService._generateSalt()
		local writeOk, writeErr = pcall(function()
			store:SetAsync(GameConfig.SEED_SALT_KEY, salt)
		end)
		if not writeOk then
			error("SeedService: salt write failed — " .. tostring(writeErr))
		end
	end

	SeedResolver.setSalt(salt :: string)
	-- Inject the real HMAC-SHA256 so the weekly seed is HMAC(salt, "week:N") (E3 hardening).
	SeedResolver.setHasher(Sha256.hmac)
end

function SeedService.getCurrentWeekSeed(): number
	return SeedResolver.getWeekSeed(SeedResolver.getCurrentWeekNumber(os.time()))
end

-- Generates a random 32-char hex string. Not cryptographically secure,
-- but sufficient for weekly seed rotation (the salt is stored server-side only).
function SeedService._generateSalt(): string
	local parts = {}
	for _ = 1, 32 do
		table.insert(parts, string.format("%x", math.random(0, 15)))
	end
	return table.concat(parts)
end

return SeedService
