local board = require("board")
local config = require("config")
local enclosure = require("resolver.enclosure")

local DEBUG_INTEGRATION = os.getenv("INTEGRATION_DEBUG") == "1"

local function place_stone(b, row, col, color)
	b[row][col] = board.make_stone(color, "stone_basic")
end

local function parse_board_ascii(rows)
	local b = board.new()
	for r = 1, #rows do
		local c = 1
		for token in string.gmatch(rows[r], "%S+") do
			if token == "A" then
				place_stone(b, r, c, config.STONE_BLACK)
			elseif token == "B" then
				place_stone(b, r, c, config.STONE_WHITE)
			end
			c = c + 1
		end
	end
	return b
end

local function board_ascii(b)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			local cell = b[r][c]
			if board.is_empty(cell) then
				row[#row + 1] = "."
			elseif cell.color == config.STONE_BLACK then
				row[#row + 1] = "A"
			else
				row[#row + 1] = "B"
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function walls_ascii(_b, n, wall)
	local boundary = {}
	for i = 1, #(wall.boundary_fields or {}) do
		local p = wall.boundary_fields[i]
		boundary[p[1] * 100 + p[2]] = true
	end
	local inside = {}
	for i = 1, #(wall.inside_fields or {}) do
		local p = wall.inside_fields[i]
		inside[p[1] * 100 + p[2]] = true
	end
	local boundary_mark = wall.owner == "A" and "A" or "B"
	local inside_mark = wall.owner == "A" and "a" or "b"

	local lines = {}
	for r = 1, n do
		local row = {}
		for c = 1, n do
			local key = r * 100 + c
			if boundary[key] then
				row[#row + 1] = boundary_mark
			elseif inside[key] then
				row[#row + 1] = inside_mark
			else
				row[#row + 1] = "."
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function debug_dump(name, b, wall_ascii)
	if not DEBUG_INTEGRATION then
		return
	end
	print("")
	print("[INTEGRATION_DEBUG] " .. name .. " initial board")
	print(board_ascii(b))
	print("[INTEGRATION_DEBUG] " .. name .. " wall render")
	print(wall_ascii)
end

local function wall_size(wall)
	return #(wall.inside_fields or {}) + #(wall.boundary_fields or {})
end

local function debug_dump_all_walls(name, b, walls)
	if not DEBUG_INTEGRATION then
		return
	end
	print("[INTEGRATION_DEBUG] " .. name .. " found walls: " .. tostring(#walls))
	for i = 1, #walls do
		local wall = walls[i]
		local boundary_count = #(wall.boundary_fields or {})
		local inside_count = #(wall.inside_fields or {})
		print("[INTEGRATION_DEBUG] wall #" .. tostring(i)
			.. " owner=" .. tostring(wall.owner)
			.. " boundary=" .. tostring(boundary_count)
			.. " inside=" .. tostring(inside_count))
		print(walls_ascii(b, config.BOARD_SIZE, wall))
	end
end

describe("Wall detection", function()
	it("extracts and renders biggest wall from sample board", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B . . . .",
			". . B . . B . . .",
			". . B . . B . . .",
			". . . B . B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("biggest_wall", b, actual)
		local expected = table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B . . . .",
			". . B b b B . . .",
			". . B b b B . . .",
			". . . B b B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("extracts and renders biggest wall from sample board", function()
		local b = parse_board_ascii({
			". . . A . . . B .",
			"A A A A . . B . .",
			". . . . . B . . .",
			"B B B B B . . . .",
			". . . B . . . . .",
			"B B B . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("biggest_wall", b, actual)
		local expected = table.concat({
			"b b b b b b b B .",
			"b b b b b b B . .",
			"b b b b b B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("extracts and renders biggest wall from sample board", function()
		local b = parse_board_ascii({
			". . . A . . . B .",
			"A A A A . . B . .",
			". . . . . B B . .",
			"B B B B B B B . .",
			". . . B . B . . .",
			"B B B . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("biggest_wall", b, actual)
		local expected = table.concat({
			"b b b b b b b B .",
			"b b b b b b B . .",
			"b b b b b B B . .",
			"B B B B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("extracts and renders biggest wall from sample board", function()
		local b = parse_board_ascii({
			". . . A . . . B .",
			"A A A A . . B . .",
			". . . . . B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("biggest_wall", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("biggest_wall", b, actual)
		local expected = table.concat({
			"b b b b b b b B .",
			"b b b b b b B . .",
			"b b b b b B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("extracts and renders smallest wall from sample board", function()
		local b = parse_board_ascii({
			". . . A . . . B .",
			"A A A A . . B . .",
			". . . . . B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("smallest_wall", b, walls)

		local smallest = walls[1]

		local actual = walls_ascii(b, config.BOARD_SIZE, smallest)
		debug_dump("smallest_wall", b, actual)
		local expected = table.concat({
			"a a a A . . . . .",
			"A A A A . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)

	it("renders inside including enclosed stones", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . A A A . . . .",
			". . A B A . . . .",
			". . A . A . . . .",
			". . A A A . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("inside_includes_stones", b, actual)
		local expected = table.concat({
			". . . . . . . . .",
			". . A A A . . . .",
			". . A a A . . . .",
			". . A a A . . . .",
			". . A A A . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("renders inside including enclosed stones", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B A A . . .",
			". . . A . A . . .",
			". . . A A A . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("inside_includes_stones", b, actual)
		local expected = table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . A A . . .",
			". . . A a A . . .",
			". . . A A A . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)
	it("renders inside including enclosed stones", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B B B B A . . . .",
			". A . . B A . . .",
			"A . . . B A . . .",
			". A A A B A . . .",
			". A . A B A . . .",
		})

		local walls = enclosure.extract_walls(b)
		assert.is_true(type(walls) == "table")
		assert.is_true(#walls > 0)
		debug_dump_all_walls("inside_includes_stones", b, walls)

		local biggest = walls[1]
		for i = 2, #walls do
			if wall_size(walls[i]) > wall_size(biggest) then
				biggest = walls[i]
			end
		end

		local actual = walls_ascii(b, config.BOARD_SIZE, biggest)
		debug_dump("inside_includes_stones", b, actual)
		local expected = table.concat({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"A A A A . . . . .",
			"a a a a A . . . .",
			"a a a a a A . . .",
			"a a a a a A . . .",
			"a a a a a A . . .",
			"a a a a a A . . .",
		}, "\n")

		assert.are.equal(expected, actual)
	end)

end)
