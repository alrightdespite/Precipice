-- MockDataStore: in-memory DataStore replacement for Lune tests.
-- Implements UpdateAsync, GetAsync, SetAsync, IncrementAsync.

local MockDataStore = {}
MockDataStore.__index = MockDataStore

type MockDataStoreInstance = {
	_data: { [string]: any },
	GetAsync: (self: MockDataStoreInstance, key: string) -> any,
	SetAsync: (self: MockDataStoreInstance, key: string, value: any) -> (),
	UpdateAsync: (self: MockDataStoreInstance, key: string, fn: (any) -> any) -> any,
	IncrementAsync: (self: MockDataStoreInstance, key: string, delta: number) -> number,
}

function MockDataStore.new(): MockDataStoreInstance
	return setmetatable({ _data = {} }, MockDataStore) :: any
end

function MockDataStore:GetAsync(key: string): any
	return self._data[key]
end

function MockDataStore:SetAsync(key: string, value: any)
	self._data[key] = value
end

function MockDataStore:UpdateAsync(key: string, fn: (any) -> any): any
	local current = self._data[key]
	local new = fn(current)
	if new ~= nil then
		self._data[key] = new
	end
	return new
end

function MockDataStore:IncrementAsync(key: string, delta: number): number
	local current = (self._data[key] or 0) + delta
	self._data[key] = current
	return current
end

function MockDataStore:RemoveAsync(key: string): any
	local prev = self._data[key]
	self._data[key] = nil
	return prev
end

return MockDataStore
