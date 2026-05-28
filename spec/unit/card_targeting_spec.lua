local board = require("board")
local config = require("config")
local match_state = require("match_state")
local resolver = require("resolver")
local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local function new_started_state(seed)
	local state = match_state.new_match("pvp", seed or 1)
	state.players.black.stances.fixed = {}
	state.players.black.stances.swappable = {}
	state.players.white.stances.fixed = {}
	state.players.white.stances.swappable = {}
	local started = resolver.begin_turn(state, "black")
	assert.is_true(started.ok)
	return state
end

describe("card target tags and validation", function()
	it("resolves runtime tags for stone targets", function()
		local state = new_started_state(41)
		state.board[3][3] = board.make_stone(config.STONE_BLACK, "stone_basic", 2)
		state.board[3][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 4)

		local self_tags = resolver.resolve_target_tags({ object_type = "stone", row = 3, col = 3 }, "black", state)
		local opp_tags = resolver.resolve_target_tags({ object_type = "stone", row = 3, col = 4 }, "black", state)
		local self_set = {}
		local opp_set = {}
		for i = 1, #self_tags do
			self_set[self_tags[i]] = true
		end
		for i = 1, #opp_tags do
			opp_set[opp_tags[i]] = true
		end
		assert.is_true(self_set.owner_self)
		assert.is_true(self_set.damaged)
		assert.is_true(opp_set.owner_opponent)
		assert.is_true(opp_set.targetable)
	end)

	it("validates target sets by target-side tags", function()
		local state = new_started_state(42)
		state.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic", 3)
		state.board[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 3)
		local attack = require("content").get_card("card_attack_1")
		local heal = require("content").get_card("card_heal_1")
		local ok_attack = resolver.validate_card_targets(attack, { { object_type = "stone", row = 4, col = 4 } }, state, "black")
		local bad_attack = resolver.validate_card_targets(attack, { { object_type = "stone", row = 5, col = 4 } }, state, "black")
		local ok_heal = resolver.validate_card_targets(heal, { { object_type = "stone", row = 5, col = 4 } }, state, "black")
		assert.is_true(ok_attack.ok)
		assert.is_false(bad_attack.ok)
		assert.is_true(ok_heal.ok)
	end)

	it("validates multi-card target count and ownership", function()
		local state = new_started_state(43)
		state.players.black.cards.hand.ids = { "card_point_tap", "card_small_mult", "card_big_mult" }
		local card_def = require("content").get_card("card_money_discard_2")
		local valid = resolver.validate_card_targets(card_def, {
			{ object_type = "card", owner = "black", hand_index = 1 },
			{ object_type = "card", owner = "black", hand_index = 2 },
		}, state, "black")
		local invalid = resolver.validate_card_targets(card_def, {
			{ object_type = "card", owner = "black", hand_index = 1 },
		}, state, "black")
		assert.is_true(valid.ok)
		assert.is_false(invalid.ok)
	end)

	it("rejects duplicate targets for target_multi", function()
		local state = new_started_state(44)
		state.players.black.cards.hand.ids = { "card_point_tap", "card_small_mult" }
		local card_def = require("content").get_card("card_money_discard_2")
		local result = resolver.validate_card_targets(card_def, {
			{ object_type = "card", owner = "black", hand_index = 1 },
			{ object_type = "card", owner = "black", hand_index = 1 },
		}, state, "black")
		assert.is_false(result.ok)
		assert.are.equal("Duplicate target selected", result.error)
	end)

	it("resolves owner tags by explicit actor instead of state.to_play", function()
		local state = new_started_state(45)
		state.to_play = "white"
		state.board[2][2] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local tags = resolver.resolve_target_tags({ object_type = "stone", row = 2, col = 2 }, "black", state)
		local set = {}
		for i = 1, #tags do
			set[tags[i]] = true
		end
		assert.is_true(set.owner_self)
		assert.is_nil(set.owner_opponent)
	end)
end)
