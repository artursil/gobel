--- Read-only facade over match state for AI strategies.
--- @module ai.adapters.match_view

local ai_config = require("ai.config")
local config = require("config")
local match_state = require("match_state")

local M = {}

--- @class MatchView
--- @field package _game table
--- @field package _actor "black"|"white"
local MatchView = {}
MatchView.__index = MatchView

--- @return "black"|"white"
function M.bot_actor()
	if config.AI_COLOR == config.STONE_WHITE then
		return "white"
	end
	return "black"
end

--- @param actor "black"|"white"
--- @return "black"|"white"
function M.opponent_actor(actor)
	if actor == "white" then
		return "black"
	end
	return "white"
end

--- @param game table
--- @param actor "black"|"white"
--- @return MatchView
function M.for_actor(game, actor)
	return setmetatable({ _game = game, _actor = actor }, MatchView)
end

--- Overlay board/ko for MCTS rollouts without mutating game state.
--- @param view table
--- @param board table
--- @param ko table|nil
--- @return MatchView
function M.with_board(view, board, ko)
	return setmetatable({
		_game = view._game,
		_actor = view._actor,
		_sim_board = board,
		_sim_ko = ko,
	}, MatchView)
end

--- @param game table
--- @return MatchView
function M.for_bot(game)
	return M.for_actor(game, M.bot_actor())
end

--- @return table
function MatchView:raw_game()
	return self._game
end

--- @return "black"|"white"
function MatchView:actor()
	return self._actor
end

--- @return string
function MatchView:phase()
	return self._game.phase
end

--- @return "black"|"white"
function MatchView:to_play()
	return self._game.to_play
end

--- @return boolean
function MatchView:versus_bot()
	return self._game.versus_bot == true
end

--- @return table
function MatchView:board()
	if self._sim_board then
		return self._sim_board
	end
	return self._game.board
end

--- @return table|nil
function MatchView:ko_ban()
	if self._sim_board then
		return self._sim_ko
	end
	return self._game.ko_ban
end

--- @return string|nil
function MatchView:ai_strategy()
	return self._game.ai_strategy
end

--- @return table|nil
function MatchView:ai_mcts()
	return self._game.ai_mcts
end

--- @return table
function MatchView:ai_settings()
	return ai_config.for_game(self._game)
end

--- @return boolean
function MatchView:planner_enabled()
	return self:ai_settings().planner.enabled
end

--- @return integer
function MatchView:planner_max_scripts()
	return self:ai_settings().planner.max_scripts
end

--- @return string|nil
function MatchView:territory_mode()
	return self._game.territory_mode
end

--- @return integer
function MatchView:stone_color()
	if self._actor == "black" then
		return config.STONE_BLACK
	end
	return config.STONE_WHITE
end

--- @return "B"|"W"
function MatchView:owner_key()
	if self._actor == "black" then
		return config.OWNER_BLACK
	end
	return config.OWNER_WHITE
end

--- @return table
function MatchView:player()
	return match_state.player_for_color(self._game, self._actor)
end

--- @return string[]
function MatchView:playable_stones()
	local stones = self:player().stones.playable_stones
	return stones or {}
end

--- @return string|nil
function MatchView:selected_stone_id()
	return self:player().stones.selected_stone
end

--- @return integer|nil
function MatchView:selected_stone_index()
	return self:player().stones.selected_stone_index
end

--- @return table
function MatchView:hand_card_ids()
	return self:player().cards.hand.ids or {}
end

--- @return integer
function MatchView:energy_current()
	return self:player().resources.energy_current or 0
end

--- @return table
function MatchView:stances()
	local p = self:player()
	return {
		fixed = p.stances.fixed or {},
		swappable = p.stances.swappable or {},
	}
end

--- @param max_value integer
--- @return integer
function MatchView:rng_next_int(max_value)
	return match_state.rng_next_int(self._game, max_value)
end

return M
