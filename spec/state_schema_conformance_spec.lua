require("spec.test_helper")

local run_state = require("single_run.run_state")
local game_state = require("single_game.game_state")
local player_game_state = require("single_game.player_game_state")
local ObjectInstance = require("single_game.resolver.ObjectInstance")

describe("T-201 state construction and schema conformance", function()
	it("creates valid run_state with all required fields", function()
		local rs = run_state.new("run123", 42)

		assert.is_not_nil(rs.meta)
		assert.are.equal("run123", rs.meta.run_id)
		assert.is_not_nil(rs.seed)
		assert.is_not_nil(rs.progression)
		assert.is_not_nil(rs.resources)
		assert.is_not_nil(rs.inventory)
		assert.is_not_nil(rs.instance_store)
		assert.is_not_nil(rs.destroyed)
		assert.is_not_nil(rs.disabled)
		assert.is_not_nil(rs.probability_modifiers)
		assert.is_not_nil(rs.history)
		assert.is_not_nil(rs.pending_effects)
	end)

	it("creates valid game_state with all required fields", function()
		local gs = game_state.new("game456", 1)

		assert.is_not_nil(gs.meta)
		assert.are.equal("game456", gs.meta.game_id)
		assert.are.equal(1, gs.meta.game_index)
		assert.is_not_nil(gs.board)
		assert.is_not_nil(gs.players)
		assert.is_not_nil(gs.turn)
		assert.is_not_nil(gs.scores)
		assert.is_not_nil(gs.effects)
		assert.is_not_nil(gs.runtime)
	end)

	it("creates valid player_game_state", function()
		local pgs = player_game_state.new("A")

		assert.are.equal("A", pgs.owner)
		assert.is_not_nil(pgs.resources)
		assert.is_not_nil(pgs.limits)
		assert.is_not_nil(pgs.card_zones)
		assert.is_not_nil(pgs.stone_zones)
		assert.is_not_nil(pgs.stances)
		assert.is_not_nil(pgs.counters)
	end)

	it("initializes both players in game_state", function()
		local gs = game_state.new("game1", 1)

		assert.is_not_nil(gs.players.A)
		assert.is_not_nil(gs.players.B)
		assert.are.equal("A", gs.players.A.owner)
		assert.are.equal("B", gs.players.B.owner)
	end)

	it("creates valid ObjectInstance", function()
		local inst = ObjectInstance.new(
			"inst_1",
			"stone_basic",
			"stone",
			"A",
			"starter",
			{ rarity = "common", cost = 1 }
		)

		assert.are.equal("inst_1", inst.instance_id)
		assert.are.equal("stone_basic", inst.def_id)
		assert.are.equal("stone", inst.object_type)
		assert.are.equal("A", inst.owner)
		assert.are.equal("starter", inst.source)
		assert.are.equal("common", inst.base.rarity)
		assert.are.equal(1, inst.level)
		assert.is_false(inst.status.disabled)
		assert.is_false(inst.status.destroyed)
	end)

	it("stores and retrieves instances", function()
		local rs = run_state.new("run1", 42)
		local inst = ObjectInstance.new("inst_1", "stone_basic", "stone", "A", "starter", {})

		run_state.store_instance(rs, inst)
		local retrieved = run_state.get_instance(rs, "inst_1")

		assert.are.equal("inst_1", retrieved.instance_id)
	end)

	it("tracks zone membership", function()
		local pgs = player_game_state.new("A")

		player_game_state.add_to_zone(pgs, "card_zones.hand", "card_1")
		assert.are.equal(1, #pgs.card_zones.hand.instance_ids)

		player_game_state.add_to_zone(pgs, "card_zones.hand", "card_2")
		assert.are.equal(2, #pgs.card_zones.hand.instance_ids)
	end)

	it("removes instance from zone", function()
		local pgs = player_game_state.new("A")

		player_game_state.add_to_zone(pgs, "card_zones.hand", "card_1")
		player_game_state.add_to_zone(pgs, "card_zones.hand", "card_2")
		assert.are.equal(2, #pgs.card_zones.hand.instance_ids)

		local removed = player_game_state.remove_from_zone(pgs, "card_zones.hand", "card_1")
		assert.is_true(removed)
		assert.are.equal(1, #pgs.card_zones.hand.instance_ids)
	end)

	it("ObjectInstance property access uses mutable overrides", function()
		local inst = ObjectInstance.new("inst_1", "stone_basic", "stone", "A", "starter", {
			rarity = "common",
			cost = 1,
		})

		assert.are.equal("common", ObjectInstance.get_property(inst, "rarity"))

		ObjectInstance.set_property(inst, "rarity", "rare")
		assert.are.equal("rare", ObjectInstance.get_property(inst, "rarity"))
	end)

	it("ObjectInstance disable tracking", function()
		local inst = ObjectInstance.new("inst_1", "stone_basic", "stone", "A", "starter", {})

		assert.is_false(ObjectInstance.is_disabled(inst, 5, 3))

		ObjectInstance.disable(inst, "testing", 7, 4)
		-- disabled until turn 7, game 4 means it's disabled when turn/game are BEFORE 7/4
		assert.is_true(ObjectInstance.is_disabled(inst, 5, 3))
		assert.is_true(ObjectInstance.is_disabled(inst, 6, 4))
		assert.is_false(ObjectInstance.is_disabled(inst, 7, 4))
		assert.is_false(ObjectInstance.is_disabled(inst, 8, 5))
	end)
end)
