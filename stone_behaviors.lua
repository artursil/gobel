local M = {}

local function add_points(value)
	return function()
		return {
			{ type = "ADD_POINTS", value = value },
		}
	end
end

local function add_mult(value)
	return function()
		return {
			{ type = "ADD_MULT", value = value },
		}
	end
end

M.add_points = add_points
M.add_mult = add_mult

return M
