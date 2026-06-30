-- TickerController: drives an in-world "research network" news ticker from the live announcement feed.
--
-- AnnouncementService already broadcasts world-first patents, exotic discoveries and weekly epochs to
-- every client (RemoteController appends them to StateController.announcements). Nothing surfaced them
-- in the world; this scrolls them across a physical board so the plaza feels live and multiplayer.
--
-- Code-owned, like HubBoardController: it rebuilds the ticker board's SurfaceGui and runs a continuous
-- right-to-left marquee. The map only needs a part named "TickerBoard" (under workspace.Hub) carrying a
-- SurfaceGui. Absent → silent no-op (headless / not built).

local TweenService = game:GetService("TweenService")

local StateController = require(script.Parent.StateController)
local Theme = require(script.Parent.Parent.UI.Theme)

local TickerController = {}

local SPEED = 120 -- canvas px/sec
local SEP = "      ◆      "
local IDLE = "PRECIPICE RESEARCH NETWORK   ·   synthesize   ·   patent   ·   prestige"

-- kind → leading glyph (kinds are best-effort; unknown kinds fall back to ◆).
local GLYPH: { [string]: string } = {
	patent = "⚗",
	exotic = "◈",
	epoch = "⏱",
	weekly = "⏱",
	seed = "⏱",
	event = "◇",
}

local _label: TextLabel? = nil
local _dirty = true
local _running = false

local function findBoardGui(): SurfaceGui?
	local ok, gui = pcall(function()
		local hub = workspace:FindFirstChild("Hub")
		local part = hub and hub:FindFirstChild("TickerBoard", true)
		return part and part:FindFirstChildWhichIsA("SurfaceGui")
	end)
	if ok and gui then
		return gui
	end
	return nil
end

local function buildText(): string
	local anns = StateController.get().announcements
	if not anns or #anns == 0 then
		return IDLE
	end
	local parts = {}
	for _, a in ipairs(anns) do
		local glyph = (a.kind and GLYPH[a.kind]) or "◆"
		table.insert(parts, glyph .. "  " .. (a.message or ""))
	end
	return table.concat(parts, SEP)
end

local function buildBoard(gui: SurfaceGui): TextLabel
	for _, c in ipairs(gui:GetChildren()) do
		c:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "Ticker"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Theme.Colors.Background
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = gui

	-- thin accent edge top + bottom for a "broadcast strip" read
	for _, y in ipairs({ 0, 1 }) do
		local edge = Instance.new("Frame")
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = Theme.Colors.Accent
		edge.AnchorPoint = Vector2.new(0, y)
		edge.Position = UDim2.fromScale(0, y)
		edge.Size = UDim2.new(1, 0, 0, 4)
		edge.Parent = root
	end

	local label = Instance.new("TextLabel")
	label.Name = "Scroll"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Position = UDim2.fromScale(1, 0)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Value
	label.TextColor3 = Theme.Colors.TextPrimary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextSize = 44
	label.Text = IDLE
	label.Parent = root

	return label
end

-- One pass of the marquee. Yields until the label has scrolled fully off the left edge.
local function scrollOnce(gui: SurfaceGui, label: TextLabel)
	if _dirty then
		label.Text = buildText()
		_dirty = false
	end

	local canvasW = (gui.SizingMode == Enum.SurfaceGuiSizingMode.FixedSize) and gui.CanvasSize.X
		or label.Parent and (label.Parent :: GuiObject).AbsoluteSize.X
		or 1000

	-- Let AutomaticSize settle so AbsoluteSize.X reflects the new text.
	task.wait()
	local textW = label.AbsoluteSize.X
	if textW <= 0 then
		textW = canvasW
	end

	label.Position = UDim2.fromOffset(canvasW, 0)
	local distance = canvasW + textW
	local tween = TweenService:Create(
		label,
		TweenInfo.new(distance / SPEED, Enum.EasingStyle.Linear),
		{ Position = UDim2.fromOffset(-textW, 0) }
	)
	tween:Play()
	tween.Completed:Wait()
end

function TickerController.bindTicker()
	if _running then
		return
	end
	local gui = findBoardGui()
	if not gui then
		return -- board not built
	end
	_running = true
	_label = buildBoard(gui)

	-- Mark dirty whenever a new announcement lands (picked up at the next scroll boundary).
	StateController.Changed:Connect(function(patch)
		if patch.announcements ~= nil then
			_dirty = true
		end
	end)

	task.spawn(function()
		while _running and gui.Parent and _label do
			local ok, err = pcall(scrollOnce, gui, _label)
			if not ok then
				warn("[TickerController] scroll error:", err)
				task.wait(1)
			end
		end
		_running = false
	end)
end

function TickerController.init(): typeof(TickerController)
	return TickerController
end

return TickerController
