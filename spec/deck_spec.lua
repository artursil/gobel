require("spec.test_helper")

local deck = require("deck")

local function rng_always_one(_max_value)
	return 1
end

describe("T-013 deck", function()
	it("draws to hand target from deck", function()
		local cards = deck.new({ "a", "b", "c" }, 2, rng_always_one)
		deck.draw_to_hand_target(cards, rng_always_one)
		assert.are.equal(2, #cards.hand.ids)
		assert.are.equal(1, #cards.deck.ids)
	end)

	it("reshuffles discard into deck when drawing from empty deck", function()
		local cards = {
			deck = { ids = {} },
			hand = { ids = {} },
			discard = { ids = { "x", "y" } },
			hand_target_size = 1,
		}
		local drawn = deck.draw_one(cards, rng_always_one)
		assert.are.equal("x", drawn)
		assert.are.same({}, cards.discard.ids)
		assert.are.same({ "x" }, cards.hand.ids)
		assert.are.same({ "y" }, cards.deck.ids)
	end)

	it("stops draw when deck and discard are empty", function()
		local cards = {
			deck = { ids = {} },
			hand = { ids = {} },
			discard = { ids = {} },
			hand_target_size = 3,
		}
		deck.draw_to_hand_target(cards, rng_always_one)
		assert.are.same({}, cards.hand.ids)
	end)

	it("plays card from hand into discard", function()
		local cards = {
			deck = { ids = {} },
			hand = { ids = { "c1", "c2" } },
			discard = { ids = {} },
			hand_target_size = 5,
		}
		local played = deck.play_from_hand(cards, 1)
		assert.are.equal("c1", played)
		assert.are.same({ "c2" }, cards.hand.ids)
		assert.are.same({ "c1" }, cards.discard.ids)
	end)

	it("rejects invalid hand index without mutation", function()
		local cards = {
			deck = { ids = {} },
			hand = { ids = { "c1" } },
			discard = { ids = {} },
			hand_target_size = 5,
		}
		local played = deck.play_from_hand(cards, 0)
		assert.is_nil(played)
		assert.are.same({ "c1" }, cards.hand.ids)
		assert.are.same({}, cards.discard.ids)
	end)
end)
