local M = {}

function M.get(resources)
	return resources.money
end

function M.can_spend(resources, amount)
	return amount >= 0 and resources.money >= amount
end

function M.gain(resources, amount)
	if amount < 0 then
		return false
	end
	resources.money = resources.money + amount
	return true
end

function M.spend(resources, amount)
	if not M.can_spend(resources, amount) then
		return false
	end
	resources.money = resources.money - amount
	return true
end

return M
