-- SeedResolver: deterministic weekly seed (doc §7, E3).
-- No Roblox globals. Clock injected. Lune-testable.
--
-- Contract:
--   The weekly seed is an integer derived from the ISO week number + secret salt (HMAC-style).
--   The salt is never hardcoded here — it is loaded once at server boot via DataService
--   and injected via setSalt(). The salt is never sent to the client.
--   getWeekSeed(isoWeekNumber) → integer seed (requires salt to be set)
--   getCurrentWeekNumber(unixTime) → ISO week number (pure, no salt needed)
--   Note: actual HMAC requires a crypto library; we approximate with string hashing since
--   Roblox's Luau does not ship a native HMAC. A proper implementation replaces this stub
--   with a Lune-compatible hash when the service is wired up in Phase 2.

local SeedResolver = {}

local _salt: string? = nil

function SeedResolver.setSalt(salt: string)
	assert(not _salt, "SeedResolver: salt already set")
	assert(type(salt) == "string" and #salt > 0, "SeedResolver: salt must be a non-empty string")
	_salt = salt
end

function SeedResolver.hasSalt(): boolean
	return _salt ~= nil
end

-- Simple deterministic hash combining week number and salt.
-- In production this is replaced with a proper HMAC-SHA256 approach.
local function hashWeek(week: number, salt: string): number
	local combined = tostring(week) .. ":" .. salt
	local h = 2166136261
	for i = 1, #combined do
		h = bit32.bxor(h, string.byte(combined, i))
		h = (h * 16777619) % 2147483647
	end
	return h
end

function SeedResolver.getWeekSeed(isoWeekNumber: number): number
	assert(_salt, "SeedResolver: salt not set — call setSalt() during server boot")
	return hashWeek(isoWeekNumber, _salt)
end

-- Returns ISO week number for a given Unix timestamp (UTC).
-- Uses the ISO 8601 definition: week 1 is the week containing the first Thursday of the year.
function SeedResolver.getCurrentWeekNumber(unixTime: number): number
	-- Day of week: 0=Sun ... 6=Sat. ISO: 1=Mon ... 7=Sun.
	local days = math.floor(unixTime / 86400)
	local dow = (days + 4) % 7 -- 0=Mon .. 6=Sun (Thursday=3)
	-- Nearest Thursday: this week's Thursday
	local thursday = days - dow + 3
	-- January 1 of the year of that Thursday
	local year = 1970
	local yearStart = 0
	-- Compute year and yearStart for the Thursday day count
	-- (Simplified; accurate for years 1970–2100)
	while true do
		local daysInYear = if (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then 366 else 365
		if yearStart + daysInYear > thursday then
			break
		end
		yearStart = yearStart + daysInYear
		year = year + 1
	end
	local jan1Dow = (yearStart + 4) % 7 -- 0=Mon
	-- Week number: how many weeks from Jan 1 Monday to Thursday
	local weekNum = math.floor((thursday - yearStart - (0 - jan1Dow) % 7) / 7) + 1
	return weekNum
end

return SeedResolver
