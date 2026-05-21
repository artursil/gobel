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