require("spec.test_helper")

local config = require("config")
local effects = require("objects.effects_conditions.effects")
local animations = require("objects.animations")

describe("ui animation steel sync (factory)", function()
	it("enqueue via add_animation steel_sync_mult appends shake plus floats when resolution matches", function()
		local state = {
			resolution = {
				source_def_id = "stance_gluttony",
				source_object_type = "stance",
				source_owner = config.OWNER_BLACK,
				source_stance_slot_index = 1,
				source_instance_id = nil,
			},
			scores = {
				x_mult = { B = 2.25, W = 1 },
			},
			ui_animation_events = {},
			ui_animation_seq_counter = 0,
		}
		animations.add_animation("steel_sync_mult")(state, {
			owner = config.OWNER_BLACK,
			steel_hand_indices = { 1, 3 },
			factor = 1.5,
			x_mult_steps = { 1.5, 2.25 },
		})
		assert.are.equal(3, #state.ui_animation_events)
		local sid = state.ui_animation_events[1].sequence_id
		assert.is_string(sid)
		for i = 1, 3 do
			assert.are.equal(sid, state.ui_animation_events[i].sequence_id)
		end
		assert.are.equal("stance_shake", state.ui_animation_events[1].type)
		assert.are.equal(1, state.ui_animation_events[1].stance_slot_index)
		assert.are.equal("hand_card_float_text", state.ui_animation_events[2].type)
		assert.are.equal(1, state.ui_animation_events[2].hand_index)
		assert.is_true(math.abs(state.ui_animation_events[2].presented_x_mult - 1.5) < 0.0001)
		assert.are.equal("hand_card_float_text", state.ui_animation_events[3].type)
		assert.are.equal(3, state.ui_animation_events[3].hand_index)
		assert.is_true(math.abs(state.ui_animation_events[3].presented_x_mult - 2.25) < 0.0001)
		assert.are.equal(600, state.ui_animation_events[2].duration_ms)
		assert.are.equal(600, state.ui_animation_events[3].duration_ms)
	end)

	it("steel_sync_mult no-ops when resolution is not steel sync stance", function()
		local state = {
			resolution = {
				source_def_id = "stance_point",
				source_object_type = "stance",
			},
			ui_animation_events = {},
		}
		animations.add_animation("steel_sync_mult")(state, {
			owner = config.OWNER_BLACK,
			steel_hand_indices = { 1 },
			factor = 1.5,
		})
		assert.are.equal(0, #state.ui_animation_events)
	end)

	it("count_and_multiply_x_mult emits intents only for steel sync stance resolution", function()
		local def = {
			effect_name = "count_and_multiply_x_mult",
			phase = "mult",
			value = 0.5,
			priority = 15,
		}
		local resolved = effects.resolve(def)
		local state = {
			resolution = {
				source_def_id = "stance_gluttony",
				source_object_type = "stance",
				source_owner = config.OWNER_BLACK,
				source_stance_index = 1,
				source_stance_slot_index = 1,
				source_instance_id = nil,
			},
			scores = {
				turn_bonus = { B = 1, W = 1 },
				territory = { B = 0, W = 0 },
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
				x_mult = { B = 1, W = 1 },
			},
			players = {
				black = {
					stances = { fixed = { "stance_gluttony" }, swappable = {} },
					cards = { hand = { ids = { "card_steel", "card_point_tap", "card_steel" } } },
				},
				white = { stances = { fixed = {}, swappable = {} }, cards = { hand = { ids = {} } } },
			},
			ui_animation_events = {},
		}
		resolved.apply(state, config.OWNER_BLACK)
		assert.is_true(state.scores.x_mult.B > 1)
		assert.are.equal(3, #state.ui_animation_events)
		local floats = 0
		for i = 1, #state.ui_animation_events do
			local it = state.ui_animation_events[i]
			if it.type == "hand_card_float_text" then
				floats = floats + 1
				assert.is_number(it.presented_x_mult)
			end
		end
		assert.are.equal(2, floats)
	end)

	it("count_and_multiply_x_mult does not emit when another stance uses the same builder", function()
		local def = {
			effect_name = "count_and_multiply_x_mult",
			phase = "mult",
			value = 0.5,
			priority = 15,
		}
		local resolved = effects.resolve(def)
		local state = {
			resolution = {
				source_def_id = "stance_hypothetical_other",
				source_object_type = "stance",
				source_owner = config.OWNER_BLACK,
				source_stance_index = 1,
				source_stance_slot_index = 1,
			},
			scores = {
				turn_bonus = { B = 1, W = 1 },
				territory = { B = 0, W = 0 },
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
				x_mult = { B = 1, W = 1 },
			},
			players = {
				black = {
					stances = { fixed = { "stance_hypothetical_other" }, swappable = {} },
					cards = { hand = { ids = { "card_steel" } } },
				},
				white = { stances = { fixed = {}, swappable = {} }, cards = { hand = { ids = {} } } },
			},
			ui_animation_events = {},
		}
		resolved.apply(state, config.OWNER_BLACK)
		assert.are.equal(0, #state.ui_animation_events)
	end)
end)
