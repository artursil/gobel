require("spec.test_helper")

local home = require("home")
local game_types = require("game_types.definitions")

describe("home game type navigation", function()
	local w = 1280
	local h = 720
	local dropdown = {
		x = (w - math.min(380, w - 48)) * 0.5,
		y = h * 0.5 - 30,
		w = math.min(380, w - 48),
		h = 60,
	}

	local function option_center(i)
		local y = dropdown.y + dropdown.h + (i - 1) * 50
		return dropdown.x + dropdown.w * 0.5, y + 24
	end

	local function pager_centers(option_count)
		local pager_y = dropdown.y + dropdown.h + option_count * 50 + 4
		local half_w = math.floor((dropdown.w - 8) * 0.5)
		local prev_x = dropdown.x + half_w * 0.5
		local next_x = dropdown.x + dropdown.w - half_w * 0.5
		local y = pager_y + 17
		return prev_x, next_x, y
	end

	it("returns next-page action for long lists", function()
		local list = game_types.get_all_types()
		assert.is_true(#list > 6)
		local _prev_x, next_x, pager_y = pager_centers(6)
		local pick = home.hit_test_game_type(next_x, pager_y, w, h, true, "standard", 1)
		assert.are.equal("dropdown_next_page", pick)
	end)

	it("selects visible option from the current page", function()
		local list = game_types.get_all_types()
		local expected = list[7]
		assert.is_not_nil(expected)
		local x, y = option_center(1)
		local pick = home.hit_test_game_type(x, y, w, h, true, "standard", 2)
		assert.are.equal("game_type:" .. expected.id, pick)
	end)

	it("clamps out-of-range pages to the last page", function()
		local list = game_types.get_all_types()
		local first_last_page = list[math.floor((#list - 1) / 6) * 6 + 1]
		local x, y = option_center(1)
		local pick = home.hit_test_game_type(x, y, w, h, true, "standard", 999)
		assert.are.equal("game_type:" .. first_last_page.id, pick)
	end)

	it("disabled pager actions are no-op, not close", function()
		local prev_x, _next_x, pager_y = pager_centers(6)
		local pick = home.hit_test_game_type(prev_x, pager_y, w, h, true, "standard", 1)
		assert.are.equal("dropdown_noop", pick)
	end)
end)
