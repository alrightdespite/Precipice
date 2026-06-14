-- GameConfig: hand-authored game-wide constants.
-- These are authoritative here; generated Data modules never override them.

return {
	-- DataStore key that holds the server-generated seed salt.
	-- The salt is generated on first server boot and persisted here forever.
	-- It is never hardcoded in source (Plan Task 3).
	SEED_SALT_KEY = "Config/SeedSalt",

	-- Server size (doc §31)
	MAX_PLAYERS_PER_SERVER = 8,

	-- Offline income caps (doc §10)
	OFFLINE_CAP_BASE_HOURS = 12,
	OFFLINE_CAP_EXTENDED_HOURS = 24,
	OFFLINE_CAP_PRESTIGE4_BONUS_HOURS = 3.6,

	-- Floor income rate when all personal slots are empty (doc §10)
	FLOOR_INCOME_RATE_PER_MIN = 2,

	-- Slot caps (doc §8)
	BASE_SLOTS = 5,
	EXPANDED_LAB_BONUS = 2,
	MAX_SLOTS = 10,

	-- Schema version (H8)
	SCHEMA_VERSION = 3,

	-- Monday job epoch DataStore key
	GLOBAL_JOBS_KEY = "GlobalJobs",

	-- MessagingService topic for cross-server announcements
	ANNOUNCEMENT_TOPIC = "precipice:announcements",
	EPOCH_TOPIC = "precipice:epoch",

	-- Announcement queue gap (doc §15)
	ANNOUNCEMENT_GAP_SECONDS = 30,

	-- Decay sweep interval (E2)
	SWEEP_INTERVAL_SECONDS = 15 * 60,

	-- Maximum simultaneous active challenges per holder (doc §15)
	MAX_ACTIVE_CHALLENGES = 3,

	-- Gamepass IDs (doc §25) — replace with real IDs before launch
	GAMEPASS_EXPANDED_LAB = 0, -- +2 slots (5→7)
	GAMEPASS_EXTENDED_OFFLINE = 0, -- offline cap 12h→24h
	GAMEPASS_COMPOUND_ARCHIVE = 0, -- one archive synthesis per month per compound
	GAMEPASS_EVENT_PASS = 0, -- 400 Robux: 2× Flux + event pass cosmetics

	-- Developer Product IDs (doc §25) — replace with real IDs before launch
	PRODUCT_TIMER_SKIP = 0, -- 75 Robux: instantly complete one personal slot
	PRODUCT_CATALYST_S = 0, -- 200 Robux: 50 Catalysts
	PRODUCT_CATALYST_L = 0, -- 500 Robux: 150 Catalysts
	PRODUCT_RUSH_ANALYSIS = 0, -- 100 Robux: 3 Rush Analysis uses

	-- Developer Product grants (doc §25)
	PRODUCT_CATALYST_S_AMOUNT = 50,
	PRODUCT_CATALYST_L_AMOUNT = 150,
	PRODUCT_RUSH_USES_AMOUNT = 3,

	-- Catalyst skip cost for personal slots (doc §25)
	CATALYST_SKIP_COST = 30,
}
