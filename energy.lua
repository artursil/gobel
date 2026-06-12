local M = {}

--- @param player table
--- @return nil
local function adopt_resources_energy(player)
	if not player.resources or player.energy == nil then
		return
	end
	if player.resources.energy_current ~= player.energy
		or player.resources.energy_max ~= player.energy_max then
		player.energy = player.resources.energy_current
		player.energy_max = player.resources.energy_max
	end
end

--- @param player table
--- @return nil
local function sync_resources_from_player(player)
	if not player.resources or player.energy == nil then
		return
	end
	player.resources.energy_current = player.energy
	player.resources.energy_max = player.energy_max
end

--- @param player table player state or legacy `{ energy_current, energy_max }`
--- @return number current
--- @return number max
local function energy_values(player)
	if player.energy ~= nil then
		adopt_resources_energy(player)
		return player.energy, player.energy_max
	end
	return player.energy_current, player.energy_max
end

--- @param player table
--- @param current number
--- @param max number|nil
--- @return nil
local function set_energy_values(player, current, max)
	if player.energy ~= nil then
		player.energy = current
		if max ~= nil then
			player.energy_max = max
		end
		sync_resources_from_player(player)
		return
	end
	player.energy_current = current
	if max ~= nil then
		player.energy_max = max
	end
end

--- Restore current energy to max at turn start.
--- @param player table
--- @return nil
function M.refresh(player)
	local _, max = energy_values(player)
	set_energy_values(player, max, max)
end

--- @param player table
--- @param amount number
--- @return boolean
function M.can_spend(player, amount)
	local current = energy_values(player)
	return amount >= 0 and current >= amount
end

--- @param player table
--- @param amount number
--- @return boolean
function M.spend(player, amount)
	if not M.can_spend(player, amount) then
		return false
	end
	local current = energy_values(player)
	set_energy_values(player, current - amount)
	return true
end

--- Increase current energy by amount without changing energy_max.
--- @param player table
--- @param amount number
--- @return nil
function M.gain(player, amount)
	if amount <= 0 then
		return
	end
	local current, max = energy_values(player)
	set_energy_values(player, math.min(max, current + amount))
end

return M
