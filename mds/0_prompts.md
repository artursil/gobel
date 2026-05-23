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
1. Every time an X is created small or big (sometimes it can be created by none X stones)  all stones creatting an X are moved up and down one after another and then X2  mult over the placed stone
2. For plus_stones similar story
3. For wall if we use wall_stone_other  effect then we move placed stone up and down and display +2 points over it, if it is however wall_stone effect we repeat this action (up and down and +2 point over it ) for every stone in the wall.


Cal them:
x_stone, plus_stone, wall




Cal them:
x_stone, plus_stone, wall