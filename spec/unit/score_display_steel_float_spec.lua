require("spec.test_helper")

local config = require("config")
local match_state = require("match_state")
local score_display = require("ui.score_display")

describe("steel float x_mult sync", function()
	it("apply_hand_float_x_mult_at_start updates presented x_mult once per job", function()
		local st = match_state.new_match("pvp", nil, 99)
		local baseline = score_display.snapshot_scores(st)
		st.players.black.score.x_mult = 4
		score_display.after_resolve(st, baseline, {
			{
				type = "hand_card_float_text",
				owner = config.OWNER_BLACK,
				hand_index = 1,
				text = "×1.5",
				presented_x_mult = 1.5,
			},
		})
		local job = {
			animation_id = "hand_card_float_text",
			age = 0,
			delay_start_s = 0,
			dur_s = 0.6,
			owner = config.OWNER_BLACK,
			presented_x_mult = 1.5,
			_score_x_mult_applied = false,
		}
		score_display.apply_hand_float_x_mult_at_start(job, st)
		assert.is_true(math.abs(score_display.effective_row(st, "black").x_mult - 1.5) < 0.0001)
		assert.are.equal(4, st.players.black.score.x_mult)
		job.presented_x_mult = 2.25
		job._score_x_mult_applied = false
		score_display.apply_hand_float_x_mult_at_start(job, st)
		assert.is_true(math.abs(score_display.effective_row(st, "black").x_mult - 2.25) < 0.0001)
	end)
end)
