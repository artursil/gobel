require("spec.test_helper")

local config = require("config")
local animation_kinds = require("ui.animation_kinds")
local animations = require("ui.animations")
local game = require("game")
local object_animations = require("objects.animations")
local resolve_round = require("single_game.resolver.resolve_round")
local P = require("spec.parameters_helper")

describe("ui.animation_kinds registry", function()
	it("spawn_job_from_intent merges defaults and intent overrides for stance_shake", function()
		local intent = {
			type = "stance_shake",
			owner = config.OWNER_BLACK,
			stance_slot_index = 2,
			start_delay_ms = 50,
			duration_ms = 300,
		}
		local job = animation_kinds.spawn_job_from_intent(intent, nil, nil)
		assert.is_not_nil(job)
		assert.are.equal("stance_shake", job.animation_id)
		assert.are.equal(0.05, job.delay_start_s)
		assert.are.equal(0.3, job.dur_s)
		assert.are.equal(config.OWNER_BLACK, job.owner)
		assert.are.equal(2, job.stance_slot_index)
		assert.are.equal(6, job.shake_amp_max)
	end)

	it("spawn_job_from_intent returns nil for unknown intent type", function()
		local job = animation_kinds.spawn_job_from_intent({ type = "unknown_animation_kind_xyz" }, nil, nil)
		assert.is_nil(job)
	end)

	it("spawn_job_from_intent returns nil when required stance fields are missing", function()
		assert.is_nil(animation_kinds.spawn_job_from_intent({ type = "stance_shake", owner = config.OWNER_BLACK }, nil, nil))
	end)

	it("spawn_job_from_intent builds hand_card_float_text job with default rise_px", function()
		local job = animation_kinds.spawn_job_from_intent({
			type = "hand_card_float_text",
			owner = config.OWNER_BLACK,
			hand_index = 1,
			text = "×1.5",
		}, nil, nil)
		assert.is_not_nil(job)
		assert.are.equal("hand_card_float_text", job.animation_id)
		assert.are.equal(52, job.rise_px)
		assert.are.equal(32, job.font_size_px)
		assert.are.equal("×1.5", job.text)
	end)

	it("spawn_job_from_intent builds display_update_x_mult job with value and field", function()
		local job = animation_kinds.spawn_job_from_intent({
			type = "display_update_x_mult",
			owner = config.OWNER_BLACK,
			value = 2.25,
		}, nil, nil)
		assert.is_not_nil(job)
		assert.are.equal("display_update_x_mult", job.animation_id)
		assert.are.equal("x_mult", job.field)
		assert.is_true(math.abs(job.value - 2.25) < 1e-9)
		assert.are.equal(config.OWNER_BLACK, job.owner)
	end)

	it("drain_state_intents empties ui_animation_events after dispatch", function()
		local layout = {
			player_stances_panel = { x = 0, y = 0, w = 200, h = 300 },
			opponent_stances_panel = { x = 600, y = 0, w = 200, h = 200 },
			hand_panel = { x = 200, y = 400, w = 400, h = 200 },
		}
		local game = {
			players = {
				black = { stances = { fixed = { "stance_point" }, swappable = {} }, cards = { hand = { ids = { "card_steel" } } } },
				white = { stances = { fixed = {}, swappable = {} }, cards = { hand = { ids = {} } } },
			},
			temporary_stances = {},
			ui_animation_events = {
				{ type = "stance_shake", owner = config.OWNER_BLACK, stance_slot_index = 1 },
			},
		}
		animations.drain_state_intents(game, layout)
		assert.are.same({}, game.ui_animation_events)
	end)

	it("pattern_x_celebrate emits bounces then per-x_stone float labels", function()
		local state = { ui_animation_events = {}, ui_animation_seq_counter = 0 }
		local board_after = {
			{},
			{},
			{ {}, {}, { kind = "x_stone" }, {}, { kind = "stone_basic" } },
			{},
			{ {}, {}, { kind = "stone_basic" }, {}, { kind = "x_stone" } },
		}
		object_animations.add_animation("pattern_x_celebrate")(state, {
			owner = config.OWNER_BLACK,
			cells = { { 3, 3 }, { 3, 5 }, { 5, 3 }, { 5, 5 } },
			board_after = board_after,
		})
		assert.are.equal(6, #state.ui_animation_events)
		for i = 1, 4 do
			assert.are.equal("board_stone_bounce", state.ui_animation_events[i].type)
		end
		local x_label = P.x_mult_animation_label()
		assert.are.equal("board_stone_float_text", state.ui_animation_events[5].type)
		assert.are.equal(x_label, state.ui_animation_events[5].text)
		assert.are.equal(3, state.ui_animation_events[5].row)
		assert.are.equal(3, state.ui_animation_events[5].col)
		assert.are.equal(x_label, state.ui_animation_events[6].text)
		assert.are.equal(5, state.ui_animation_events[6].row)
	end)

	it("pattern_x_celebrate shows per-stone x2 not combined product", function()
		local state = { ui_animation_events = {}, ui_animation_seq_counter = 0 }
		local board_after = {
			{},
			{},
			{ {}, {}, { kind = "x_stone" }, {}, { kind = "x_stone" } },
			{},
			{ {}, {}, { kind = "stone_basic" }, {}, { kind = "stone_basic" } },
		}
		object_animations.add_animation("pattern_x_celebrate")(state, {
			owner = config.OWNER_BLACK,
			cells = { { 3, 3 }, { 3, 5 }, { 5, 3 }, { 5, 5 } },
			board_after = board_after,
		})
		local x_label = P.x_mult_animation_label()
		assert.are.equal(x_label, state.ui_animation_events[5].text)
		assert.are.equal(x_label, state.ui_animation_events[6].text)
		assert.are.not_equal(
			P.format_x_mult_animation_label(P.stone.x_stone_mult_factor * P.stone.x_stone_mult_factor),
			state.ui_animation_events[5].text
		)
	end)

	it("wall_stone_bounce emits one float per wall points block in group", function()
		local state = { ui_animation_events = {}, ui_animation_seq_counter = 0 }
		local cells = {}
		for i = 1, 10 do
			cells[i] = { 3, i }
		end
		local bonus = P.wall_points(10)
		object_animations.add_animation("wall_stone_bounce")(state, {
			owner = config.OWNER_BLACK,
			cells = cells,
			anchor_row = 3,
			anchor_col = 6,
			bonus = bonus,
		})
		local floats = 0
		local wall_label = P.wall_points_float_label()
		for i = 1, #state.ui_animation_events do
			local it = state.ui_animation_events[i]
			if it.type == "board_stone_float_text" then
				floats = floats + 1
				assert.are.equal(wall_label, it.text)
			end
		end
		assert.are.equal(bonus / P.stone.wall_points_per_block, floats)
	end)

	it("resolve_round does not clear ui_animation_events at start", function()
		local g = game.new("pvp", "basic_stones")
		g.ui_animation_events = {
			{ type = "board_stone_bounce", owner = config.OWNER_BLACK, row = 1, col = 1 },
		}
		resolve_round.resolve(g, { macro = "end_of_turn" })
		assert.are.equal(1, #g.ui_animation_events)
	end)

	it("board_stone_bounce_offset follows active bounce job", function()
		local layout = {
			player_stances_panel = { x = 0, y = 0, w = 200, h = 300 },
			opponent_stances_panel = { x = 600, y = 0, w = 200, h = 200 },
			hand_panel = { x = 200, y = 400, w = 400, h = 200 },
			board_metrics = { n = 9, x = 0, y = 0, w = 400, h = 400, cell = 40 },
		}
		local game = {
			players = {
				black = { stances = { fixed = {}, swappable = {} }, cards = { hand = { ids = {} } } },
				white = { stances = { fixed = {}, swappable = {} }, cards = { hand = { ids = {} } } },
			},
			temporary_stances = {},
			ui_animation_events = {
				{
					type = "board_stone_bounce",
					owner = config.OWNER_BLACK,
					row = 4,
					col = 5,
					duration_ms = 200,
					start_delay_ms = 0,
				},
			},
		}
		animations.drain_state_intents(game, layout)
		animations.update(0.1, game, layout)
		local off = animations.board_stone_bounce_offset(4, 5)
		assert.is_true(off > 0)
	end)

	it("tick_job_age removes job when elapsed past end", function()
		local job = {
			animation_id = "stance_shake",
			age = 0,
			delay_start_s = 0,
			dur_s = 0.1,
		}
		assert.is_false(animation_kinds.tick_job_age(job, 0.05))
		assert.is_true(animation_kinds.tick_job_age(job, 0.06))
	end)
end)
