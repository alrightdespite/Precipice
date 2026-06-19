-- AnnouncementQueue tests: 30s min-gap release + per-key dedup (§15).

local spec = require("../spec")
local AnnouncementQueue = require("../../src/shared/Core/AnnouncementQueue")

local describe, it, expect = spec.describe, spec.it, spec.expect

local function item(kind, key)
	return { kind = kind, message = kind .. " msg", tier = 4, dedupKey = key }
end

describe("AnnouncementQueue — gap release", function()
	it("releases nothing when empty", function()
		local q = AnnouncementQueue.new(30, 100)
		expect(q:release(0)).toBeNil()
	end)

	it("first item releases immediately, second waits for the gap", function()
		local q = AnnouncementQueue.new(30, 100)
		q:enqueue(item("a", "k1"), 0)
		q:enqueue(item("b", "k2"), 0)

		local first = q:release(0)
		expect(first ~= nil and first.kind).toBe("a")
		-- Within the gap: nothing releases
		expect(q:release(10)).toBeNil()
		-- After the gap: next item releases
		local second = q:release(30)
		expect(second ~= nil and second.kind).toBe("b")
	end)

	it("releases in FIFO order", function()
		local q = AnnouncementQueue.new(30, 100)
		q:enqueue(item("a", "k1"), 0)
		q:enqueue(item("b", "k2"), 0)
		q:enqueue(item("c", "k3"), 0)
		expect((q:release(0) :: any).kind).toBe("a")
		expect((q:release(60) :: any).kind).toBe("b")
		expect((q:release(120) :: any).kind).toBe("c")
	end)
end)

describe("AnnouncementQueue — dedup", function()
	it("suppresses the same dedupKey within the TTL", function()
		local q = AnnouncementQueue.new(30, 100)
		expect(q:enqueue(item("a", "first:T4_01"), 0)).toBeTrue()
		expect(q:enqueue(item("a", "first:T4_01"), 5)).toBeFalse() -- within TTL
		expect(q:size()).toBe(1)
	end)

	it("allows the same key again after the TTL elapses", function()
		local q = AnnouncementQueue.new(30, 100)
		expect(q:enqueue(item("a", "first:T4_01"), 0)).toBeTrue()
		expect(q:enqueue(item("a", "first:T4_01"), 101)).toBeTrue() -- TTL passed
	end)

	it("different keys are independent", function()
		local q = AnnouncementQueue.new(30, 100)
		expect(q:enqueue(item("a", "first:T4_01"), 0)).toBeTrue()
		expect(q:enqueue(item("a", "first:T4_02"), 0)).toBeTrue()
		expect(q:size()).toBe(2)
	end)

	it("items without a dedupKey are never deduped", function()
		local q = AnnouncementQueue.new(30, 100)
		expect(q:enqueue({ kind = "x", message = "m" }, 0)).toBeTrue()
		expect(q:enqueue({ kind = "x", message = "m" }, 0)).toBeTrue()
		expect(q:size()).toBe(2)
	end)

	it("clearDedup forgets seen keys", function()
		local q = AnnouncementQueue.new(30, 100)
		q:enqueue(item("a", "first:T4_01"), 0)
		q:clearDedup()
		expect(q:enqueue(item("a", "first:T4_01"), 1)).toBeTrue()
	end)
end)
