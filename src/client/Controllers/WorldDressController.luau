-- WorldDressController: small live-dressing binders for three in-world features, all driven from data
-- that already exists client-side (no new remotes). Each is independent and a graceful no-op when its
-- map instances are absent (headless / not yet authored).
--
--  • Element plaques — fills the 8 element-garden/pylon plaques from ElementMeta (symbol / atomic # /
--    name / colour). Each plaque part carries an "ElementIndex" attribute (1..8); its SurfaceGui has
--    labels named "Symbol", "ElementName", "AtomicNumber".
--  • Flask reaction — tints the centerpiece reagent toward an event tint while a Flux season is live and
--    flashes a bright pulse on a world-first announcement. Drives Hub.Monument.Flask's "Reagent" part.
--  • Hall-of-Fame plinths — fills 3 podium plinths ("Plinth1".."Plinth3", labels "PlinthName" /
--    "PlinthScore") from the cached all-time Chief's Board (HubBoardController keeps that cache warm).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StateController = require(script.Parent.StateController)
local LeaderboardController = require(script.Parent.LeaderboardController)
local ElementMeta = require(game:GetService("ReplicatedStorage").Shared.Config.ElementMeta)

local WorldDressController = {}

local EVENT_TINT = Color3.fromRGB(183, 156, 255) -- amethyst, used while an event season is live
local PLINTH_POLL = 60

local _nameCache: { [number]: string } = {}
local _resolving: { [number]: boolean } = {}

local function formatScore(n: number): string
	local abs = math.abs(n)
	if abs >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif abs >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif abs >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function hub(): Instance?
	return workspace:FindFirstChild("Hub")
end

-- ── Element plaques ─────────────────────────────────────────────────────────

local function bindElementPlaques()
	local h = hub()
	if not h then
		return
	end
	for _, inst in ipairs(h:GetDescendants()) do
		local idx = inst:GetAttribute("ElementIndex")
		if type(idx) == "number" then
			local meta = ElementMeta[idx]
			if meta then
				local gui = inst:FindFirstChildWhichIsA("SurfaceGui")
					or inst:FindFirstChildWhichIsA("SurfaceGui", true)
				if gui then
					local sym = gui:FindFirstChild("Symbol", true)
					local nm = gui:FindFirstChild("ElementName", true)
					local num = gui:FindFirstChild("AtomicNumber", true)
					if sym and sym:IsA("TextLabel") then
						sym.Text = meta.symbol
						sym.TextColor3 = meta.color
					end
					if nm and nm:IsA("TextLabel") then
						nm.Text = meta.name
					end
					if num and num:IsA("TextLabel") then
						num.Text = tostring(meta.atomicNumber)
					end
				end
			end
		end
	end
end

-- ── Flask reaction ──────────────────────────────────────────────────────────

local function bindFlask()
	local h = hub()
	local monument = h and h:FindFirstChild("Monument")
	local flask = monument and monument:FindFirstChild("Flask")
	local reagent = flask and flask:FindFirstChild("Reagent", true)
	if not (reagent and reagent:IsA("BasePart")) then
		return
	end
	local baseColor = reagent.Color

	local function targetColor(): Color3
		local flux = StateController.get().flux
		if flux and (flux.total or 0) > 0 then
			return baseColor:Lerp(EVENT_TINT, 0.55)
		end
		return baseColor
	end

	local function settle()
		TweenService:Create(reagent, TweenInfo.new(1.5), { Color = targetColor() }):Play()
	end

	local function pulse()
		local bright = targetColor():Lerp(Color3.new(1, 1, 1), 0.7)
		local up = TweenService:Create(reagent, TweenInfo.new(0.25), { Color = bright })
		up.Completed:Once(function()
			TweenService:Create(reagent, TweenInfo.new(1.0), { Color = targetColor() }):Play()
		end)
		up:Play()
	end

	settle()
	StateController.Changed:Connect(function(patch)
		if patch.flux ~= nil then
			settle()
		end
		if patch.announcements ~= nil then
			local anns = StateController.get().announcements
			local newest = anns and anns[#anns]
			if newest and (newest.kind == "patent" or newest.kind == "exotic") then
				pulse()
			end
		end
	end)
end

-- ── Hall-of-Fame plinths ────────────────────────────────────────────────────

local function resolveName(userId: number, label: TextLabel)
	if userId <= 0 then
		label.Text = tostring(userId)
		return
	end
	if _nameCache[userId] then
		label.Text = _nameCache[userId]
		return
	end
	label.Text = tostring(userId)
	if _resolving[userId] then
		return
	end
	_resolving[userId] = true
	task.spawn(function()
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if ok and name then
			_nameCache[userId] = name
			if label.Parent then
				label.Text = name
			end
		end
		_resolving[userId] = nil
	end)
end

local function fillPlinths()
	local h = hub()
	if not h then
		return
	end
	local entries = LeaderboardController.getCached("chiefs")
	for i = 1, 3 do
		local plinth = h:FindFirstChild("Plinth" .. i, true)
		if plinth then
			local gui = plinth:FindFirstChildWhichIsA("SurfaceGui", true)
			if gui then
				local nameLbl = gui:FindFirstChild("PlinthName", true)
				local scoreLbl = gui:FindFirstChild("PlinthScore", true)
				local e = entries[i]
				if nameLbl and nameLbl:IsA("TextLabel") then
					if e then
						resolveName(e.userId, nameLbl)
					else
						nameLbl.Text = "—"
					end
				end
				if scoreLbl and scoreLbl:IsA("TextLabel") then
					scoreLbl.Text = e and formatScore(e.score or 0) or ""
				end
			end
		end
	end
end

local function bindPlinths()
	local h = hub()
	if not h or not (h:FindFirstChild("Plinth1", true)) then
		return
	end
	task.spawn(function()
		while true do
			fillPlinths()
			task.wait(PLINTH_POLL)
		end
	end)
end

-- ── Entry ───────────────────────────────────────────────────────────────────

function WorldDressController.bindWorld()
	bindElementPlaques()
	bindFlask()
	bindPlinths()
end

function WorldDressController.init(): typeof(WorldDressController)
	return WorldDressController
end

return WorldDressController
