-- MockClock: injectable clock for Lune tests.
-- Replaces os.time() in pure Core modules.

local MockClock = {}
MockClock.__index = MockClock

type MockClockInstance = {
	_time: number,
	now: (self: MockClockInstance) -> number,
	advance: (self: MockClockInstance, seconds: number) -> (),
	set: (self: MockClockInstance, t: number) -> (),
}

function MockClock.new(startTime: number?): MockClockInstance
	return setmetatable({ _time = startTime or 0 }, MockClock) :: any
end

function MockClock:now(): number
	return self._time
end

function MockClock:advance(seconds: number)
	self._time = self._time + seconds
end

function MockClock:set(t: number)
	self._time = t
end

return MockClock
