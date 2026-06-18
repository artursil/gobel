--- Enqueue and drain effect-driven stone removals on ``state.pending_stone_removals``.
--- @module objects.effects_conditions.helpers.shared.pending_removals

local M = {}

--- @class PendingRemovalEntry
--- @field row integer
--- @field col integer
--- @field capturer string|nil ``"black"`` | ``"white"`` side that caused removal
--- @field reason string|nil diagnostic tag (e.g. ``"sacrifice"``, ``"capture_stone_supplemental"``)
--- @field skip_on_removed boolean|nil when true, drain skips ``on_removed`` for this cell (sacrifice)

--- Ensure the pending-removals queue exists on match state.
--- @param state table
--- @return table entries
function M.ensure_queue(state)
	if not state.pending_stone_removals then
		state.pending_stone_removals = {}
	end
	return state.pending_stone_removals
end

--- Append one removal entry to the queue.
--- @param state table
--- @param entry PendingRemovalEntry
--- @return nil
function M.enqueue(state, entry)
	if type(entry) ~= "table" or entry.row == nil or entry.col == nil then
		error("pending removal entry requires row and col")
	end
	local queue = M.ensure_queue(state)
	queue[#queue + 1] = {
		row = entry.row,
		col = entry.col,
		capturer = entry.capturer,
		reason = entry.reason,
		skip_on_removed = entry.skip_on_removed,
	}
end

--- Enqueue a sacrifice self-removal (kamikaze): ``on_removed`` must not run on drain.
--- @param state table
--- @param row integer
--- @param col integer
--- @param opts table|nil ``{ capturer = string, reason = string }``
--- @return nil
function M.enqueue_sacrifice(state, row, col, opts)
	opts = opts or {}
	M.enqueue(state, {
		row = row,
		col = col,
		capturer = opts.capturer,
		reason = opts.reason or "sacrifice",
		skip_on_removed = true,
	})
end

--- Take all queued entries and reset the queue (caller drains cells).
--- @param state table
--- @return PendingRemovalEntry[]
function M.take_all(state)
	local queue = M.ensure_queue(state)
	local out = {}
	for i = 1, #queue do
		out[i] = queue[i]
	end
	state.pending_stone_removals = {}
	return out
end

--- @param state table
--- @return integer
function M.pending_count(state)
	return #(M.ensure_queue(state))
end

return M
