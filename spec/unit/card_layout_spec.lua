require("spec.test_helper")

local card_geometry = require("ui.card_geometry")
local layout_mod = require("layout")

describe("card layout", function()
	it("image_draw_dest fills bounds when image is 1024x1435", function()
		local dx, dy, dw, dh = card_geometry.image_draw_dest({ x = 0, y = 0, w = 125, h = 175 }, 1024, 1435)
		assert.is_true(math.abs(dw - 125) < 1)
		assert.is_true(math.abs(dh - 175) < 2)
		assert.are.equal(0, dx)
		assert.are.equal(0, dy)
	end)

	it("hand_fan_slots preserve 2.5 x 3.5 aspect", function()
		local layout = layout_mod.from_window(1280, 720)
		local slots = layout_mod.hand_fan_slots(layout, 4)
		for i = 1, #slots do
			local ratio = slots[i].w / slots[i].h
			assert.is_true(math.abs(ratio - card_geometry.WIDTH_TO_HEIGHT) < 0.02)
		end
	end)

	it("hand_fan_slots stay inside hand_panel and collapse for large hands", function()
		local layout = layout_mod.from_window(1280, 720)
		local panel = layout.hand_panel
		local slots = layout_mod.hand_fan_slots(layout, 120)
		assert.are.equal(120, #slots)
		local last = slots[#slots]
		assert.is_true(slots[1].x >= panel.x)
		assert.is_true(last.x + last.w <= panel.x + panel.w)
		assert.is_true(slots[2].x - slots[1].x < slots[1].w)
	end)
end)
