local M = {}

function M.refresh(resources)
	resources.energy_current = resources.energy_max
end

function M.can_spend(resources, amount)
	return amount >= 0 and resources.energy_current >= amount
end

function M.spend(resources, amount)
	if not M.can_spend(resources, amount) then
		return false
	end
	resources.energy_current = resources.energy_current - amount
	return true
end

--- Increase current energy by amount without changing energy_max.
--- @param resources table
--- @param amount number
--- @return nil
function M.gain(resources, amount)
	if amount <= 0 then
		return
	end
	resources.energy_current = math.min(resources.energy_max, resources.energy_current + amount)
end

return M
