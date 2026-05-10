require("spec.test_helper")

local effects = require("objects.effects")
local conditions = require("objects.conditions")

describe("T-102 effects with conditions integration", function()
	it("applies effect when all conditions pass", function()
		local state = {
			scores = {
				points = { B = 0, W = 0 },
			},
		}
		local effect_def = {
			effect_name = "add_points",
			value = 5,
			conditions = {
				{ condition_name = "always" },
			},
		}
		local resolved = effects.resolve(effect_def)
		local context = { state = state }

		if conditions.eval_all(resolved.conditions, context) then
			resolved.apply(state, "B")
		end

		assert.are.equal(5, state.scores.points.B)
	end)

	it("skips effect when condition fails", function()
		local state = {
			scores = {
				points = { B = 0, W = 0 },
			},
		}
		local effect_def = {
			effect_name = "add_points",
			value = 5,
			conditions = {
				{ condition_name = "never" },
			},
		}
		local resolved = effects.resolve(effect_def)
		local context = { state = state }

		if conditions.eval_all(resolved.conditions, context) then
			resolved.apply(state, "B")
		end

		assert.are.equal(0, state.scores.points.B)
	end)

	it("applies effect when no conditions present (default pass)", function()
		local state = {
			scores = {
				points = { B = 0, W = 0 },
			},
		}
		local effect_def = {
			effect_name = "add_points",
			value = 7,
		}
		local resolved = effects.resolve(effect_def)
		local context = { state = state }

		if conditions.eval_all(resolved.conditions, context) then
			resolved.apply(state, "B")
		end

		assert.are.equal(7, state.scores.points.B)
	end)

	it("applies multiple sequential effects with different conditions", function()
		local state = {
			scores = {
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
			},
		}
		local effects_defs = {
			{
				effect_name = "add_points",
				value = 3,
				conditions = { { condition_name = "always" } },
			},
			{
				effect_name = "add_mult",
				value = 2,
				conditions = { { condition_name = "never" } },
			},
		}

		for _, effect_def in ipairs(effects_defs) do
			local resolved = effects.resolve(effect_def)
			local context = { state = state }
			if conditions.eval_all(resolved.conditions, context) then
				if resolved.apply then
					resolved.apply(state, "B")
				end
			end
		end

		assert.are.equal(3, state.scores.points.B)
		assert.are.equal(1, state.scores.plus_mult.B)
	end)
end)
