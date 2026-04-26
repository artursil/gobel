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

return M
