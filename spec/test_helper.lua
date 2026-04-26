package.path = package.path .. ";./?.lua;./?/init.lua"

local M = {}

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
