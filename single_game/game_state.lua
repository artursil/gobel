--- Runtime game_state implementation conforming to single_game/game_state.schema.md
--- Single-game container, resets between games in a run.
--- @module single_game.game_state

local player_game_state = require("single_game.player_game_state")
local M = {}

--- Create a new game_state.
--- @param game_id string: Unique game identifier
--- @param game_index integer: Which game in the run
--- @return table: Fully initialized game_state
function M.new(game_id, game_index)
	return {
		meta = {
			game_id = game_id,
			game_index = game_index,
			phase = "TURN_START",
			turn_number = 1,
			round_number = 1,
			ended = false,
			end_reason = "none",
			winner = "none",
		},

		board = {
			grid = {},
			ko_ban = nil,
			placement_mask = nil,
			territory_value = {},
		},

		players = {
			A = player_game_state.new("A"),
			B = player_game_state.new("B"),
		},

		turn = {
			to_play = "A",
			consecutive_passes = 0,
			cards_played_this_turn = 0,
			stones_played_this_turn = 0,
		},

		scores = {
			turn_bonus = { A = 1, B = 1 },
			territory = { A = 0, B = 0 },
			points = { A = 0, B = 0 },
			plus_mult = { A = 1, B = 1 },
			x_mult = { A = 1, B = 1 },
			total = { A = 0, B = 0 },
		},

		effects = {
			active = {},
			distance_modifiers = {
				default_bonus = 0,
				by_stone_key = {},
			},
			listeners = {},
		},

		runtime = {
			last_played = {
				stone_instance_id = nil,
				card_instance_id = nil,
				by_player = {
					A = { stone_instance_id = nil, card_instance_id = nil },
					B = { stone_instance_id = nil, card_instance_id = nil },
				},
			},
			sequences = { A = {}, B = {} },
			predictions = {},
			message_queue = {},
			score_events = {},
		},
	}
end

--- Get player state by owner.
--- @param game_state table
--- @param owner string: "A" or "B"
--- @return table: PlayerGameState
function M.get_player(game_state, owner)
	return game_state.players[owner]
end

--- Set current phase.
--- @param game_state table
--- @param phase string: Phase name
--- @return nil
function M.set_phase(game_state, phase)
	game_state.meta.phase = phase
end

--- Advance turn number.
--- @param game_state table
--- @return integer: New turn number
function M.next_turn(game_state)
	game_state.meta.turn_number = game_state.meta.turn_number + 1
	return game_state.meta.turn_number
end

--- Advance round number.
--- @param game_state table
--- @return integer: New round number
function M.next_round(game_state)
	game_state.meta.round_number = game_state.meta.round_number + 1
	return game_state.meta.round_number
end

--- Mark game as ended.
--- @param game_state table
--- @param winner string: "A" or "B"
--- @param reason string: Why game ended
--- @return nil
function M.end_game(game_state, winner, reason)
	game_state.meta.ended = true
	game_state.meta.winner = winner
	game_state.meta.end_reason = reason
end

return M
