local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local atlas_params = require("objects.parameters.stone_solidity_atlas")
local sprites = require("ui.sprites")

describe("ui.stone_solidity_atlas", function()
	local original_get_image
	local original_new_quad

	before_each(function()
		package.loaded["ui.stone_solidity_atlas"] = nil
		sprites.clear_cache(atlas_params.path)
		original_get_image = sprites.get_image
		original_new_quad = love.graphics.newQuad
	end)

	after_each(function()
		sprites.get_image = original_get_image
		love.graphics.newQuad = original_new_quad
		package.loaded["ui.stone_solidity_atlas"] = nil
	end)

	it("returns quad for black and white at each tier when atlas loads", function()
		local fake_image = {
			getWidth = function()
				return 800
			end,
			getHeight = function()
				return 400
			end,
		}
		sprites.get_image = function(path)
			if path == atlas_params.path then
				return fake_image
			end
			return false
		end
		love.graphics.newQuad = function(x, y, w, h, iw, ih)
			return {
				getViewport = function()
					return x, y, w, h
				end,
				_x = x,
				_y = y,
				_w = w,
				_h = h,
				_iw = iw,
				_ih = ih,
			}
		end

		local atlas = require("ui.stone_solidity_atlas")
		for _, side in ipairs({ "black", "white" }) do
			for tier = 0, 3 do
				local img, quad = atlas.get_frame(side, tier)
				assert.are.equal(fake_image, img)
				assert.is_not_nil(quad)
				local rect = atlas_params.frames[side][tier + 1]
				local qx, qy, qw, qh = quad:getViewport()
				assert.are.equal(rect.x, qx)
				assert.are.equal(rect.y, qy)
				assert.are.equal(rect.w, qw)
				assert.are.equal(rect.h, qh)
			end
		end
	end)

	it("returns nil when image missing", function()
		sprites.get_image = function()
			return false
		end
		local atlas = require("ui.stone_solidity_atlas")
		assert.is_false(atlas.is_available())
		local img, quad = atlas.get_frame("black", 0)
		assert.is_nil(img)
		assert.is_nil(quad)
	end)
end)
