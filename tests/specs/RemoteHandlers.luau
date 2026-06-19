-- RemoteHandlers: CI guard — every C2S RemoteFunction in Manifest has a server handler.
-- Catches gaps like the FormulaLogRequest hole fixed in Phase 11.
-- Handlers register via RemoteService.setInvoke("Name", fn) (rate-limited, §D). A legacy direct
-- `getFunction("Name").OnServerInvoke` binding is still accepted as a fallback.
-- All service files are scanned as source text; no Roblox globals required.

local spec = require("../spec")
local Manifest = require("../../src/shared/Remotes/Manifest.luau")

local fs = require("@lune/fs")

local describe, it, expect = spec.describe, spec.it, spec.expect

-- ── Collect all C2S Function remotes from Manifest ───────────────────────────

local c2sFunctions: { string } = {}
for _, entry in ipairs(Manifest) do
	if entry.kind == "Function" and entry.direction == "C2S" then
		table.insert(c2sFunctions, entry.name)
	end
end

-- ── Scan service sources for OnServerInvoke bindings ─────────────────────────

local SERVICES_DIR = "src/server/Services"

local function readFile(path: string): string
	local ok, content = pcall(fs.readFile, path)
	return if ok then content else ""
end

local function getAllServiceSource(): string
	local parts: { string } = {}
	local ok, entries = pcall(fs.readDir, SERVICES_DIR)
	if not ok then return "" end
	for _, name in ipairs(entries) do
		if name:match("%.luau$") then
			table.insert(parts, readFile(SERVICES_DIR .. "/" .. name))
		end
	end
	return table.concat(parts, "\n")
end

local allSource = getAllServiceSource()

-- ── Tests ────────────────────────────────────────────────────────────────────

describe("RemoteHandlers — every C2S Function has a server handler", function()
	for _, remoteName in ipairs(c2sFunctions) do
		local name = remoteName
		it(name .. " is registered via setInvoke (or a legacy OnServerInvoke binding)", function()
			-- Canonical: RemoteService.setInvoke("Name", fn) — rate-limited registration (§D).
			local found = allSource:find('setInvoke("' .. name .. '"', 1, true) ~= nil
			-- Legacy fallback: getFunction("Name") near an OnServerInvoke assignment.
			if not found then
				-- Scan for the pattern: remote name adjacent to OnServerInvoke (within 200 chars)
				local pos = 1
				while pos <= #allSource do
					local s, e = allSource:find(name, pos, true)
					if not s then break end
					local context = allSource:sub(math.max(1, s - 100), e + 200)
					if context:find("OnServerInvoke") then
						found = true
						break
					end
					pos = e + 1
				end
			end
			expect(found).toBeTrue()
		end)
	end
end)
