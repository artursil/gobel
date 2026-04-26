local M = {}

local RECENT_LIMIT = 20

function M.push(message_state, text)
	message_state.queue[#message_state.queue + 1] = text
	message_state.recent[#message_state.recent + 1] = text
	if #message_state.recent > RECENT_LIMIT then
		table.remove(message_state.recent, 1)
	end
end

function M.peek(message_state)
	return message_state.queue[1]
end

function M.pop(message_state)
	if #message_state.queue == 0 then
		return nil
	end
	return table.remove(message_state.queue, 1)
end

function M.clear_queue(message_state)
	message_state.queue = {}
end

return M
