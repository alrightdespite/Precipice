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
	SCHEMA_VERSION = 2,

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
}
