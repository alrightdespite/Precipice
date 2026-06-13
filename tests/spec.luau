-- Minimal spec helper for Lune tests.
-- Usage:
--   local spec = require("tests/spec")
--   spec.describe("MyModule", function()
--     spec.it("does X", function()
--       spec.expect(1 + 1).toBe(2)
--     end)
--   end)
--   spec.run()

local spec = {}

local _suites: { { name: string, tests: { { name: string, fn: () -> () } } } } = {}
local _current: { name: string, tests: { { name: string, fn: () -> () } } }? = nil

function spec.describe(name: string, fn: () -> ())
	local suite = { name = name, tests = {} }
	_current = suite
	fn()
	_current = nil
	table.insert(_suites, suite)
end

function spec.it(name: string, fn: () -> ())
	assert(_current, "spec.it called outside spec.describe")
	table.insert(_current.tests, { name = name, fn = fn })
end

type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeTrue: () -> (),
	toBeFalse: () -> (),
	toBeNil: () -> (),
	toBeGreaterThan: (n: number) -> (),
	toBeLessThan: (n: number) -> (),
}

function spec.expect(value: any): Expectation
	return {
		toBe = function(expected)
			if value ~= expected then
				error(string.format("Expected %s to be %s", tostring(value), tostring(expected)), 2)
			end
		end,
		toEqual = function(expected)
			if value ~= expected then
				error(string.format("Expected %s to equal %s", tostring(value), tostring(expected)), 2)
			end
		end,
		toBeTrue = function()
			if value ~= true then
				error(string.format("Expected true, got %s", tostring(value)), 2)
			end
		end,
		toBeFalse = function()
			if value ~= false then
				error(string.format("Expected false, got %s", tostring(value)), 2)
			end
		end,
		toBeNil = function()
			if value ~= nil then
				error(string.format("Expected nil, got %s", tostring(value)), 2)
			end
		end,
		toBeGreaterThan = function(n)
			if not (value > n) then
				error(string.format("Expected %s > %s", tostring(value), tostring(n)), 2)
			end
		end,
		toBeLessThan = function(n)
			if not (value < n) then
				error(string.format("Expected %s < %s", tostring(value), tostring(n)), 2)
			end
		end,
	}
end

function spec.run(): boolean
	local passed = 0
	local failed = 0
	local errors: { string } = {}

	for _, suite in ipairs(_suites) do
		print(string.format("\n  %s", suite.name))
		for _, test in ipairs(suite.tests) do
			local ok, err = pcall(test.fn)
			if ok then
				passed = passed + 1
				print(string.format("    PASS  %s", test.name))
			else
				failed = failed + 1
				local msg = string.format("    FAIL  %s\n          %s", test.name, tostring(err))
				print(msg)
				table.insert(errors, msg)
			end
		end
	end

	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then
		print("\nFailed tests:")
		for _, e in ipairs(errors) do
			print(e)
		end
		return false
	end
	return true
end

return spec
