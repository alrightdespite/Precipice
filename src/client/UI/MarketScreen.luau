-- STUB: Phase 12B replaces with real layout and data binding.
local Players = game:GetService("Players")

local gui = Instance.new("ScreenGui")
gui.Name = "MarketScreen"
gui.Enabled = false
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.Text = "MarketScreen [STUB]"
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
label.TextColor3 = Color3.fromRGB(200, 200, 220)
label.TextScaled = true
label.Font = Enum.Font.Gotham
label.Parent = gui

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local MarketScreen = {}
function MarketScreen.open()
	gui.Enabled = true
end
function MarketScreen.close()
	gui.Enabled = false
end
return MarketScreen
