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


