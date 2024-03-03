--[[
	Credits to sleitnick for the code;;;;
	all this does it make it so you can chain the TblUtil methods together.
	Example:
	local CT = require(PathToCT)
	local tbl = CT{1, 2, 3, 4, 5}
	local result = tbl:Map(function(v) return v * 2 end):Filter(function(v) return v > 5 end):Reduce(function(acc, v) return acc + v end):Get()
	print(result) -- 18
	]]
local HttpService = game:GetService("HttpService")

type ChainTableImpl = {
	__index: ChainTableImpl,
	__call: <T>(t: T) -> { any },
	Shuffle: (self: ChainTable, rngOverride: Random?) -> ChainTable,
	Sample: <T>(self: ChainTable, size: number, rngOverride: Random?) -> ChainTable,
	new: <T>(t: { T }) -> ChainTable,
	Map: <T, M>(self: ChainTable, f: (value: T) -> M) -> ChainTable,
	Filter: <T>(self: ChainTable, predicate: (value: T, key: any, tbl: { T }) -> (boolean | string)?) -> ChainTable,
	Reduce: <T, R>(self: ChainTable, predicate: (result: R, value: T, index: number, table: { T }) -> R, init: R) -> R,
	Find: <K, V>(self: ChainTable, callback: (value: V, key: K, tbl: { [K]: V }) -> boolean) -> (V?, K?),
	Every: <K, V>(self: ChainTable, callback: (value: V, key: K, tbl: { [K]: V }) -> boolean) -> boolean,
	Some: <K, V>(self: ChainTable, callback: (value: V, key: K, tbl: { [K]: V }) -> boolean) -> boolean,
	IsEmpty: (self: ChainTable) -> boolean,
	Concat: (self: ChainTable, sep: string?, i: number?, j: number?) -> string,
	Sort: (self: ChainTable, predicate: (a: any, b: any) -> ()) -> ChainTable,
	Slice: (self: ChainTable, startNum: number, endNum: number) -> ChainTable,
	Length: (self: ChainTable) -> number,
	EncodeJSON: (self: ChainTable) -> string,
	Get: (self: ChainTable) -> { any },
}

type ChainTable = typeof(setmetatable({} :: { _table: { any } }, {} :: ChainTableImpl))

local ChainTable: ChainTableImpl = {} :: ChainTableImpl
ChainTable.__index = ChainTable
ChainTable.__call = function(table)
	return table:Get()
end

function ChainTable.new<T>(t)
	local self = setmetatable({}, ChainTable)
	self._table = t
	self._rng = Random.new()
	return self
end

function ChainTable:Shuffle(rngOverride)
	local tbl = self:Get()
	local shuffled = table.clone(tbl)
	local random = if typeof(rngOverride) == "Random" then rngOverride else self._rng
	for i = #tbl, 2, -1 do
		local j = random:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return ChainTable.new(shuffled)
end

function ChainTable:Sample<T>(size, rngOverride)
	local tbl = self:Get()
	assert(type(size) == "number", "Second argument must be a number")

	-- If given table is empty, just return a new empty table:
	local len = #tbl
	if len == 0 then
		return {}
	end

	local shuffled = table.clone(tbl)
	local sample = table.create(size)
	local random = if typeof(rngOverride) == "Random" then rngOverride else self._rng

	-- Clamp sample size to be no larger than the given table size:
	size = math.clamp(size, 1, len)

	for i = 1, size do
		local j = random:NextInteger(i, len)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	table.move(shuffled, 1, size, 1, sample)

	return ChainTable.new(sample)
end

function ChainTable:Map<T, M>(f)
	local tbl = self:Get()
	assert(type(f) == "function", "Argument must be a function")
	local newT = table.create(#tbl)
	for k, v in tbl do
		newT[k] = f(v, k, tbl)
	end

	return ChainTable.new(newT)
end

function ChainTable:Filter<T>(predicate)
	local tbl = self:Get()
	assert(type(predicate) == "function", "Argument must be a function")
	local newT = table.create(#tbl)
	if #tbl > 0 then
		local n = 0
		for i, v in tbl do
			if predicate(v, i, tbl) then
				n += 1
				newT[n] = v
			end
		end
	else
		for k, v in tbl do
			if predicate(v, k, tbl) then
				newT[k] = v
			end
		end
	end
	return ChainTable.new(newT)
end

function ChainTable:Reduce<T, R>(predicate: (R, T, number, { T }) -> R, init: R)
	local tbl = self:Get()
	assert(type(predicate) == "function", "Second argument must be a function")
	local result = init :: R
	if #tbl > 0 then
		local start = 1
		if init == nil then
			result = (tbl[1] :: any) :: R
			start = 2
		end
		for i = start, #tbl do
			result = predicate(result, tbl[i], i, tbl)
		end
	else
		local start = nil
		if init == nil then
			result = (next(tbl) :: any) :: R
			start = result
		end
		for k, v in next, tbl, start :: any? do
			result = predicate(result, v, k, tbl)
		end
	end

	return result
end

function ChainTable:Find<K, V>(callback)
	local tbl = self:Get()
	for k, v in tbl do
		if callback(v, k, tbl) then
			return v, k
		end
	end
	return nil, nil
end

function ChainTable:Every<K, V>(callback)
	local tbl = self:Get()
	for k, v in tbl do
		if not callback(v, k, tbl) then
			return false
		end
	end
	return true
end

function ChainTable:Some<K, V>(callback)
	local tbl = self:Get()
	for k, v in tbl do
		if callback(v, k, tbl) then
			return true
		end
	end
	return false
end

function ChainTable:Concat(sep, i, j)
	local tbl = self:Get()
	return table.concat(tbl, sep, i, j)
end

function ChainTable:IsEmpty()
	local tbl = self:Get()
	return next(tbl) == nil
end

function ChainTable:Sort(predicate)
	local tbl = self:Get()
	table.sort(tbl, function(a, b)
		return predicate(a, b)
	end)
	return ChainTable.new(tbl)
end

function ChainTable:Slice(i, j)
	local tbl = self:Get()
	return ChainTable.new({table.unpack(tbl, i, j)})
end

function ChainTable:Length()
	local tbl = self:Get()

	local len = 0
	for _ in pairs(tbl) do
		len += 1
	end
	
	return #tbl
end

function ChainTable:EncodeJSON()
	local tbl = self:Get()
	return HttpService:JSONEncode(tbl)
end

function ChainTable:Get()
	local table = self._table
	setmetatable(self, nil)
	self = nil
	return table
end

return ChainTable.new
