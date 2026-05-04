--- Game type definitions with stone and deck configurations
--- @module game_types.definitions

local M = {}

M.standard = {
	id = "standard",
	name = "Standard",
	description = "Standard game with all stones and cards",
	black_stones = {
		stone_basic = 5,
		stone_power = 3,
		stone_focus = 2,
		stone_lieutenant = 2,
		stone_tower = 1,
	},
	white_stones = {
		stone_basic = 5,
		stone_power = 3,
		stone_focus = 2,
		stone_lieutenant = 2,
		stone_tower = 1,
	},
	stone_hand_size = 6,
	black_deck = nil,
	white_deck = nil,
	black_poses = nil,
	white_poses = nil,
	black_energy_max = 3,
	white_energy_max = 3,
}

M.basic_stones = {
	id = "basic_stones",
	name = "Basic Stones Only",
	description = "Only basic stones, no cards or poses",
	black_stones = {
		stone_basic = 20,
	},
	white_stones = {
		stone_basic = 20,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_poses = { fixed = {}, swappable = {} },
	white_poses = { fixed = {}, swappable = {} },
	black_energy_max = 3,
	white_energy_max = 3,
}

M.all_towers = {
	id = "all_towers",
	name = "All Towers",
	description = "All players have only tower stones",
	black_stones = {
		stone_tower = 20,
	},
	white_stones = {
		stone_tower = 20,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_poses = { fixed = {}, swappable = {} },
	white_poses = { fixed = {}, swappable = {} },
	black_energy_max = 3,
	white_energy_max = 3,
}

M.asymmetric = {
	id = "asymmetric",
	name = "Asymmetric",
	description = "Black has lieutenants, white has basic stones",
	black_stones = {
		stone_lieutenant = 20,
	},
	white_stones = {
		stone_basic = 20,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_poses = { fixed = {}, swappable = {} },
	white_poses = { fixed = {}, swappable = {} },
	black_energy_max = 3,
	white_energy_max = 3,
}

function M.get_game_type(type_id)
	return M[type_id]
end

function M.get_all_types()
	return {
		{ id = "standard", name = M.standard.name },
		{ id = "basic_stones", name = M.basic_stones.name },
		{ id = "all_towers", name = M.all_towers.name },
		{ id = "asymmetric", name = M.asymmetric.name },
	}
end

return M
