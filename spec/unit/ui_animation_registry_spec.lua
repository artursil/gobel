require("spec.test_helper")

local config = require("config")
local animation_kinds = require("ui.animation_kinds")
local animations = require("ui.animations")

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
