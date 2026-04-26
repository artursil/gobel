package.path = package.path .. ";./?.lua;./?/init.lua"

local M = {}

if not love then
	love = {}
end

if not love.math then
	love.math = {}
end

if not love.math.random then
	function love.math.random(min_value, max_value)
		if max_value then
			return min_value
		end
		return 1
	end
end

function M.rng_always_one(_max_value)
	return 1
end

function M.copy_ids(ids)
	local out = {}
	for i = 1, #ids do
		out[i] = ids[i]
	end
	return out
end

return M
