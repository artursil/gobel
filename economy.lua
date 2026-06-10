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

--- Subtracts money and clamps the balance at zero.
--- @param resources table
--- @param amount number
--- @return boolean
function M.deduct_clamped(resources, amount)
	if amount <= 0 then
		return true
	end
	resources.money = math.max(0, (resources.money or 0) - amount)
	return true
end

--- Applies a full capture penalty, allowing negative balances.
--- @param resources table
--- @param amount number
--- @return boolean
function M.deduct_penalty(resources, amount)
	if amount <= 0 then
		return true
	end
	resources.money = (resources.money or 0) - amount
	return true
end

return M
