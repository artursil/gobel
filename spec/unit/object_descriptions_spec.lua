local object_descriptions = require("ui.object_descriptions")

local function def_with_status()
	return {
		description = "Run-persistent mult: +3 on special stone, -3 on wall stone.",
		description_status = {
			kind = "run_counter",
			counter_key = "persistent_flux_mult",
			label = "Currently",
			signed = true,
		},
	}
end

describe("object_descriptions", function()
	it("get_lines returns status with signed counter when non-zero", function()
		local state = {
			run_state = {
				counters = {
					persistent_flux_mult = { B = 9, W = 0 },
				},
			},
		}
		local lines = object_descriptions.get_lines(def_with_status(), state, "B")
		assert.are.equal("Run-persistent mult: +3 on special stone, -3 on wall stone.", lines.static)
		assert.are.equal("Currently: +9", lines.status)
	end)

	it("get_lines omits status when counter is zero", function()
		local state = {
			run_state = {
				counters = {
					persistent_flux_mult = { B = 0, W = 0 },
				},
			},
		}
		local lines = object_descriptions.get_lines(def_with_status(), state, "B")
		assert.is_nil(lines.status)
	end)

	it("get_lines formats negative counters", function()
		local state = {
			run_state = {
				counters = {
					persistent_flux_mult = { B = -3, W = 0 },
				},
			},
		}
		local lines = object_descriptions.get_lines(def_with_status(), state, "B")
		assert.are.equal("Currently: -3", lines.status)
	end)

	it("get_full_text joins static and status with newline", function()
		local state = {
			run_state = {
				counters = {
					persistent_flux_mult = { B = 9, W = 0 },
				},
			},
		}
		local text = object_descriptions.get_full_text(def_with_status(), state, "B")
		assert.are.equal(
			"Run-persistent mult: +3 on special stone, -3 on wall stone.\nCurrently: +9",
			text
		)
	end)

	it("get_full_text returns static only when status hidden", function()
		local lines = object_descriptions.get_full_text(def_with_status(), nil, "B")
		assert.are.equal("Run-persistent mult: +3 on special stone, -3 on wall stone.", lines)
	end)
end)
