-- PlotService: spawns and destroys per-player plot models in workspace.
-- Expects a Model named "PLOT_TEMPLATE" inside workspace.Plots (built in Studio).
-- Gracefully skips if template is absent (headless / no-world context).

local TEMPLATE_NAME = "PLOT_TEMPLATE"
local PLOTS_FOLDER = "Plots"

-- Plots are tiled in a grid so concurrent players never overlap. Stride is
-- derived from the template bounds plus a gap, so spacing adapts to the build.
local GRID_COLS = 8
local PLOT_GAP_STUDS = 64

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

-- World translation for a grid slot, relative to the template's position.
-- row is shifted by +1 so no player plot lands on top of PLOT_TEMPLATE itself.
local function offsetForSlot(template: Model, slot: number): Vector3
	local extents = template:GetExtentsSize()
	local strideX = extents.X + PLOT_GAP_STUDS
	local strideZ = extents.Z + PLOT_GAP_STUDS
	local col = slot % GRID_COLS
	local row = math.floor(slot / GRID_COLS)
	return Vector3.new(col * strideX, 0, (row + 1) * strideZ)
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
	-- Translate the whole model so plots never stack at the template origin.
	plot:PivotTo(plot:GetPivot() + offsetForSlot(template :: Model, slot))
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
