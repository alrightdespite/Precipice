-- AdminController: registers the admin slash-commands with TextChatService and relays them to the
-- server. Required because under TextChatService a typed "/" message is treated as a command and
-- does NOT fire Player.Chatted — so the server can't see it via chat alone. Each TextChatCommand's
-- Triggered fires on the client; we forward the full text to AdminService, which re-checks isAdmin.
-- (Registering the commands is harmless for non-admins; the server rejects their relays.)

local TextChatService = game:GetService("TextChatService")
local RemoteController = require(script.Parent.RemoteController)

local AdminController = {}

local ALIASES = { "/give", "/setbalance", "/kick", "/inspect", "/tp" }

function AdminController.init(): typeof(AdminController)
	for _, alias in ipairs(ALIASES) do
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "Admin_" .. string.sub(alias, 2)
		cmd.PrimaryAlias = alias
		cmd.AutocompleteVisible = false
		cmd.Triggered:Connect(function(_textSource, unfilteredText: string)
			RemoteController.fire("AdminCommand", unfilteredText)
		end)
		cmd.Parent = TextChatService
	end
	return AdminController
end

return AdminController
