--- Thin synergy helpers for card/stance scoring (no placement logic).
--- @module ai.heuristics.synergy

local content = require("content")

local M = {}

--- @param view table
--- @return integer
function M.count_steel_in_hand(view)
	local ids = view:hand_card_ids()
	local count = 0
	for i = 1, #ids do
		local def = content.get_card(ids[i])
		if def and def.tags then
			for j = 1, #def.tags do
				if def.tags[j] == "steel" then
					count = count + 1
					break
				end
			end
		end
	end
	return count
end

--- @param view table
--- @param def_id string
--- @return boolean
function M.has_stance(view, def_id)
	local stances = view:stances()
	for _, list in pairs(stances) do
		for i = 1, #list do
			local entry = list[i]
			if entry and (entry.id == def_id or entry.stance_id == def_id) then
				return true
			end
		end
	end
	return false
end

--- @param view table
--- @return string[]
function M.active_stance_def_ids(view)
	local out = {}
	local seen = {}
	local stances = view:stances()
	for _, list in pairs(stances) do
		for i = 1, #list do
			local entry = list[i]
			local id = entry and (entry.id or entry.stance_id)
			if id and not seen[id] then
				seen[id] = true
				out[#out + 1] = id
			end
		end
	end
	return out
end

return M
