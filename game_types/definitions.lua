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

M.special_steel_showcase = {
	id = "special_steel_showcase",
	name = "Special Steel Showcase",
	description = "Black has special stones, steel cards, and special-steel sync stance to showcase the new feature",
	black_stones = {
		stone_special = 10,
		stone_basic = 6,
	},
	white_stones = {
		stone_basic = 20,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_initial_hand = {
		"card_steel",
		"card_steel",
		"card_steel",
	},
	white_initial_hand = {},
	black_stances = { fixed = { "stance_special_steel_sync" }, swappable = {} },
	white_stances = { fixed = {}, swappable = {} },
	black_energy_max = 3,
	white_energy_max = 3,
}

M.temporary_stance_test = {
	id = "temporary_stance_test",
	name = "Temporary Stance Test",
	description = "Test temporary stance: black has focus_stance card (creates +5 pts/round for 3 rounds)",
	black_stones = {
		stone_basic = 20,
	},
	white_stones = {
		stone_basic = 20,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_initial_hand = {
		"card_focus_stance",
	},
	white_initial_hand = {},
	black_stances = { fixed = {}, swappable = {} },
	white_stances = { fixed = {}, swappable = {} },
	black_energy_max = 3,
	white_energy_max = 3,
}

M.vertical_slice_test = {
	id = "vertical_slice_test",
	name = "Vertical Slice Test",
	description = "Blueprint + persistent mult + targeted cards + wall/special stones.",
	black_stones = {
		stone_special = 8,
		stone_wall = 8,
		stone_basic = 6,
	},
	white_stones = {
		stone_special = 6,
		stone_wall = 6,
		stone_basic = 10,
	},
	stone_hand_size = 6,
	black_deck = {},
	white_deck = {},
	black_initial_hand = {
		"card_destroy_enemy_stone",
		"card_forge_mark",
	},
	white_initial_hand = {},
	black_stances = { fixed = { "stance_blueprint", "stance_persistent_flux", "stance_point" }, swappable = {} },
	white_stances = { fixed = { "stance_mult" }, swappable = {} },
	black_energy_max = 8,
	white_energy_max = 8,
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
		{ id = "special_steel_showcase", name = M.special_steel_showcase.name },
		{ id = "temporary_stance_test", name = M.temporary_stance_test.name },
		{ id = "vertical_slice_test", name = M.vertical_slice_test.name },
	}
end

return M
