require("spec.test_helper")

local config = require("config")
local match_state = require("match_state")
local score_display = require("ui.score_display")

describe("ui.score_display rollout", function()
	it("after_resolve with display_update_x_mult does not mutate player.score", function()
		local st = match_state.new_match("pvp", nil, 1)
		local baseline = score_display.snapshot_scores(st)
		st.players.black.score.x_mult = 8
		local intents = {
			{ type = "display_update_x_mult", owner = config.OWNER_BLACK, value = 2 },
		}
		score_display.after_resolve(st, baseline, intents)
		assert.is_true(score_display.is_rollout_active(st))
		assert.are.equal(1, score_display.effective_row(st, "black").x_mult)
		local job = {
			animation_id = "display_update_x_mult",
			age = 0,
			delay_start_s = 0,
			dur_s = 0.001,
			owner = config.OWNER_BLACK,
			field = "x_mult",
			value = 2,
			_display_value_applied = false,
		}
		score_display.apply_display_job_at_start(job, st)
		assert.are.equal(2, score_display.effective_row(st, "black").x_mult)
		assert.are.equal(8, st.players.black.score.x_mult)
		score_display.end_rollout(st)
		assert.are.equal(8, score_display.effective_row(st, "black").x_mult)
	end)

	it("after_resolve skips rollout when no display intents", function()
		local st = match_state.new_match("pvp", nil, 2)
		score_display.after_resolve(st, score_display.snapshot_scores(st), {})
		assert.is_false(score_display.is_rollout_active(st))
	end)
end)
