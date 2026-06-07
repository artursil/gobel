1. white stones always should be setup as W.
2. We shouldn't use hardcoded values in tests but have them calculated based on parameters not hardcoded values
3. I want at least 10 different tests per stone, and they should really be unique.
4. tax stone doesn't work as expected. we should check if tax_stone is a part of enclosure, if yes then we count how many enemy stones are in this enclosure and for each enemy stone. we should test multiple type of enclosures, if enclosure in enclosure we stop getting money and points. we need in tests check the state in multiple round. we need more tests
5. territory_to_points_stone - nothing is properly tested here, testing it on empty board makes no sense. having 2 tests for a stone is a joke. If we have a stone that influence boards each turn having it tested only for one turn is also a joke. what if the stone gets blocked, what if it gets captured etc? what if we have more territory stones etc.
6. same for territory_to_multiplier_stone


/grill-me Previously defined mds\STONES_IMPLEMENTATION_ENTRY.md has a lot of issues. I added comments "Comment: " to show what I would change. One other things is totall misunderstanding of what visual tests, are. Visual tests are tests that are in visual directory and visually
    presents the board in ASCII format. I would like to unify tests and visual tests into one field in this document and be way more verbose what we are testing, it should specify initial state, what is the action, what we assert and maybe if necessary specify the whole chain of
    actions. I want you to firstly reach an understanding with you so we can later create a plan of making this document better.



## tax_stone
- missing enclosures from wall to wall
- missing enclosures within enclosures
- "tax_stone scenario 6: captured tax stone pays nothing that turn" you can safely replace with another test
- "tax_stone scenario 5: nested enclosure pays inner enemies once only" - you can safely replace with another test


	it("keeps board fixture #12 complex mix", function()
		local b = helper.parse_board_ascii({
			"B . W . B . . . .",
			"W B . B . B . . .",
			"W W B . W W B . .",
			"W . W . . B . B .",
			"B . W . . W . . B",
			"W B B W W . . B .",
			". . W B W W B . .",
			"W W . B B B . B W",
			". W W . B . . W .",
		})
		local tiles = helper.new_tiles()
		local regions = enclosure.detect_regions_and_ownership(b, tiles)
		helper.debug_dump_regions("fixture1q", b, regions, tiles)

		assert_expected_ownership_ascii(b, regions, tiles, {
			"B b W b B b b b b",
			"W B b B . B b b b",
			"W W B . W W B b b",
			"W w W . . B . B b",
			"B w W . . W . . B",
			"W B B W W . . B b",
			". . W B W W B b b",
			"W W b B B B b B W",
			"w W W b B b b W w",
		})
	end)



/visual-tests for 02_points_stone clean the file, remove unused functions and stones.
this stone is rather easy to test so just use different boards, you can copy previous once and make sure that only recently placed stone scores, I don't think we need 10 tests here.


/visual-tests for 03_influence_stone_spec clean the file, remove unused functions and stones.
Tests for this stone are totally useless. They lack understanding how territory works, they need to be rewritten from scratch. We should take existings complex boards from other tests and modify them for this stone


/visual-tests for 04_tower_stone_spec clean the file, remove unused functions and stones.
Tests for this stone are mostly wrong. This is not how the territory value is calculated, Some boards are wrong. We should also assert scores before and after tower_stone. And why the hell there are 2 tower parameters, use only one no "OR"s.


/visual-tests for 05_energy_stone_spec clean the file, remove unused functions and stones.
Test for this stones have a lot of errors, energy stone is defined twice, multiple rounds tests don't make sense in general those tests are not very good and should be rewritten from scratch.
Remove "OR"s when using parameter values


/visual-tests for 06_x_stone_spec, 07_plus_stone_spec, 26_wall_spec just clean the files, remove unused functions and stones, don't touch tests themselves.
Remove "OR"s when using parameter values


/visual-tests for 08_diagonal_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are useless not in a single one we test actual diagonal lines, they need to be rewritten and please use more interesting boards from other tests. and remove all those "OR" parameters there should be only one parameter used in each case.


/visual-tests for 09_line_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but please confirm their validity and remove all those "OR" parameters there should be only one parameter used in each case.

/visual-tests for 10_kamikaze_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but please confirm their validity as far as I can see.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow

/visual-tests for 11_enclosure_stone_spec clean the file, remove unused functions and stones.
Some tests are fine, but asserts for scores are mostly missing and we lack interesting cases of enclosure that exist in other tests, it seems to me that those tests were written lacking fur understanding how the enclosures work.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow

/visual-tests for 12_control_stone_spec clean the file, remove unused functions and stones.
Those tests are mostly uselsess, there is complete lack of understanding of how territory is calculated - please read the rules. We need to rewrite those tests so they have interesting territory assignments in the set_board and then show how control stone changes the final assignment.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow


/visual-tests for 13_blockade_stone_spec clean the file, remove unused functions and stones.
Those tests are mostly uselsess, there is complete lack of understanding of how how this stone, should work, we should assert if the opponent is capable of placing a stone in certain field, if we are capable of it and how it changes after several rounds, we also need more interesting set boards.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 14_defence_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but more interesting cases are missing, and some tests rely on destroy_odds which are deprecated now, we just have solidity paramteres for each stone.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 15_money_stone_spec clean the file, remove unused functions and stones.
Some tests are fine, but we lack interesting cases of enclosure that exist in other tests, it seems to me that those tests were written lacking fur understanding how the enclosures work. Read enclosure rules, There should be multiple enclosures on board, tests with enclosures within enclosures, opponents enclosure within our enclosure, enclosures using the boundaries of the board etc.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 16_anti_capture_stone_spec clean the file, remove unused functions and stones.
Those tests are mostly uselsess, there is complete lack of understanding of how how this stone should work, we should have actual capture scenarios on the set board and check if opponent is capable of making a move, if we can make a move and also how the board changes after X rounds and if opponent is capable of making a move now.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.


/visual-tests for 17_control_territory_stone_spec clean the file, remove unused functions and stones.
Those tests miss the stone mechanic. Payout depends only on `territory_control_rounds` at the placement cell (see `docs/territory/control-rounds.md`), not enclosure topology. Seed the control grid via `set_territory_control_rounds_ascii` (separate layer from stone board). Assert `plus_mult` delta: own territory `S.mult_control_streak_multiplier * N`, enemy territory negative (floor at 0), `+0` gives nothing. Minimal boards; multi-zone board to prove each cell reads independently. Grid tick rules belong in `spec/unit/territory_control_rounds_spec.lua`, not this visual spec.

Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 18_delay_reward_stone_spec clean the file, remove unused functions and stones.
Those tests are mostly fine but please double check their validity and think about other usecases.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

CUTOFF

/visual-tests for 19_capture_stone_spec clean the file, remove unused functions and stones.
Those tests need to be rewritten, and also the STONES_IMPLEMENTATION_ENTRY needs to be updated in terms of implementation_details. I changed my mind how the capture stone should work. so capture stone should capture a stone if the stone doesn't have any liberties, so the difference between this stone and basic stone is that in this case it doesn't matter by which stones it is surrounded. Also opponent cannot immediately place a stone in the place where it was capture, they have to wait at least one round. The effect of this stone works only on placement. If capture stone affects more than 1 stone, a stone to be captured is selected by random.

In tests there should be examples of multiround scenario, when opponent places a stone in the same place it was previously captured.
Read enclosure rules, There should be multiple enclosures on board, tests with enclosures within enclosures, opponents enclosure within our enclosure, enclosures using the boundaries of the board etc.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 20_tax_stone_spec clean the file, remove unused functions and stones.
Those tests should be adjusted, some are fine, but still feels like lack of full understanding how enclosure works, lack of interesting boards from other tests. Read enclosure rules, There should be multiple enclosures on board, tests with enclosures within enclosures, opponents enclosure within our enclosure, enclosures using the boundaries of the board etc.

Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 21_self_destruct_timed_stone_spec clean the file, remove unused functions and stones.
Those tests are mostly fine but please double check their validity and think about other usecases.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.


CUTOFF

/visual-tests for 22_territory_to_points_stone_spec clean the file, remove unused functions and stones.
Here is a clear lack of understanding how territory assignment works, even when tests are interesting asserts are simply wrong.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 23_territory_to_multiplier_stone_spec clean the file, remove unused functions and stones.
Here is a clear lack of understanding how territory assignment works, even when tests are interesting asserts are simply wrong.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 24_territory_to_multiplier_stone_spec clean the file, remove unused functions and stones.
Here is a clear lack of understanding how territory assignment works, even when tests are interesting asserts are simply wrong. Read first how territory assignment works.
Remove "OR"s when using parameter values
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.


/visual-tests for 25_escalating_points_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but please confirm their validity and remove all those "OR" parameters there should be only one parameter used in each case.
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 25_escalating_money_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but please confirm their validity and remove all those "OR" parameters there should be only one parameter used in each case.
We don't want to define new functions for checking values. We should use parametrized value directly in the test. If we want to check the delta we simply before assert should create a variable local expected_delta = S.<parameter_name> * N, where N is value that makes sense for the test. This will make the tests way easier to follow. There is no limit of number of tests.

/visual-tests for 25_escalating_money_stone_spec clean the file, remove unused functions and stones.
Mostly those tests are fine, but please confirm their validity and remove all those "OR" parameters there should be only one parameter used in each case.
/visual-tests for 09_line_stone_spec clean the file, remove unused functions and stones.



Mostly those tests are fine, but please confirm their validity and remove all those "OR" parameters there should be only one parameter used in each case.
Remove "OR"s when using parameter values