-- HubBoardController: drives the two in-world Civic-Plaza info boards from live
-- leaderboard data (design §30). The Leaderboards pavilion shows the weekly Sprint
-- top researchers; the Hall of Fame pavilion shows the all-time Chief's Board.
--
-- The board panel (the "Board" part's SurfaceGui under workspace.Hub.Pavilions.<name>)
-- is owned entirely by this controller: on bind it clears the Studio-authored
-- placeholder labels and rebuilds a clean live table, then refreshes on a poll.
-- The pavilion's other signage (NamePlate / FriezeSign) is left untouched.
--
-- Decoupled from the map by design: the map is gitignored, so this only requires that
-- each pavilion have a "Board" part with a SurfaceGui. Absent → silent no-op (headless).
--
-- Poll cadence respects LeaderboardService's per-player rate limit (1 req / 2s across
-- all boards): the two boards are requested ~3s apart, then the cycle sleeps ~57s,
-- so each board refreshes about once a minute and the two requests never collide.

local Players = game:GetService("Players")

local LeaderboardController = require(script.Parent.LeaderboardController)
local Theme = require(script.Parent.Parent.UI.Theme)

local HubBoardController = {}

local ROW_COUNT = 5
local POLL_REST = 57 -- seconds the cycle sleeps after refreshing both boards
local STAGGER = 3 -- seconds between the two boards' requests (rate-limit safety)

-- Which pavilion maps to which board + its labelling.
local BOARDS = {
	{
		pavilion = "Leaderboards",
		board = "sprint",
		title = "WEEKLY SPRINT",
		subtitle = "Top Researchers",
		footer = "Press E for the full board",
	},
	{
		pavilion = "HallOfFame",
		board = "chiefs",
		title = "HALL OF FAME",
		subtitle = "All-Time Chief's Board",
		footer = "Lifetime rank · refreshed live",
	},
}

-- Resolved username cache shared across both boards.
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

local function getHubPavilions(): Instance?
	local ok, folder = pcall(function()
		return workspace:FindFirstChild("Hub"):FindFirstChild("Pavilions")
	end)
	if ok and folder then
		return folder
	end
	return nil
end

local function findBoardGui(pavilions: Instance, pavilionName: string): SurfaceGui?
	local pav = pavilions:FindFirstChild(pavilionName)
	if not pav then
		return nil
	end
	local boardPart = pav:FindFirstChild("Board")
	if not boardPart then
		return nil
	end
	return boardPart:FindFirstChildWhichIsA("SurfaceGui")
end

-- Build the static panel chrome + ROW_COUNT row templates once. Returns a context table
-- with the row sublabel references + the status label for later refreshes.
local function buildPanel(gui: SurfaceGui, def: any): any
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "LivePanel"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Background
	root.BackgroundTransparency = 0.18
	root.BorderSizePixel = 0
	root.Parent = gui

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 0, 66)
	title.FontFace = Theme.Font.Display
	title.TextColor3 = Theme.Colors.Accent
	title.TextScaled = false
	title.TextSize = 54
	title.Text = def.title
	title.Parent = root

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(0, 82)
	subtitle.Size = UDim2.new(1, 0, 0, 30)
	subtitle.FontFace = Theme.Font.Value
	subtitle.TextColor3 = Theme.Colors.TextSecondary
	subtitle.TextSize = 24
	subtitle.Text = def.subtitle
	subtitle.Parent = root

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = Theme.Colors.Accent
	divider.BackgroundTransparency = 0.4
	divider.Position = UDim2.fromOffset(0, 122)
	divider.Size = UDim2.new(1, 0, 0, 2)
	divider.Parent = root

	local rowsArea = Instance.new("Frame")
	rowsArea.Name = "Rows"
	rowsArea.BackgroundTransparency = 1
	rowsArea.Position = UDim2.fromOffset(0, 138)
	rowsArea.Size = UDim2.new(1, 0, 0, 372)
	rowsArea.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = rowsArea

	local rows = {}
	for i = 1, ROW_COUNT do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.LayoutOrder = i
		row.BackgroundColor3 = Theme.Colors.SurfaceRaised
		row.BackgroundTransparency = i % 2 == 0 and 0.45 or 0.25
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 66)
		row.Parent = rowsArea

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row

		local rank = Instance.new("TextLabel")
		rank.Name = "Rank"
		rank.BackgroundTransparency = 1
		rank.Position = UDim2.fromOffset(16, 0)
		rank.Size = UDim2.new(0, 64, 1, 0)
		rank.FontFace = Theme.Font.Display
		rank.TextColor3 = Theme.Colors.TextSecondary
		rank.TextXAlignment = Enum.TextXAlignment.Left
		rank.TextSize = 30
		rank.Text = ""
		rank.Parent = row

		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(92, 0)
		name.Size = UDim2.new(1, -300, 1, 0)
		name.FontFace = Theme.Font.Label
		name.TextColor3 = Theme.Colors.TextPrimary
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextSize = 28
		name.Text = ""
		name.Parent = row

		local score = Instance.new("TextLabel")
		score.Name = "Score"
		score.BackgroundTransparency = 1
		score.AnchorPoint = Vector2.new(1, 0)
		score.Position = UDim2.new(1, -16, 0, 0)
		score.Size = UDim2.new(0, 180, 1, 0)
		score.FontFace = Theme.Font.Value
		score.TextColor3 = Theme.Colors.Accent
		score.TextXAlignment = Enum.TextXAlignment.Right
		score.TextSize = 28
		score.Text = ""
		score.Parent = row

		rows[i] = { row = row, rank = rank, name = name, score = score }
	end

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0, 138)
	status.Size = UDim2.new(1, 0, 0, 372)
	status.FontFace = Theme.Font.Body
	status.TextColor3 = Theme.Colors.TextSecondary
	status.TextSize = 26
	status.Text = "Loading…"
	status.Parent = root

	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromOffset(0, 564)
	footer.Size = UDim2.new(1, 0, 0, 30)
	footer.FontFace = Theme.Font.Body
	footer.TextColor3 = Theme.Colors.TextMuted
	footer.TextSize = 20
	footer.Text = def.footer
	footer.Parent = root

	return { rows = rows, status = status, renderId = 0 }
end

-- Async-resolve a username into the shared cache, then write it into `label` if `label`
-- still belongs to render `renderId` (guards against a newer refresh having reused the row).
local function resolveName(userId: number, label: TextLabel, ctx: any, renderId: number)
	if userId <= 0 then
		return
	end
	if _nameCache[userId] then
		label.Text = _nameCache[userId]
		return
	end
	if _resolving[userId] then
		return
	end
	_resolving[userId] = true
	task.spawn(function()
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if not ok then
			warn("[HubBoardController] GetNameFromUserIdAsync failed for", userId, "—", name)
		elseif name then
			_nameCache[userId] = name
			if ctx.renderId == renderId and label.Parent then
				label.Text = name
			end
		end
		_resolving[userId] = nil
	end)
end

local function render(ctx: any, entries: { any })
	ctx.renderId += 1
	local renderId = ctx.renderId

	if #entries == 0 then
		ctx.status.Text = "No entries yet — be the first!"
		ctx.status.Visible = true
		for _, r in ipairs(ctx.rows) do
			r.row.Visible = false
		end
		return
	end

	ctx.status.Visible = false
	for i, r in ipairs(ctx.rows) do
		local entry = entries[i]
		if entry then
			r.row.Visible = true
			r.rank.Text = "#" .. tostring(entry.rank or i)
			r.score.Text = formatScore(entry.score or 0)
			if entry.displayName and entry.displayName ~= "" then
				r.name.Text = entry.displayName
			else
				r.name.Text = tostring(entry.userId)
				resolveName(entry.userId, r.name, ctx, renderId)
			end
		else
			r.row.Visible = false
		end
	end
end

-- One request + render for a single board. Swallows transport/rate-limit failures
-- (render falls back to the cached entries, which may be empty on a cold first call).
local function refreshBoard(def: any, ctx: any)
	LeaderboardController.request(def.board)
	render(ctx, LeaderboardController.getCached(def.board))
end

-- Called once at PlayerReady (after the hub exists), alongside bindHubPavilions.
function HubBoardController.bindBoards()
	local pavilions = getHubPavilions()
	if not pavilions then
		return -- hub absent (headless / not built)
	end

	local bound: { { def: any, ctx: any } } = {}
	for _, def in ipairs(BOARDS) do
		local gui = findBoardGui(pavilions, def.pavilion)
		if gui then
			table.insert(bound, { def = def, ctx = buildPanel(gui, def) })
		end
	end

	if #bound == 0 then
		return
	end

	task.spawn(function()
		while true do
			for idx, b in ipairs(bound) do
				refreshBoard(b.def, b.ctx)
				if idx < #bound then
					task.wait(STAGGER)
				end
			end
			task.wait(POLL_REST)
		end
	end)
end

function HubBoardController.init(): typeof(HubBoardController)
	return HubBoardController
end

return HubBoardController
