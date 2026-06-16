-- PlotService: spawns and destroys per-player plot models in workspace.
-- Expects a Model named "PLOT_TEMPLATE" inside workspace.Plots (built in Studio).
-- Gracefully skips if template is absent (headless / no-world context).

local TEMPLATE_NAME = "PLOT_TEMPLATE"
local PLOTS_FOLDER = "Plots"

local _plots: { [number]: Model } = {}

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

	local plot = (template :: Model):Clone()
	plot.Name = tostring(userId)
	plot.Parent = plotsFolder
	_plots[userId] = plot
end

function PlotService.destroyPlot(player: Player)
	local userId = player.UserId
	local plot = _plots[userId]
	if plot then
		plot:Destroy()
		_plots[userId] = nil
	end
end

function PlotService.init()
	-- Boot-time: no-op. PlayerAdded/Removing wired in GameInit.
end

return PlotService
