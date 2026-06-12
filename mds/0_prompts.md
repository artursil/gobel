I need a couple of changes regarding the implementation of AI.

1. rename the placement_terms to stoens_heuristics_def. I want to clearly now where to look for definition of all heursitics for stones placement.
2. each heuristic should have a weight assigned to it in a clear way. I should be able to a look at the file with all separate heuristics defined and I should immediately by lookint at the file understand what heurstic stands for and what is it's weight.

3. The other thing I want to adjust is the definition of score. So right now when we run MCTS it is evaluated just based on the possible scores increase, however I think we should also include the heuristics there so when I said that now heuristics should have weights I actually think they should have 2 scores, pre-selection score and selection score. Then pre_selection score is used to select fields to evaluate later in MCTS
4. selection score on other hand we add to the final evaluation score. So basically when we evaluate field (X, Y) we calculate how the score changes for us and our opponent but also we take into account heuristics. This way AI should be able to think more long term and build for some things instead of just looking for the highest score next move
5. Apart from the weight assigned to those heuristics we also should have a list of heuristics being included in the move evaluation. and defualt list  should be defined in global config and then different opponents can priotisize different heuristics

Do those changes make sense to you?


resizing window bug

defence/health
3 new stones
tests + code






POSSIBLE HEURISTIC:
good move if we stop an enclosure





Now I want you to create 2 prompts one for code writer one for test writer.
I want to add 3 stones to the game;
1. x_stone - if is a part of an X on the board gives 2 x_mult, the size of the X on the board matters. it consists of at least 5 stones it is size 1 if it has at least 9 stones forming a big X then it gives another 2x mult and then if it's 3 times the size then another one
2. Plus stone - if is a part of + on the board gives 5 plus_mult, same principal the bigger the plus the bigger the mult
3. Wall stone - all the connected stones to the this stone including the wall stone give +2 points

Heuristics for those stones:
1. if we have an x_stone in hand and we are 2 or less moves away from creating an X give some weight and another heuristic for x_stone if an opponent is 2 moves away or less from creating an X (no matter if he has x_stones) blocking it gives some weight
2. Analogous 2 heuristics for plus_stone as for x_stone
3. For wall we don't need heurstics becuse it will be evaluated during regular scoring




In nutshell those effects for x_stone, plus_stone, and wall_stone can be triggered both by all stones and those specific stones. We need to in the end create 5 effects
1. x_stone - checks for any stone if it belongs to an X on the board and if there is an X_stone in it
2. plus_stone - the same things
3. wall_stone_other - this is for all of the non-wall stones that are added to the wall and then adds points only for this one stone
4. wall_stone - this adds points for all of the stones in the wall including itself
5. shared_stones_effects - this one groups all the effects we use for all of the stones so we don't copy paste the same effects over and over

Animations for those stones:
1. Every time an X is created small or big (sometimes it can be created by none X stones)  all stones creatting an X are moved up and down one  after another and then X2 is displayed over every x_stone inside this X and this is repeated for all newly created Xs
2. For plus_stones similar story
3. For wall if we place wall_stone and the wall is bigger or equal 5 stones we move upon and down every stone connected to the wall_stone and then we display +5 x times depending on the size of the wall


Cal them:
x_stone, plus_stone, wall




Cal them:
x_stone, plus_stone, wall



Ok those are all the things I want to be implemented, please divide those into PRs and prompts for writers.

I want to implement following changes:
1. Firstly we need to focus on playing cards, playing cards should have different playing types, so some we just use, but for some we use them on an object and this has to be clear from the visual standpoint.
2. The types I can think of right now is card that works on an opponent stone, that works on an upgradable our stone or any stone of ours, on other playing cards etc. I think the easiest way is to have it defined by tags, if an object has a tag then we can do it.
3. Then we need clear UI for this, so if the card can be just used (eg. it gives us just points), when we select the card the use button is green.
4. When however we need to firstly select some other cards to use this one it should stay grey.
5. We should have an option to select multiply cards, so whenever we click on card it should pop up and we should be able to do it for multiple cards.
6. When we have a playing card that attacks when we start dragging the card the arrow should appear same as in slay the spire and the arrow should be grey if we are over wrong stone and gold if we are on the right one.
7. To test all of this I would add 3 new cards: attack, heal and get money card. Attack card deals 1 damage on selected enemy, heal card give one solidity back for our attacked stone, money card gives you 1$ when you discard 2 other cards, so basically we firstly need to select 2 other cards to use this one
8. For testing it we need a new game type will all of those card types
9. We need to add an option to scroll through the game types
10. When stone is dealt damage the graphic for it should change depending on the % of the solidity left


I want you to help me adjust agents_workflow to this project needs. This is taken from a public repo that uses typescript and claude code for coordinating agents. I want to use cursor agents and python for similar functionality. So here are things to implement:

prompts:
- test-writer - writes test, specifies what is a good test what is a bad test, how good test doesn't focus on implementation details but tests public interfaces. Code can change entirely; tests shouldn't.
- visual-test-writer - use skill /visual-tests
- code-writer.md - just implements functionality with writing_tests, refactoring or reviewing not like implement-all.md, possibly raises concerns if tests are not correctly written, but NEVER corrects them himself. It should also follow best coding principles.
- delegator - if there is dispute between test-writer and code-writer decides who is right and delegates fixes, has similar responsibilites to a reviewer.

workflows:
- tests_exist.py - In this workflow for a single issue, we ask code-writer to implement a functionality, then we ask delegator to check if the implemenation is correct and if code-writer correctly raises concerns about the tests, visual-test-writer is asked to correct things. This loop runs until delegator has no further remarks or we run the loop already 4 times. If it doesn't finish in 4 attempts it has to be reported, by creating a new issue.

- parallel_tests_exist.py - Planner (or explicit issue list) then parallel tests_exist per issue.
- merge_issues.py - Sequentially merges agent/issue-N branches into an integration branch; closes each issue after its merge; opens a review PR at the end.
- single_feature.py - Acts similar like test_exist.py but here we use test-writer or visual-test-writer to write test first, then code-writer implements then delegator checks everything else is the same.
- parallel_features.py - Same batch pattern as parallel_tests_exist.py but for single_feature (no merge step).


Please take inspiration from run.ts for workflows and from prompts/.md for writing md prompts


- combination of stones
- capture stone
- finish turn / advance_round / complete_full_round




on_removed
CONTEXT
sub macro
lifecycle


This is literally all wrong and should be handled all in apply.
1. on_compile - capture_stone should actually not special effect just in resolver/stages there should be file remove_stones.lua which examines state of the board and removes the stones and gives points for capture. for anti-capture we also don't need a special effect, we need however in state of the game state.recalculate_legal_moves which contains a state of the legal moves on the board and in resolver/stages/legality_of_moves.lua we update this based on the state of the board.
2. resolve_immediate - this should be just in apply with a right phase, we always calculate scores in apply.
3. on_finalize_compile - kamikaze_stone should be removed in remove_stones.lua stage where we remove all stones that don't belong.
4. on_snapshot - totally unnecessary, apply should just in the mult phase assign right number of points, remember that we already store information about territory control look here for the tests -> spec\visual\territory_control_rounds_spec.lua
5. on_placement - apply should start the timer, we don't need it
6. macro/sub - again why do we need it when we already have phases, which determine the order?
7. lifecycle - we don't need it

Debugger:
- change value of territory fields


1. Fix stones PR
    - energy not the state of the game, energy stone doesn't work as it supposed.
    - energy max, after run
2. how counters for stones are updated
3. Debugger.
4. UI
    - UI for controlled territory
    - UI for territory value
5. More stones
    - stone effects when held in hand?
    - gold stones
6. Automatic sprite generation + display of stones.
7. Animations improvements.
8. Animations
9. Heuristics
10. Combination of stones
11. Stone testing
12. Finish all stones.
13. Simulation
14. Tweaking heuristic




1. condition still not used
2. phases enum wrong
3. action enum I don't see X
4. macro still exists X
5. sub still exists X
6. helper_effects vs effect_helpers
7. legacy_action remove
8. dispatch_removed vs remove_stones
9. Condition.lua why removed?



objects
├── animations
├── definitions
├── effects
│   ├── effect_helpers
│   ├── EffectSchema.lua
│   ├── effects.lua
├── conditions
│   ├── condition_helpers
│   ├── ConditionSchema.lua
│   ├── conditions.lua
├── parameters
│   ├── cards.lua
├── definitions
│   ├── cards.lua
├── definitions
│   ├── cards.lua


We are almost there .
1. Object definition is wrong it should look something like this:
		effects = {
			{
				effect_name = "add_points",
				action = "on_play",
				phase = "points",
				value = S.stance_focus_bonus_points_per_round,
				priority = S.stance_turn_bonus_priority,
				conditions = {
					{ condition_name = "temporary_stance_active" },
					{ condition_name = "stance_owner_is_current_turn" },
				},
			},
		},

I'm just not sure how to handle if we have multiple values for effects or conditions

2. I'm stiil not sure how do you define conditions inside conditions.lua

1. I don't like if and elseif in ai/scoring/stone_placement_effects.lua it is a bad design, should be refactored.
2. In objects/definitions/shared_stones_effects.lua we shouldn't have values for wall_stone, diagonal_group_points, line_group_points because those shapes should be only triggered on placement of a given stone.
3. energy should be part of the state of the game and energy_stone similar like other stones should modify a state of the game.
4. functions that are not directly used as effects in stones definitions should be in effects_helpers.lua not effects.lua
5. Docstrings are missing for some effects and effects_helpers.
6. I don't understand defence_solidity_network why it doesn't modify stones in the state of the game?
7. There are so many new files added in the resolver however I don't understand why those are not just added as effects. The purpose of effect was to have be how a clear entry point of what a specific stone does by modifying the state of the game. I guess for stone removal we need a specific action on the board but board is a still a part of the state so I don't understand why we cannot simply have all those newly added files in resolver moved to objects/helper_effects/ and then use them in effects. For me the navigation of the code should be very clear. If I have a stone I should look at it's effect and see what exactly is happening, right now it doesn't seem to work like that.
8. Even though agents were instructed to not modify tests, just asserts if necessary, unfortunately some tests were modified. We place different stones, we have different initial boards this is unacceptable and needs to be reverted ASAP!!!!
