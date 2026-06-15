-- Loading screen — first thing every player sees.
-- Slightly more than a stub: shows title, progress bar placeholder, cycling taglines.
-- Phase 12B: replace placeholder geometry with real art and animated bar.

local Players = game:GetService("Players")

local TAGLINES = {
	"Synthesize the unknown.",
	"Claim your patents. Guard them well.",
	"Every compound, a discovery.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.Enabled = false
gui.ResetOnSpawn = false
gui.DisplayOrder = 100 -- on top of everything during load

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.Text = "PRECIPICE"
title.Size = UDim2.new(1, 0, 0.2, 0)
title.Position = UDim2.fromScale(0, 0.35)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(220, 220, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = bg

-- Progress bar placeholder (Phase 12B wires real progress)
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(0.4, 0, 0, 4)
barBg.Position = UDim2.new(0.3, 0, 0.62, 0)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
barBg.BorderSizePixel = 0
barBg.Parent = bg

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(120, 100, 255)
barFill.BorderSizePixel = 0
barFill.Name = "Fill"
barFill.Parent = barBg

local taglineLabel = Instance.new("TextLabel")
taglineLabel.Text = TAGLINES[1]
taglineLabel.Size = UDim2.new(0.8, 0, 0.1, 0)
taglineLabel.Position = UDim2.new(0.1, 0, 0.68, 0)
taglineLabel.BackgroundTransparency = 1
taglineLabel.TextColor3 = Color3.fromRGB(140, 130, 200)
taglineLabel.TextScaled = true
taglineLabel.Font = Enum.Font.Gotham
taglineLabel.Parent = bg

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local taglineIndex = 1
local cycling = false

local function cycleTagline()
	if not cycling then
		return
	end
	taglineIndex = (taglineIndex % #TAGLINES) + 1
	taglineLabel.Text = TAGLINES[taglineIndex]
	task.delay(3, cycleTagline)
end

local LoadingScreen = {}

function LoadingScreen.open()
	gui.Enabled = true
	cycling = true
	task.delay(3, cycleTagline)
end

function LoadingScreen.close()
	cycling = false
	gui.Enabled = false
end

return LoadingScreen
