-- RevealController: §13 reveal queue and VFX sequence.
-- SlotController.reveal() enqueues here; reveals play one at a time, 0.5s gap.
-- VFX steps (dim WingLight → spotlight → pulse → particles → fade chamber)
-- are guarded by chamber-part availability; card always shows.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Compounds = require(ReplicatedStorage.Shared.Data.Compounds)
local StateController = require(script.Parent.StateController)
local RemoteController = require(script.Parent.RemoteController)
local SlotController = require(script.Parent.SlotController)

-- Tier → spot/particle color (mirrors Theme.Colors.Tier)
local TIER_COLORS: { [number]: Color3 } = {
	[1] = Color3.fromHex("6B7280"),
	[2] = Color3.fromHex("10B981"),
	[3] = Color3.fromHex("3B82F6"),
	[4] = Color3.fromHex("8B5CF6"),
	[5] = Color3.fromHex("F59E0B"),
	[6] = Color3.fromHex("EF4444"),
	[7] = Color3.fromHex("FF6B35"),
}

local _queue: { number } = {}
local _playing = false

-- Lazy-require RevealCard to avoid module load order issues
local _revealCard = nil
local function getRevealCard()
	if not _revealCard then
		_revealCard = require(script.Parent.Parent.UI.RevealCard)
	end
	return _revealCard
end

local function pushQueueState()
	local total = #_queue + (if _playing then 1 else 0)
	StateController.set({ revealQueue = total })
end

-- ── VFX helpers ────────────────────────────────────────────────────────────

local function dimWingLights(chamberPart: BasePart, goalBrightness: number)
	-- WingLight PointLights live in the Lab folder (grandparent of the chamber)
	local chambers = chamberPart.Parent
	local lab = chambers and chambers.Parent
	if not lab then
		return
	end
	for _, inst in ipairs(lab:GetChildren()) do
		if inst:IsA("PointLight") and inst.Name == "WingLight" then
			TweenService:Create(inst, TweenInfo.new(0.4), { Brightness = goalBrightness }):Play()
		end
	end
end

local function pulseLight(light: PointLight, n: number)
	if n <= 0 then
		return
	end
	TweenService:Create(light, TweenInfo.new(0.12), { Brightness = 6 }):Play()
	task.delay(0.12, function()
		TweenService:Create(light, TweenInfo.new(0.12), { Brightness = 0 }):Play()
		task.delay(0.18, function()
			pulseLight(light, n - 1)
		end)
	end)
end

-- Plays the 5 physical VFX steps then calls onDone.
-- All steps skip gracefully when chamberPart is nil.
local function playVFX(chamberPart: BasePart?, tier: number, onDone: () -> ())
	if not chamberPart then
		task.delay(0.5, onDone)
		return
	end

	local tierColor = TIER_COLORS[tier] or TIER_COLORS[1]

	-- 1. Dim wing lights to 20%
	dimWingLights(chamberPart, 0.2)

	-- 2. Spotlight fade in (tier color)
	local spotlight = chamberPart:FindFirstChildWhichIsA("SpotLight")
	if spotlight then
		spotlight.Enabled = true
		spotlight.Color = tierColor
		TweenService:Create(spotlight, TweenInfo.new(0.3), { Brightness = 3 }):Play()
	end

	-- 3. Chamber pulse 3× via PointLight
	local pLight = chamberPart:FindFirstChildWhichIsA("PointLight")
	if pLight then
		pulseLight(pLight, 3)
	end

	-- 4. Particles burst (after pulse starts)
	local particles = chamberPart:FindFirstChildWhichIsA("ParticleEmitter")
	if particles then
		particles.Color = ColorSequence.new(tierColor)
		particles:Emit(math.clamp(tier * 8, 8, 60))
	end

	-- 5. Fade out chamber, then signal done
	local chamberTween = TweenService:Create(
		chamberPart,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	)
	chamberTween.Completed:Connect(onDone)
	task.delay(0.5, function()
		chamberTween:Play()
	end)
end

local function resetChamber(chamberPart: BasePart?)
	if not chamberPart then
		return
	end
	chamberPart.Transparency = 0
	dimWingLights(chamberPart, 1)
	local spotlight = chamberPart:FindFirstChildWhichIsA("SpotLight")
	if spotlight then
		spotlight.Brightness = 0
		spotlight.Enabled = false
	end
end

-- ── Queue drain ────────────────────────────────────────────────────────────

local drainQueue -- forward declaration

local function playReveal(slotIndex: number)
	-- Fire the reveal remote (awards compound server-side, clears slot state)
	local result, err = RemoteController.invoke("SlotReveal", slotIndex)
	if not result or result == false then
		warn("[RevealController] reveal failed for slot", slotIndex, tostring(err))
		_playing = false
		pushQueueState()
		task.delay(0.5, drainQueue)
		return
	end

	local compoundId = (result :: any).compoundId :: string
	local isNatural = (result :: any).isNatural :: boolean
	local isWorldFirst = (result :: any).isPatent == true
	local compound = Compounds[compoundId]
	local tier: number = (compound and compound.tier) or 1
	local chamberPart = SlotController.getChamberPart(slotIndex)

	playVFX(chamberPart, tier, function()
		-- isWorldFirst comes authoritatively from the SlotReveal payload (isPatent),
		-- not a race against the PatentClaim S2C event.
		getRevealCard().show({
			compoundId = compoundId,
			compound = compound,
			tier = tier,
			isNatural = isNatural,
			isWorldFirst = isWorldFirst,
			onDone = function()
				resetChamber(chamberPart)
				_playing = false
				pushQueueState()
				task.delay(0.5, drainQueue)
			end,
		})
	end)
end

drainQueue = function()
	if _playing then
		return
	end
	if #_queue == 0 then
		pushQueueState()
		return
	end
	_playing = true
	pushQueueState()
	local slotIndex = table.remove(_queue, 1)
	task.spawn(playReveal, slotIndex)
end

-- ── Public API ─────────────────────────────────────────────────────────────

local RevealController = {}

function RevealController.enqueue(slotIndex: number)
	table.insert(_queue, slotIndex)
	pushQueueState()
	drainQueue()
end

function RevealController.getQueueCount(): number
	return #_queue + (if _playing then 1 else 0)
end

function RevealController.init(): typeof(RevealController)
	return RevealController
end

return RevealController
