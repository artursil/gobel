local M = {}

local function serialize(v, depth)
	depth = depth or 0
	local indent = string.rep("  ", depth)

	if type(v) == "table" then
		local s = "{\n"
		for k, val in pairs(v) do
			s = s .. indent .. "  [" .. tostring(k) .. "] = " .. serialize(val, depth + 1) .. ",\n"
		end
		return s .. indent .. "}"
	else
		return tostring(v)
	end
end

local function write_to_file(text)
	local path = "logs/debug_log.txt"
	local file = io.open(path, "a")
	if file then
		file:write(text)
		file:write("\n")
		file:close()
	end
end

--- Logs stack trace + optional variables snapshot to file
--- @param title string
--- @param vars table|nil
function M.log_stack(title, vars)
	local header = "\n====================\n"
	header = header .. "[TRACE] " .. tostring(title) .. "\n"

	-- stack trace (skip this function itself)
	local stack = debug.traceback("", 2)

	header = header .. "\n--- STACK TRACE ---\n"

	-- optional variable dump
	if vars ~= nil then
		header = header .. "\n--- VARIABLES ---\n"
		header = header .. serialize(vars) .. "\n"
    else
	header = header .. stack .. "\n"
    end

	header = header .. "====================\n"

	write_to_file(header)
end

return M