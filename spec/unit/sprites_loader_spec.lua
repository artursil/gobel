local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local sprites = require("ui.sprites")

describe("ui.sprites loader", function()
	before_each(function()
		sprites.clear_cache()
	end)

	it("does not try _r.png variant for stone atlas paths", function()
		local tried = {}
		local original_new_image = love.graphics.newImage
		love.graphics.newImage = function(path)
			tried[#tried + 1] = path
			if path == "sprites/stones/stones.png" then
				return { getWidth = function()
					return 800
				end, getHeight = function()
					return 400
				end }
			end
			error("not found: " .. path)
		end

		local img = sprites.get_image("sprites/stones/stones.png")
		assert.is_not_nil(img)
		assert.are.equal(1, #tried)
		assert.are.equal("sprites/stones/stones.png", tried[1])

		love.graphics.newImage = original_new_image
	end)

	it("still prefers _r.png for card backgrounds", function()
		local tried = {}
		local original_new_image = love.graphics.newImage
		love.graphics.newImage = function(path)
			tried[#tried + 1] = path
			if path == "sprites/cards/background_1_r.png" then
				return { getWidth = function()
					return 10
				end, getHeight = function()
					return 10
				end }
			end
			error("not found")
		end

		local img = sprites.get_image("sprites/cards/background_1_r.png")
		assert.is_not_nil(img)
		assert.are.equal("sprites/cards/background_1_r.png", tried[1])

		love.graphics.newImage = original_new_image
	end)
end)
