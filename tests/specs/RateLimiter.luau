-- RateLimiter token-bucket tests.

local spec = require("../spec")
local RateLimiter = require("../../src/shared/Core/RateLimiter")

local describe, it, expect = spec.describe, spec.it, spec.expect

describe("RateLimiter — allow", function()
	it("first request on a fresh key is allowed", function()
		local buckets = {}
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100)).toBeTrue()
	end)

	it("allows a burst up to capacity at the same instant, then rejects", function()
		local buckets = {}
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100)).toBeTrue() -- token 2 -> 1
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100)).toBeTrue() -- token 1 -> 0
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100)).toBeFalse() -- empty
	end)

	it("refills at the configured rate over time", function()
		local buckets = {}
		RateLimiter.allow(buckets, "1:Foo", 2, 2, 100) -- 2 -> 1
		RateLimiter.allow(buckets, "1:Foo", 2, 2, 100) -- 1 -> 0
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100)).toBeFalse()
		-- 0.5s at 2 tokens/s = +1 token
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 100.5)).toBeTrue()
	end)

	it("does not refill beyond capacity", function()
		local buckets = {}
		RateLimiter.allow(buckets, "1:Foo", 2, 2, 100) -- 2 -> 1
		-- 100s later it would refill 200 tokens, but capacity caps it at 2
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 200)).toBeTrue() -- 2 -> 1
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 200)).toBeTrue() -- 1 -> 0
		expect(RateLimiter.allow(buckets, "1:Foo", 2, 2, 200)).toBeFalse()
	end)

	it("supports fractional rates (0.1/s = one per 10s)", function()
		local buckets = {}
		expect(RateLimiter.allow(buckets, "1:Slow", 0.1, 1, 0)).toBeTrue() -- 1 -> 0
		expect(RateLimiter.allow(buckets, "1:Slow", 0.1, 1, 5)).toBeFalse() -- +0.5 token
		expect(RateLimiter.allow(buckets, "1:Slow", 0.1, 1, 10)).toBeTrue() -- +1.0 token
	end)

	it("keys are independent (per player + per remote)", function()
		local buckets = {}
		RateLimiter.allow(buckets, "1:Foo", 1, 1, 0) -- drains player 1 / Foo
		expect(RateLimiter.allow(buckets, "1:Foo", 1, 1, 0)).toBeFalse()
		expect(RateLimiter.allow(buckets, "2:Foo", 1, 1, 0)).toBeTrue() -- different player
		expect(RateLimiter.allow(buckets, "1:Bar", 1, 1, 0)).toBeTrue() -- different remote
	end)
end)

describe("RateLimiter — clear", function()
	it("drops only buckets matching the prefix", function()
		local buckets = {}
		RateLimiter.allow(buckets, "1:Foo", 1, 1, 0)
		RateLimiter.allow(buckets, "1:Bar", 1, 1, 0)
		RateLimiter.allow(buckets, "2:Foo", 1, 1, 0)

		RateLimiter.clear(buckets, "1:")

		expect(buckets["1:Foo"]).toBeNil()
		expect(buckets["1:Bar"]).toBeNil()
		expect(buckets["2:Foo"] ~= nil).toBeTrue()
	end)
end)
