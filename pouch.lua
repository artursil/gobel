local M = {}
local array_utils = require("array_utils")

function M.shuffle_init(ids, rng_next_int)
	local shuffled = array_utils.clone(ids)
	array_utils.shuffle_in_place(shuffled, rng_next_int)
	return { ids = shuffled }
end

function M.remaining_count(pouch_state)
	return #pouch_state.ids
end

function M.draw(pouch_state)
	if #pouch_state.ids == 0 then
		return nil
	end
	local stone_id = pouch_state.ids[#pouch_state.ids]
	pouch_state.ids[#pouch_state.ids] = nil
	return stone_id
end

function M.remove_one(pouch_state, stone_id)
	for i = #pouch_state.ids, 1, -1 do
		if pouch_state.ids[i] == stone_id then
			table.remove(pouch_state.ids, i)
			return true
		end
	end
	return false
end

function M.peek_next(pouch_state)
	if #pouch_state.ids == 0 then
		return nil
	end
	return pouch_state.ids[#pouch_state.ids]
end

function M.peek_many(pouch_state, count)
	local out = {}
	local last = #pouch_state.ids
	for i = 0, count - 1 do
		local idx = last - i
		if idx < 1 then
			break
		end
		out[#out + 1] = pouch_state.ids[idx]
	end
	return out
end

return M
