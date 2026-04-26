--- Per-player FIFO of upcoming stone kinds with a visible window of five.

local config = require("config")
local stone_kinds = require("stone_kinds")

local M = {}

local BUFFER_AHEAD = 6

--- Ensures at least n entries exist from the current head.
--- @param pipe table
--- @param n integer
local function ensure(pipe, n)
	while pipe.head + n - 1 > #pipe.list do
		pipe.list[#pipe.list + 1] = stone_kinds.random_incoming()
	end
end

--- Builds a pipeline table for one player.
--- @return table
local function new_pipe()
	local list = {}
	for _ = 1, BUFFER_AHEAD do
		list[#list + 1] = stone_kinds.random_incoming()
	end
	return { head = 1, list = list }
end

--- Attaches incoming queues for both colors to a game table.
--- @param g table
function M.attach(g)
	g.incoming = {
		black = new_pipe(),
		white = new_pipe(),
	}
end

--- Returns the kind that would be placed next for this color.
--- @param g table
--- @param color integer
--- @return integer
function M.peek_next_kind(g, color)
	local pipe = color == config.STONE_BLACK and g.incoming.black or g.incoming.white
	ensure(pipe, 1)
	return pipe.list[pipe.head]
end

--- Returns the next five kinds (may be fewer if buffer exhausted; ensure prevents that).
--- @param g table
--- @param color integer
--- @return table array of five integers
function M.peek_five(g, color)
	local pipe = color == config.STONE_BLACK and g.incoming.black or g.incoming.white
	ensure(pipe, 5)
	local out = {}
	for i = 1, 5 do
		out[i] = pipe.list[pipe.head + i - 1]
	end
	return out
end

--- Consumes one stone kind after a successful placement and extends the buffer.
--- @param g table
--- @param color integer
function M.consume(g, color)
	local pipe = color == config.STONE_BLACK and g.incoming.black or g.incoming.white
	pipe.head = pipe.head + 1
	ensure(pipe, 5)
end

return M
