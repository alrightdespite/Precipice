-- PlotService: spawns and destroys per-player plot models in workspace.
-- Expects a Model named "PLOT_TEMPLATE" inside workspace.Plots (built in Studio).
-- Gracefully skips if template is absent (headless / no-world context).

local TEMPLATE_NAME = "PLOT_TEMPLATE"
local PLOTS_FOLDER = "Plots"

-- Plots ring the Central Hub (IR-DIV-01): two facing rows of four, one north and
-- one south of the hub, so the hub sits in the middle of every plot. Stride is
-- derived from the template bounds plus a gap, so spacing adapts to the build.
local GRID_COLS = 4
local PLOT_GAP_STUDS = 64
-- World centre of the shared hub (matches workspace.Hub). The two plot rows
-- straddle this point; keep in sync with the Studio-built hub geometry.
local HUB_CENTER = Vector3.new(1145, 0, 40)
-- Distance from the hub centre to each plot row.
local ROW_GAP_STUDS = 560

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

-- Absolute world CFrame for a slot: four plots per row, two rows straddling the
-- hub (row 0 north, row 1 south). The south row is flipped 180° so both rows
-- face the hub. Placement is absolute (not relative to the unused template
-- model), so the template can sit anywhere off-stage. Stride comes from the
-- dedicated "PlotBounds" part when present (sized to the real lot), so far-flung
-- decorative parts can't inflate spacing; falls back to whole-model extents.
local function placementForSlot(template: Model, slot: number): CFrame
	local boundsPart = template:FindFirstChild("PlotBounds")
	local footprint = if boundsPart and boundsPart:IsA("BasePart")
		then (boundsPart :: BasePart).Size
		else template:GetExtentsSize()
	local strideX = footprint.X + PLOT_GAP_STUDS
	local col = slot % GRID_COLS
	local row = math.floor(slot / GRID_COLS)
	local x = HUB_CENTER.X + (col - (GRID_COLS - 1) / 2) * strideX
	local z = HUB_CENTER.Z + (if row == 0 then ROW_GAP_STUDS else -ROW_GAP_STUDS)
	local y = template:GetPivot().Position.Y
	local cf = CFrame.new(x, y, z)
	if row ~= 0 then
		-- South row faces north toward the hub.
		cf = cf * CFrame.Angles(0, math.pi, 0)
	end
	return cf
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
		_usedSlots[slot] = nil
		_slotByUser[userId] = nil
	end
end

function PlotService.init()
	-- Boot-time: no-op. PlayerAdded/Removing wired in GameInit.
end

return PlotService
