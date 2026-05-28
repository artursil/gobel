local helper = require("spec.test_helper")

helper.install_love_test_stubs()
helper.reset_module("main")

local game_types = require("game_types.definitions")
local home = require("home")

describe("menu wheel game type paging", function()
	local w = 1280
	local h = 720

	local function dropdown_rect()
		local width = math.min(380, w - 48)
		return { x = (w - width) * 0.5, y = h * 0.5 - 30, w = width, h = 60 }
	end

	local function option_center(i)
		local d = dropdown_rect()
		local y = d.y + d.h + (i - 1) * 50 + 24
		return d.x + d.w * 0.5, y
	end

	before_each(function()
		helper.set_upvalue(love.wheelmoved, "screen", "menu")
		helper.set_upvalue(love.wheelmoved, "menu_step", "game_type")
		helper.set_upvalue(love.wheelmoved, "dropdown_open", true)
		helper.set_upvalue(love.wheelmoved, "dropdown_page", 1)
		helper.set_upvalue(love.mousepressed, "screen", "menu")
		helper.set_upvalue(love.mousepressed, "menu_step", "game_type")
		helper.set_upvalue(love.mousepressed, "dropdown_open", true)
		helper.set_upvalue(love.mousepressed, "dropdown_page", 1)
		helper.set_upvalue(love.mousepressed, "selected_game_type", "standard")
		love.mouse.getPosition = function()
			local rect = home.game_type_dropdown_scroll_rect(w, h, 1)
			return rect.x + 5, rect.y + 5
		end
	end)

	it("wheel over dropdown changes page", function()
		love.wheelmoved(0, -1)
		local page = helper.get_upvalue(love.wheelmoved, "dropdown_page")
		assert.are.equal(2, page)
	end)

	it("wheel outside dropdown does nothing", function()
		love.mouse.getPosition = function()
			return 10, 10
		end
		love.wheelmoved(0, -1)
		local page = helper.get_upvalue(love.wheelmoved, "dropdown_page")
		assert.are.equal(1, page)
	end)

	it("wheel paging clamps to first and last page", function()
		love.wheelmoved(0, 1)
		local page = helper.get_upvalue(love.wheelmoved, "dropdown_page")
		assert.are.equal(1, page)
		local last_page = math.ceil(#game_types.get_all_types() / 6)
		helper.set_upvalue(love.wheelmoved, "dropdown_page", last_page)
		love.mouse.getPosition = function()
			local rect = home.game_type_dropdown_scroll_rect(w, h, last_page)
			return rect.x + 5, rect.y + 5
		end
		love.wheelmoved(0, -1)
		page = helper.get_upvalue(love.wheelmoved, "dropdown_page")
		assert.are.equal(last_page, page)
	end)

	it("selection flow remains correct after wheel page change", function()
		love.wheelmoved(0, -1)
		local page = helper.get_upvalue(love.wheelmoved, "dropdown_page")
		helper.set_upvalue(love.mousepressed, "dropdown_page", page)
		local x, y = option_center(1)
		love.mousepressed(x, y, 1)
		local selected = helper.get_upvalue(love.mousepressed, "selected_game_type")
		local step = helper.get_upvalue(love.mousepressed, "menu_step")
		local list = game_types.get_all_types()
		assert.are.equal(list[7].id, selected)
		assert.are.equal("match", step)
	end)
end)
