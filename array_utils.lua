local M = {}

function M.clone(ids)
	local out = {}
	for i = 1, #ids do
		out[i] = ids[i]
	end
	return out
end

function M.append_all(target, source)
	for i = 1, #source do
		target[#target + 1] = source[i]
	end
end

function M.shuffle_in_place(ids, rng_next_int)
	for i = #ids, 2, -1 do
		local j = rng_next_int(i)
		ids[i], ids[j] = ids[j], ids[i]
	end
end

return M
