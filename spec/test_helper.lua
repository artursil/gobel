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

function M.get_upvalue(fn, target_name)
	local idx = 1
	while true do
		local name, value = debug.getupvalue(fn, idx)
		if not name then
			return nil
		end
		if name == target_name then
			return value, idx
		end
		idx = idx + 1
	end
end

function M.set_upvalue(fn, target_name, new_value)
	local idx = 1
	while true do
		local name = debug.getupvalue(fn, idx)
		if not name then
			return false
		end
		if name == target_name then
			debug.setupvalue(fn, idx, new_value)
			return true
		end
		idx = idx + 1
	end
end

function M.install_love_test_stubs()
	love = love or {}
	love.math = love.math or {}
	love.timer = love.timer or {}
	love.event = love.event or {}
	love.graphics = love.graphics or {}
	love.math.random = love.math.random
		or function(min_value, max_value)
			if max_value then
				return min_value
			end
			return 1
		end
	love.math.setRandomSeed = love.math.setRandomSeed or function() end
	love.timer.getTime = love.timer.getTime or function()
		return 1
	end
	love.event.quit = love.event.quit or function() end
	love.graphics.newFont = love.graphics.newFont or function()
		return { getHeight = function()
			return 18
		end }
	end
	love.graphics.setFont = love.graphics.setFont or function() end
	love.graphics.getFont = love.graphics.getFont or function()
		return { getHeight = function()
			return 18
		end }
	end
	love.graphics.getDimensions = love.graphics.getDimensions or function()
		return 1280, 720
	end
	love.graphics.getWidth = love.graphics.getWidth or function()
		return 1280
	end
	love.graphics.getHeight = love.graphics.getHeight or function()
		return 720
	end
	love.graphics.clear = love.graphics.clear or function() end
	love.graphics.setColor = love.graphics.setColor or function() end
	love.graphics.rectangle = love.graphics.rectangle or function() end
	love.graphics.circle = love.graphics.circle or function() end
	love.graphics.line = love.graphics.line or function() end
	love.graphics.polygon = love.graphics.polygon or function() end
	love.graphics.printf = love.graphics.printf or function() end
	love.graphics.print = love.graphics.print or function() end
	love.graphics.setLineWidth = love.graphics.setLineWidth or function() end
	love.graphics.push = love.graphics.push or function() end
	love.graphics.pop = love.graphics.pop or function() end
	love.graphics.translate = love.graphics.translate or function() end
	love.graphics.rotate = love.graphics.rotate or function() end
end

function M.reset_module(name)
	package.loaded[name] = nil
	return require(name)
end

return M
