import math

EMPTY = "."
A_STONE = "A"
B_STONE = "B"
A_STRONG = "Y"
B_STRONG = "X"

N = 9

# -----------------------------
# BOARD (EDIT THIS)
# -----------------------------
board = [
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", "A", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    ["B", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
    [".", ".", ".", ".", ".", ".", ".", ".", "."],
]

# -----------------------------
# CONFIG
# -----------------------------
BONUS_STRONG = 0  # <-- THIS makes the effect visible


# -----------------------------
# DISTANCE
# -----------------------------
def manhattan(r1, c1, r2, c2):
    return abs(r1 - r2) + abs(c1 - c2)


# -----------------------------
# COLLECT STONES
# -----------------------------
def get_stones():
    A = []
    B = []

    for r in range(N):
        for c in range(N):
            cell = board[r][c]

            if cell == "A":
                A.append((r, c, 0))  # normal
            elif cell == "Y":
                A.append((r, c, BONUS_STRONG))
            elif cell == "B":
                B.append((r, c, 0))
            elif cell == "X":
                B.append((r, c, BONUS_STRONG))

    return A, B


# -----------------------------
# EFFECTIVE DISTANCE
# -----------------------------
def effective_distance(r, c, stones):
    best = math.inf

    for sr, sc, bonus in stones:
        d = manhattan(r, c, sr, sc) - bonus
        if d < best:
            best = d

    return best


# -----------------------------
# TERRITORY
# -----------------------------
def compute_territory():
    A_stones, B_stones = get_stones()

    result = [["" for _ in range(N)] for _ in range(N)]

    for r in range(N):
        for c in range(N):
            cell = board[r][c]

            if cell in ["A", "Y"]:
                result[r][c] = cell
                continue
            if cell in ["B", "X"]:
                result[r][c] = cell
                continue

            da = effective_distance(r, c, A_stones)
            db = effective_distance(r, c, B_stones)

            if da < db:
                result[r][c] = "a"
            elif db < da:
                result[r][c] = "b"
            else:
                result[r][c] = "."

    return result


# -----------------------------
# PRINT
# -----------------------------
def print_board(b):
    for row in b:
        print(" ".join(row))


# -----------------------------
# RUN
# -----------------------------
if __name__ == "__main__":
    print("INPUT:")
    print_board(board)

    print("\nOUTPUT:")
    res = compute_territory()
    print_board(res)