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

local function new_tiles()
	local tiles = {}
	for r = 1, config.BOARD_SIZE do
		tiles[r] = {}
		for c = 1, config.BOARD_SIZE do
			tiles[r][c] = {
				influence = { A = 0, B = 0 },
				region_id = nil,
				override_owner = nil,
				owner = nil,
			}
		end
	end
	return tiles
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

local function regions_ascii(b, regions, tiles)
	local lines = {}
	for r = 1, config.BOARD_SIZE do
		local row = {}
		for c = 1, config.BOARD_SIZE do
			if not board.is_empty(b[r][c]) then
				row[#row + 1] = board.chain_color(b[r][c]) == config.STONE_BLACK and "A" or "B"
			else
				local rid = tiles[r][c].region_id
				local owner = rid and regions[rid] and regions[rid].owner or nil
				if owner == "A" then
					row[#row + 1] = "a"
				elseif owner == "B" then
					row[#row + 1] = "b"
				else
					row[#row + 1] = "."
				end
			end
		end
		lines[#lines + 1] = table.concat(row, " ")
	end
	return table.concat(lines, "\n")
end

local function debug_dump(name, b, regions, tiles)
	if not DEBUG_INTEGRATION then
		return
	end
	print("")
	print("[INTEGRATION_DEBUG] " .. name .. " initial board")
	print(board_ascii(b))
	print("[INTEGRATION_DEBUG] " .. name .. " region ownership")
	print(regions_ascii(b, regions, tiles))
end

local function assert_expected_ownership_ascii(b, regions, tiles, expected_rows)
	local expected = table.concat(expected_rows, "\n")
	local actual = regions_ascii(b, regions, tiles)
	assert.are.equal(expected, actual)
end

describe("Enclosure integration (detect_regions_and_ownership)", function()
	it("claims a fully enclosed center point for black", function()
		local b = board.new()
		for r = 4, 6 do
			for c = 4, 6 do
				if not (r == 5 and c == 5) then
					place_stone(b, r, c, config.STONE_BLACK)
				end
			end
		end

		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("black_center_enclosure", b, regions, tiles)

		local enclosed_region_count = 0
		for _, region in pairs(regions) do
			if region.owner == "A" then
				enclosed_region_count = enclosed_region_count + 1
			end
		end

		assert.is_true(enclosed_region_count >= 1)
		local center_region_id = tiles[5][5].region_id
		assert.is_true(center_region_id ~= nil)
		assert.are.equal("A", regions[center_region_id].owner)
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . A A A . . .",
			". . . A a A . . .",
			". . . A A A . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("does not claim center when enclosure boundary is mixed", function()
		local b = board.new()
		for r = 4, 6 do
			for c = 4, 6 do
				if not (r == 5 and c == 5) then
					place_stone(b, r, c, config.STONE_BLACK)
				end
			end
		end
		place_stone(b, 4, 4, config.STONE_WHITE)

		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("mixed_boundary_center", b, regions, tiles)

		local center_region_id = tiles[5][5].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B A A . . .",
			". . . A a A . . .",
			". . . A A A . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps edge-connected region unowned by enclosure", function()
		local b = board.new()
		place_stone(b, 2, 2, config.STONE_BLACK)
		place_stone(b, 2, 3, config.STONE_BLACK)
		place_stone(b, 2, 4, config.STONE_BLACK)
		place_stone(b, 1, 4, config.STONE_BLACK)

		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("edge_connected_region", b, regions, tiles)

		local edge_region_id = tiles[1][2].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . A . . . . .",
			". A A A . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #1 center region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B . . . . .",
			". . B A B B . . .",
			". . . B . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_1", b, regions, tiles)

		local center_region_id = tiles[5][5].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B . . . . .",
			". . B A B B . . .",
			". . . B b B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #2 sampled empty region unowned", function()
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
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_2", b, regions, tiles)

		local probe_region_id = tiles[2][5].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			"a a a A b b b B .",
			"A A A A b b B . .",
			"b b b b b B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #3 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . B .",
			"A A A A . . B . .",
			". . . . . B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_3", b, regions, tiles)

		local probe_region_id = tiles[2][5].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			"b b b b b b b B .",
			"A A A A b b B . .",
			"b b b b b B . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
	end)

	it("keeps board fixture #4 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . A . . . B .",
			"A A A A . . B . .",
			". . . . . B . . A",
			"B B B B B . . A .",
			". . . . . . A . .",
			". . . . . A . . .",
			". . . . . A . . .",
			". . . . . A . . .",
			". . . . . A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_4", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			"a a a A b b b B .",
			"A A A A b b B . .",
			"b b b b b B . . A",
			"B B B B B . . A a",
			". . . . . . A a a",
			". . . . . A a a a",
			". . . . . A a a a",
			". . . . . A a a a",
			". . . . . A a a a",
		})
	end)
	it("keeps board fixture #5 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . A . . . . .",
			"B B B . . . . . .",
			". A . B . . . . .",
			". A A B . . . . .",
			". . . B . . . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_5", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . A . .",
			". . . . . . . . .",
			". . . A . . . . .",
			"B B B . . . . . .",
			"b A b B . . . . .",
			"b A A B . . . . .",
			"b b b B . . . . .",
		})
	end)
	it("keeps board fixture #6 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". A A A . . . . .",
			"B B B B A . . . .",
			". A . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_6", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". A A A . . . . .",
			"B B B B A . . . .",
			"b A b b B A . . .",
			"b b b b B A . . .",
			"b b b b B A . . .",
			"b b b b B A . . .",
		})
	end)
	it("keeps board fixture #7 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". A A A . . . . .",
			"B B B B A . . . .",
			". A . . B A . . .",
			". . A . B A . . .",
			". . . A B A . . .",
			". . . . B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_7", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". A A A . . . . .",
			"B B B B A . . . .",
			"b A b b B A . . .",
			"b b A b B A . . .",
			"b b b A B A . . .",
			"b b b b B A . . .",
		})
	end)
	it("keeps board fixture #8 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B B B B A . . . .",
			". A . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_8", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B B B B A . . . .",
			"b A b b B A . . .",
			"b b b b B A . . .",
			"b b b b B A . . .",
			"b b b b B A . . .",
		})
	end)
	it("keeps board fixture #9 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B A B B A . . . .",
			". A . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_9", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B A B B A . . . .",
			"a A a a B A . . .",
			"a a a a B A . . .",
			"a a a a B A . . .",
			"a a a a B A . . .",
		})
	end)
	it("keeps board fixture #95 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A A A . . .",
			"B A B B . A . . .",
			". A . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
			". . . . B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture_95", b, regions, tiles)

		local probe_region_id = tiles[4][6].region_id
		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A A A . . .",
			"B A B B a A . . .",
			"a A a a B A . . .",
			"a a a a B A . . .",
			"a a a a B A . . .",
			"a a a a B A . . .",
		})
	end)
	it("keeps board fixture #10 sampled empty region unowned", function()
		local b = parse_board_ascii({
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B A B B A . . . .",
			". A . . B A . . .",
			". . . . B A . . .",
			". A A A B A . . .",
			". A . A B A . . .",
		})
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture10", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B A B B A . . . .",
			"a A a a B A . . .",
			"a a a a B A . . .",
			"a A A A B A . . .",
			"a A a A B A . . .",
		})
	end)
	it("keeps board fixture #11 sampled empty region unowned", function()
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
		local tiles = new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		debug_dump("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			"A A A A . . . . .",
			"B B B B A . . . .",
			"b A b b B A . . .",
			"A b b b B A . . .",
			"a A A A B A . . .",
			"a A a A B A . . .",
		})
	end)
end)
