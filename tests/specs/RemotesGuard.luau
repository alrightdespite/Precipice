-- RemotesGuard: CI guard — fail if any .luau file outside RemoteService creates
-- remote instances (H9, E13). Checks source text for Instance.new("RemoteEvent/Function").

local spec = require("../spec")
local fs = require("@lune/fs")

local ALLOWED_FILE = "src/server/Services/RemoteService.luau"

local function scanDir(dir: string, results: { string })
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		local meta = fs.metadata(path)
		if meta.kind == "dir" then
			scanDir(path, results)
		elseif path:match("%.luau$") then
			table.insert(results, path)
		end
	end
end

spec.describe("RemotesGuard — no authored remote instances", function()
	spec.it("no .luau file outside RemoteService creates remote instances", function()
		local files: { string } = {}
		scanDir("src", files)

		local violations: { string } = {}
		for _, path in ipairs(files) do
			local normalized = path:gsub("\\", "/")
			if normalized == ALLOWED_FILE then
				continue
			end
			local content = fs.readFile(path)
			if content:match('Instance%.new%s*%(%s*"RemoteEvent"') or content:match('Instance%.new%s*%(%s*"RemoteFunction"') then
				table.insert(violations, path)
			end
		end

		if #violations > 0 then
			error("Files author remote instances (only RemoteService may):\n  " .. table.concat(violations, "\n  "))
		end
	end)
end)
