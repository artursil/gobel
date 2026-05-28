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
		package.loaded["objects.parameters.stone_solidity_atlas"] = nil
		require("objects.parameters.stone_solidity_atlas")
	end)

	local function stub_atlas(iw, ih)
		local fake_image = {
			getWidth = function()
				return iw
			end,
			getHeight = function()
				return ih
			end,
		}
		sprites.get_image = function(path)
			if path == atlas_params.path then
				return fake_image
			end
			return false
		end
		love.graphics.newQuad = function(x, y, w, h, img_w, img_h)
			return {
				getViewport = function()
					return x, y, w, h
				end,
				_x = x,
				_y = y,
				_w = w,
				_h = h,
				_iw = img_w,
				_ih = img_h,
			}
		end
		return fake_image
	end

	it("uses manual frames from parameters when they fit the image", function()
		stub_atlas(1600, 900)
		local atlas = require("ui.stone_solidity_atlas")
		for _, side in ipairs({ "black", "white" }) do
			for tier = 0, 3 do
				local _, quad = atlas.get_frame(side, tier)
				local expected = atlas_params.frames[side][tier + 1]
				local qx, qy, qw, qh = quad:getViewport()
				assert.are.equal(expected.x, qx)
				assert.are.equal(expected.y, qy)
				assert.are.equal(expected.w, qw)
				assert.are.equal(expected.h, qh)
			end
		end
	end)

	it("grid fallback places black row below white on tall sheets when frames omitted", function()
		package.loaded["objects.parameters.stone_solidity_atlas"] = {
			path = atlas_params.path,
			cols = 4,
			row_white = 0,
			row_black = 1,
			inset = 2,
		}
		package.loaded["ui.stone_solidity_atlas"] = nil
		stub_atlas(800, 800)
		local atlas = require("ui.stone_solidity_atlas")
		local _, white_quad = atlas.get_frame("white", 0)
		local _, black_quad = atlas.get_frame("black", 0)
		local _, wy, _, wh = white_quad:getViewport()
		local _, by = black_quad:getViewport()
		assert.is_true(by >= wy + wh - 1, "black row must start below the white row")
	end)

	it("falls back to grid for a tier when manual rect is out of bounds", function()
		local atlas = require("ui.stone_solidity_atlas")
		local manual_white = atlas.frame_rect("white", 0, 1600, 900)
		local grid_black = atlas.frame_rect("black", 0, 1600, 200)
		assert.are.equal(atlas_params.frames.white[1].x, manual_white.x)
		local expected_black = atlas.grid_frame_rect(1600, 200, atlas_params.row_black or 1, 0)
		assert.are.equal(expected_black.x, grid_black.x)
		assert.are.equal(expected_black.y, grid_black.y)
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
