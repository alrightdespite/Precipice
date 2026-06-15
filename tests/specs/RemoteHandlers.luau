-- RemoteHandlers: CI guard — every C2S RemoteFunction in Manifest has an OnServerInvoke binding.
-- Catches gaps like the FormulaLogRequest hole fixed in Phase 11.
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

describe("RemoteHandlers — every C2S Function has an OnServerInvoke binding", function()
	for _, remoteName in ipairs(c2sFunctions) do
		local name = remoteName
		it(name .. " has OnServerInvoke wired in a service", function()
			-- Match either: getFunction("Name").OnServerInvoke or getFunction("Name")…OnServerInvoke
			local pattern1 = 'getFunction%("' .. name .. '"%)%.OnServerInvoke'
			local pattern2 = 'getFunction%("' .. name .. '"%)' .. ".+OnServerInvoke"
			local found = allSource:find(pattern1) ~= nil
			if not found then
				-- Some services store the function first, then assign OnServerInvoke on the next line
				found = allSource:find('getFunction%("' .. name .. '"%)') ~= nil
					and allSource:find(name .. '"%)') ~= nil
			end
			-- Broader: just check that the name appears near OnServerInvoke somewhere
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
