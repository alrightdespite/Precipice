-- PlotService: spawns and destroys per-player plot models in workspace.
-- Expects a Model named "PLOT_TEMPLATE" inside workspace.Plots (built in Studio).
-- Gracefully skips if template is absent (headless / no-world context).

local TEMPLATE_NAME = "PLOT_TEMPLATE"
local PLOTS_FOLDER = "Plots"

-- Plots ring the Central Hub (IR-DIV-01) in a regular octagon: eight plots evenly
-- spaced on a circle around the hub, each rotated to face it, so every player is
-- the SAME distance from the hub. This is the most uniform/efficient equal-distance
-- formation for the 262×410 lot.
-- World centre of the shared hub (matches workspace.Hub). Keep in sync with the
-- Studio-built hub geometry.
local HUB_CENTER = Vector3.new(1145, 0, 40)
-- Radius from hub centre to each plot centre. 580 places the inward-facing fronts
-- (lot is 262 wide, front sits at radius-205 = 375) just outside the hub's octagon
-- ring road (vertices at ~370), shortening the plot→plaza walk while the 262-wide
-- fronts still clear: front circumference 2π·375 ≈ 2356 / 8 = 294 > 262. The Studio
-- ring road + lab gateways are built to match this radius (keep them in sync).
local PLOT_RING_RADIUS = 580

local _plots: { [number]: Model } = {}
local _slotByUser: { [number]: number } = {}
local _usedSlots: { [number]: boolean } = {}

local PlotService = {}

local function getOrCreatePlotsFolder(): Folder
	local existing = workspace:FindFirstChild(PLOTS_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing :: Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = PLOTS_FOLDER
	folder.Parent = workspace
	return folder
end

-- Lowest free grid index; reused on logout so the grid stays compact.
local function claimSlot(): number
	local i = 0
	while _usedSlots[i] do
		i += 1
	end
	_usedSlots[i] = true
	return i
end

-- Absolute world CFrame for a slot: eight plots evenly placed on a circle of
-- radius PLOT_RING_RADIUS around the hub, each turned to face the hub (its front,
-- the -Z entrance side, points at the centre). Placement is absolute, so the
-- unused template can sit off-stage. Slots beyond 8 wrap (max 8 players/server).
local function placementForSlot(_template: Model, slot: number): CFrame
	local angle = (slot % 8) * (2 * math.pi / 8)
	local x = HUB_CENTER.X + math.cos(angle) * PLOT_RING_RADIUS
	local z = HUB_CENTER.Z + math.sin(angle) * PLOT_RING_RADIUS
	local y = _template:GetPivot().Position.Y
	-- lookAt: the CFrame's front (-Z / LookVector) points toward the hub centre.
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(HUB_CENTER.X, y, HUB_CENTER.Z))
end

-- Plot footprint markers (Studio-built blueprint pads in workspace.WorldGround.PlotMarkers,
-- one per slot: "PlotMarker_<slot>"). They show where each plot WILL spawn; we hide a marker
-- while its slot is occupied and restore it when the player leaves. Gracefully no-ops if the
-- markers are absent (headless / tests).
local MARKERS_FOLDER = "PlotMarkers"
local function setMarkerVisible(slot: number, visible: boolean)
	local wg = workspace:FindFirstChild("WorldGround")
	local markers = wg and wg:FindFirstChild(MARKERS_FOLDER)
	local marker = markers and markers:FindFirstChild("PlotMarker_" .. slot)
	if not marker then
		return
	end
	for _, d in ipairs(marker:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = visible and (d.Name == "HoloSign" and 0.35 or 0) or 1
		elseif d:IsA("SurfaceGui") then
			d.Enabled = visible
		end
	end
end

function PlotService.spawnPlot(player: Player)
	local userId = player.UserId
	if _plots[userId] then
		return -- already spawned (studio reconnect edge case)
	end

	local plotsFolder = getOrCreatePlotsFolder()
	local template = plotsFolder:FindFirstChild(TEMPLATE_NAME)
	if not template or not template:IsA("Model") then
		warn("[PlotService] PLOT_TEMPLATE not found in workspace.Plots — plot skipped for userId", userId)
		return
	end

	-- The template's own SpawnLocation sits at the origin; disable it once so no
	-- player ever spawns on the (non-play) template. Each clone keeps its own.
	local templateSpawn = (template :: Model):FindFirstChild("Spawn")
	if templateSpawn and templateSpawn:IsA("SpawnLocation") then
		templateSpawn.Enabled = false
	end

	local slot = claimSlot()
	_slotByUser[userId] = slot
	setMarkerVisible(slot, false) -- hide the "available" blueprint while this slot is occupied

	local plot = (template :: Model):Clone()
	plot.Name = tostring(userId)
	-- Place the whole model at its absolute ring slot around the hub.
	plot:PivotTo(placementForSlot(template :: Model, slot))
	plot.Parent = plotsFolder
	_plots[userId] = plot

	-- Route this player to their own plot. RespawnLocation forces the spawn point
	-- regardless of team selection; re-enable the clone's spawn (cloned from the
	-- now-disabled template spawn) so it is a valid respawn target.
	local spawn = plot:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.Enabled = true
		spawn.Neutral = true
		player.RespawnLocation = spawn
		-- If the character already loaded (joined before the plot existed, or
		-- Studio auto-load), move it onto the plot now.
		local char = player.Character
		if char then
			char:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
		end
	end
end

function PlotService.destroyPlot(player: Player)
	local userId = player.UserId
	local plot = _plots[userId]
	if plot then
		plot:Destroy()
		_plots[userId] = nil
	end
	local slot = _slotByUser[userId]
	if slot ~= nil then
		setMarkerVisible(slot, true) -- restore the "available" blueprint marker
		_usedSlots[slot] = nil
		_slotByUser[userId] = nil
	end
end

function PlotService.init()
	-- Boot-time: no-op. PlayerAdded/Removing wired in GameInit.
end

return PlotService
