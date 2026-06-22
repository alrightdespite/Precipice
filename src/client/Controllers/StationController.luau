-- StationController: wires the in-world station terminals (the physical equivalents of the
-- HUD screens, design §31). Each station Model under the player's plot
-- (workspace.Plots.<userId>.Lab.Stations.<name>) carries a "Screen" attribute and a ProximityPrompt;
-- walking up + triggering opens that screen via UIController. The Vault station also has a SurfaceGui
-- whose labels are kept live from StateController. Config lives entirely on the instances (the
-- attribute), so stations can be added/moved/removed in Studio without code changes.
--
-- Mirrors SlotController.bindRevealPrompts; pcall-guarded so it is a no-op when the map is not
-- present (headless / template not built).

local Players = game:GetService("Players")

local StationController = {}

local function formatNum(n: number): string
	local abs = math.abs(n)
	if abs >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	end
	if abs >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	end
	if abs >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	end
	if abs >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- Resolve the Stations folder in the local player's plot clone. Returns nil if absent.
local function getStationsFolder(): Instance?
	local lp = Players.LocalPlayer
	if not lp then
		return nil
	end
	local userId = tostring(lp.UserId)
	local ok, folder = pcall(function()
		return workspace
			:FindFirstChild("Plots")
			:FindFirstChild(userId)
			:FindFirstChild("Lab")
			:FindFirstChild("Stations")
	end)
	if ok and folder then
		return folder
	end
	return nil
end

-- Recompute the Vault station's SurfaceGui labels from current state. Labels are found by name
-- ("PelletsValue" / "CompoundsValue") anywhere under the station; missing labels are skipped.
local function refreshVaultGui(station: Instance, StateController: any)
	local state = StateController.get()
	local pellets = (state.balance and state.balance.pellets) or 0
	local kinds = 0
	for _, qty in pairs(state.vault or {}) do
		if type(qty) == "number" and qty > 0 then
			kinds += 1
		end
	end
	local pelletsLabel = station:FindFirstChild("PelletsValue", true)
	if pelletsLabel and pelletsLabel:IsA("TextLabel") then
		pelletsLabel.Text = formatNum(pellets) .. " ◈"
	end
	local compoundsLabel = station:FindFirstChild("CompoundsValue", true)
	if compoundsLabel and compoundsLabel:IsA("TextLabel") then
		compoundsLabel.Text = tostring(kinds) .. " compounds"
	end
end

-- Called once at PlayerReady (after the plot clone exists), alongside bindRevealPrompts.
function StationController.bindStations()
	local UIController = require(script.Parent.UIController)
	local StateController = require(script.Parent.StateController)

	local stations = getStationsFolder()
	if not stations then
		return -- map not built / headless; in-world stations simply absent (More drawer still works)
	end

	local vaultStations: { Instance } = {}

	for _, station in ipairs(stations:GetChildren()) do
		local screen = station:GetAttribute("Screen")
		if type(screen) == "string" and screen ~= "" then
			local prompt = station:FindFirstChild("Prompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = true
				if prompt.ActionText == "" then
					prompt.ActionText = screen
				end
				prompt.Triggered:Connect(function()
					UIController.openScreen(screen)
				end)
			end
			if screen == "Vault" then
				table.insert(vaultStations, station)
				refreshVaultGui(station, StateController)
			end
		end
	end

	-- Keep Vault station faces live as pellets / vault change.
	if #vaultStations > 0 then
		StateController.Changed:Connect(function(patch)
			if patch.balance ~= nil or patch.vault ~= nil then
				for _, station in ipairs(vaultStations) do
					refreshVaultGui(station, StateController)
				end
			end
		end)
	end
end

function StationController.init(): typeof(StationController)
	return StationController
end

return StationController
