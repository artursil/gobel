local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local ui_fonts = require("ui.fonts")
ui_fonts.init()

local stance_detail_popup = require("ui.stance_detail_popup")

describe("stance_detail_popup", function()
	it("places popup beside anchor and keeps it on screen", function()
		local anchor = { x = 100, y = 200, w = 80, h = 112 }
		local box = stance_detail_popup.layout(anchor, "Echo", "Copy the stance to the right.", 1280, 720)
		assert.is_true(box.x + box.w <= 1280)
		assert.is_true(box.y + box.h <= 720)
		assert.are.equal("Echo", box.title)
		assert.is_true(box.title_box.w < box.desc_box.w + 40)
		assert.are.equal(box.x + math.floor((box.w - box.title_box.w) * 0.5), box.title_box.x)
	end)

	it("contains detects clicks inside outer golden box", function()
		local box = { x = 50, y = 60, w = 200, h = 120 }
		assert.is_true(stance_detail_popup.contains(box, 100, 90))
		assert.is_false(stance_detail_popup.contains(box, 10, 10))
	end)
end)
