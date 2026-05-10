--- Runtime ObjectInstance implementation conforming to single_game/resolver/ObjectInstance.schema.md
--- Mutable runtime entities derived from definitions.
--- @module single_game.resolver.ObjectInstance

local M = {}

--- Create a new ObjectInstance.
--- @param instance_id string: Unique instance ID
--- @param def_id string: Definition ID (e.g., "stone_basic")
--- @param object_type string: "stone" | "card" | "stance" | "temporary_stance"
--- @param owner string: `config.OWNER_BLACK` | `config.OWNER_WHITE` | "run"
--- @param source string: "starter" | "reward" | "shop" | "generated"
--- @param base_properties table: {rarity, probability, defense, cost, tags?, remaining_rounds?}
--- @return table: ObjectInstance
function M.new(instance_id, def_id, object_type, owner, source, base_properties)
	base_properties = base_properties or {}
	return {
		instance_id = instance_id,
		def_id = def_id,
		object_type = object_type,
		tags = base_properties.tags or {},

		owner = owner,
		source = source,

		level = 1,
		max_level = 5,
		experience = 0,

		base = {
			rarity = base_properties.rarity or "common",
			probability = base_properties.probability or 1.0,
			defense = base_properties.defense or 1,
			cost = base_properties.cost or 1,
		},

		mutable = {
			rarity = nil,
			probability = nil,
			defense = nil,
			cost = nil,
		},

		extra_effects = {},
		removed_effect_indexes = {},

		duration = {
			remaining_rounds = base_properties.remaining_rounds,
		},

		status = {
			disabled = false,
			disabled_reason = nil,
			disabled_until_turn = nil,
			disabled_until_game = nil,
			permanent_disable = false,
			uses_left = nil,
			destroyed = false,
			evolve = {
				target_def_id = nil,
				at_turn = nil,
				at_game = nil,
				condition = nil,
			},
		},

		telemetry = {
			total_uses = 0,
			uses_this_game = 0,
			turns_unplayed = 0,
			games_unplayed = 0,
			last_used_turn = nil,
			last_used_game = nil,
		},
	}
end

--- Get effective value (mutable override or base).
--- @param instance table
--- @param property string: "rarity" | "probability" | "defense" | "cost"
--- @return any: Effective property value
function M.get_property(instance, property)
	if instance.mutable[property] ~= nil then
		return instance.mutable[property]
	end
	return instance.base[property]
end

--- Set mutable property override.
--- @param instance table
--- @param property string
--- @param value any
--- @return nil
function M.set_property(instance, property, value)
	instance.mutable[property] = value
end

--- Mark instance as disabled.
--- @param instance table
--- @param reason string: Why disabled
--- @param until_turn integer|nil: Disable until turn (nil = permanent)
--- @param until_game integer|nil: Disable until game (nil = current game only)
--- @return nil
function M.disable(instance, reason, until_turn, until_game)
	instance.status.disabled_reason = reason
	instance.status.disabled_until_turn = until_turn
	instance.status.disabled_until_game = until_game
	if until_turn == nil and until_game == nil then
		instance.status.permanent_disable = true
		instance.status.disabled = true
	end
end

--- Check if instance is disabled.
--- Disabled if:
--- - permanent_disable is true, OR
--- - destroyed is true, OR
--- - Both disabled_until conditions are set and BOTH are satisfied, OR
--- - Exactly one disabled_until condition is set and it's satisfied, OR
--- - disabled flag is true
--- @param instance table
--- @param turn_number integer|nil: Current turn
--- @param game_number integer|nil: Current game
--- @return boolean
function M.is_disabled(instance, turn_number, game_number)
	if instance.status.permanent_disable then
		return true
	end
	if instance.status.destroyed then
		return true
	end
	
	local has_turn_limit = instance.status.disabled_until_turn ~= nil
	local has_game_limit = instance.status.disabled_until_game ~= nil
	
	if has_turn_limit and has_game_limit then
		-- Both limits set: disabled if EITHER limit applies
		local turn_applies = turn_number and turn_number < instance.status.disabled_until_turn
		local game_applies = game_number and game_number < instance.status.disabled_until_game
		if turn_applies or game_applies then
			return true
		end
	elseif has_turn_limit then
		-- Only turn limit: apply it
		if turn_number and turn_number < instance.status.disabled_until_turn then
			return true
		end
	elseif has_game_limit then
		-- Only game limit: apply it
		if game_number and game_number < instance.status.disabled_until_game then
			return true
		end
	end
	
	return instance.status.disabled
end

--- Record usage.
--- @param instance table
--- @param turn_number integer: Current turn
--- @param game_number integer: Current game
--- @return nil
function M.record_use(instance, turn_number, game_number)
	instance.telemetry.total_uses = instance.telemetry.total_uses + 1
	instance.telemetry.uses_this_game = instance.telemetry.uses_this_game + 1
	instance.telemetry.last_used_turn = turn_number
	instance.telemetry.last_used_game = game_number
end

--- Decrement duration by one round.
--- @param instance table
--- @return nil
function M.decrement_duration(instance)
	if instance.duration and instance.duration.remaining_rounds then
		instance.duration.remaining_rounds = instance.duration.remaining_rounds - 1
	end
end

--- Check if instance duration has expired (remaining_rounds <= 0).
--- @param instance table
--- @return boolean
function M.is_expired(instance)
	if not instance.duration or instance.duration.remaining_rounds == nil then
		return false
	end
	return instance.duration.remaining_rounds <= 0
end

return M
