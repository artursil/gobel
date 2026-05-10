--- Runtime PlayerGameState implementation conforming to single_game/player_game_state.schema.md
--- Nested under game_state.players.B (black) / .W (white)
--- @module single_game.player_game_state

local M = {}

--- Create a new PlayerGameState for a player.
--- @param owner string: `config.OWNER_BLACK` (`"B"`) or `config.OWNER_WHITE` (`"W"`)
--- @return table: Fully initialized PlayerGameState
function M.new(owner)
	return {
		owner = owner,

		resources = {
			energy_current = 3,
			energy_max = 3,
			money_delta_this_game = 0,
		},

		limits = {
			cards_per_turn = 999,
			stones_per_turn = 1,
			hand_size_cards = 4,
			hand_size_stones = 6,
		},

		card_zones = {
			draw_pile = { instance_ids = {} },
			hand = { instance_ids = {} },
			discard = { instance_ids = {} },
			exhaust = { instance_ids = {} },
			destroyed = { instance_ids = {} },
		},

		stone_zones = {
			pouch = { instance_ids = {} },
			hand = { instance_ids = {} },
			board = { instance_ids = {} },
			captured = { instance_ids = {} },
			destroyed = { instance_ids = {} },
		},

		stances = {
			visible = { instance_ids = {} },
			hidden = { instance_ids = {} },
		},

		counters = {
			prisoners_captured = 0,
			stones_captured = 0,
			cards_played = 0,
			stones_played = 0,
			turns_without_playing_card = 0,
			turns_without_playing_stone = 0,
		},
	}
end

--- Add instance to a zone.
--- @param player_state table
--- @param zone_path string: e.g., "card_zones.hand"
--- @param instance_id string
--- @return nil
function M.add_to_zone(player_state, zone_path, instance_id)
	local parts = {}
	for part in zone_path:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	local zone = player_state
	for i = 1, #parts - 1 do
		zone = zone[parts[i]]
	end
	local zone_name = parts[#parts]
	table.insert(zone[zone_name].instance_ids, instance_id)
end

--- Remove instance from a zone.
--- @param player_state table
--- @param zone_path string: e.g., "card_zones.hand"
--- @param instance_id string
--- @return boolean: true if found and removed
function M.remove_from_zone(player_state, zone_path, instance_id)
	local parts = {}
	for part in zone_path:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	local zone = player_state
	for i = 1, #parts - 1 do
		zone = zone[parts[i]]
	end
	local zone_name = parts[#parts]
	local ids = zone[zone_name].instance_ids
	for i, id in ipairs(ids) do
		if id == instance_id then
			table.remove(ids, i)
			return true
		end
	end
	return false
end

return M
