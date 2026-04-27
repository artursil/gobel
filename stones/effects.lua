local M = {}

function M.add_points(effect)
	return {
		type = "ADD_POINTS",
		value = effect.value,
		priority = effect.priority or 10,
	}
end

function M.add_mult(effect)
	return {
		type = "ADD_MULT",
		value = effect.value,
		priority = effect.priority or 10,
	}
end

function M.resolve(effect)
	local builder = M[effect.effect_name]
	if not builder then
		return nil
	end
	return builder(effect)
end

function M.resolve_board_stone(_stone_cell, _state)
	return {}
end

return M
