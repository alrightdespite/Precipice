-- SoundController: the game's audio backbone. Owns two SoundGroups (Music / SFX) under SoundService,
-- plays one-shot UI/interaction SFX, and exposes enable/disable that the Settings screen drives.
--
-- The whole game currently ships with ZERO audio, and the Settings Music/SFX toggles were dead; this
-- controller wires both. Asset IDs live in the SFX/MUSIC tables below and are placeholder `0` until the
-- real Roblox audio is approved — `playSfx` and the music loop no-op cleanly while ids are 0, so every
-- call site is safe to wire ahead of the audio landing.
--
-- Enabled state is mirrored onto LocalPlayer attributes ("MusicEnabled" / "SfxEnabled") so the Settings
-- toggles can read the current value on open. (Cross-relog persistence would need a profile field — not
-- yet in the schema; this survives respawns within a session.)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local SoundController = {}

-- One-shot SFX catalog. id = Roblox asset id (0 = unset → no-op). volume is the per-sound base.
local SFX: { [string]: { id: number, volume: number } } = {
	uiClick = { id = 0, volume = 0.45 },
	uiOpen = { id = 0, volume = 0.5 },
	uiClose = { id = 0, volume = 0.4 },
	purchase = { id = 0, volume = 0.6 },
	slotDone = { id = 0, volume = 0.6 },
	reveal = { id = 0, volume = 0.7 },
}

-- Looping hub background music.
local MUSIC = { id = 0, volume = 0.35 }

local _musicGroup: SoundGroup? = nil
local _sfxGroup: SoundGroup? = nil
local _musicSound: Sound? = nil
local _musicOn = true
local _sfxOn = true
local _initialized = false

local function ensureGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = 1
	g.Parent = SoundService
	return g
end

-- Play a catalogued one-shot SFX. Safe no-op if SFX disabled, name unknown, or id unset.
function SoundController.playSfx(name: string)
	if not _sfxOn or not _sfxGroup then
		return
	end
	local e = SFX[name]
	if not e or e.id <= 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(e.id)
	s.Volume = e.volume
	s.SoundGroup = _sfxGroup
	s.Parent = SoundService
	s.Ended:Once(function()
		s:Destroy()
	end)
	-- Fallback cleanup in case the asset fails to load / never fires Ended.
	task.delay(8, function()
		if s and s.Parent then
			s:Destroy()
		end
	end)
	s:Play()
end

function SoundController.setMusicEnabled(on: boolean)
	_musicOn = on
	if _musicGroup then
		_musicGroup.Volume = on and 1 or 0
	end
	local lp = Players.LocalPlayer
	if lp then
		lp:SetAttribute("MusicEnabled", on)
	end
end

function SoundController.setSfxEnabled(on: boolean)
	_sfxOn = on
	if _sfxGroup then
		_sfxGroup.Volume = on and 1 or 0
	end
	local lp = Players.LocalPlayer
	if lp then
		lp:SetAttribute("SfxEnabled", on)
	end
end

function SoundController.isMusicEnabled(): boolean
	return _musicOn
end

function SoundController.isSfxEnabled(): boolean
	return _sfxOn
end

function SoundController.init(): typeof(SoundController)
	if _initialized then
		return SoundController
	end
	_initialized = true

	_musicGroup = ensureGroup("Music")
	_sfxGroup = ensureGroup("SFX")

	-- Restore any prior in-session preference from attributes (default on).
	local lp = Players.LocalPlayer
	if lp then
		local m = lp:GetAttribute("MusicEnabled")
		local x = lp:GetAttribute("SfxEnabled")
		if type(m) == "boolean" then
			_musicOn = m
		end
		if type(x) == "boolean" then
			_sfxOn = x
		end
	end
	SoundController.setMusicEnabled(_musicOn)
	SoundController.setSfxEnabled(_sfxOn)

	-- Hub music loop (no-op until MUSIC.id is set).
	if MUSIC.id > 0 then
		local s = Instance.new("Sound")
		s.Name = "HubMusic"
		s.SoundId = "rbxassetid://" .. tostring(MUSIC.id)
		s.Volume = MUSIC.volume
		s.Looped = true
		s.SoundGroup = _musicGroup
		s.Parent = SoundService
		s:Play()
		_musicSound = s
	end

	return SoundController
end

return SoundController
