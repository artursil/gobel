#!/usr/bin/env python3
"""Merge helpers for stones.lua during agent branch integration."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ALL_UNIMPLEMENTED = [
    "points_stone",
    "influence_stone",
    "tower_stone",
    "energy_stone",
    "diagonal_stone",
    "line_stone",
    "kamikaze_stone",
    "enclosure_stone",
    "control_stone",
    "blockade_stone",
    "defence_stone",
    "money_field_stone",
    "anti_capture_stone",
    "delay_reward_stone",
    "capture_stone",
    "tax_stone",
    "self_destruct_timed_stone",
    "territory_to_points_stone",
    "territory_to_multiplier_stone",
    "escalating_points_stone",
    "escalating_money_stone",
    "high_power_money_loss_stone",
]

ISSUE_STONES = {
    4: "points_stone",
    5: "influence_stone",
    6: "tower_stone",
    7: "energy_stone",
    8: "diagonal_stone",
    9: "line_stone",
    10: "kamikaze_stone",
    11: "enclosure_stone",
    12: "control_stone",
    13: "blockade_stone",
    14: "defence_stone",
    15: "money_field_stone",
    16: "anti_capture_stone",
    17: "delay_reward_stone",
    18: "capture_stone",
    19: "tax_stone",
    20: "self_destruct_timed_stone",
    21: "territory_to_points_stone",
    22: "territory_to_multiplier_stone",
    23: "escalating_points_stone",
    24: "escalating_money_stone",
    25: "high_power_money_loss_stone",
}


def git_show(ref: str, path: str) -> str | None:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def extract_stone_block(text: str, stone_id: str) -> str | None:
    pattern = rf"(M\.{re.escape(stone_id)}\s*=\s*\{{)"
    match = re.search(pattern, text)
    if not match:
        return None
    start = match.start()
    brace_start = text.find("{", match.start())
    depth = 0
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    return None


def implemented_stone_ids(text: str) -> set[str]:
    ids: set[str] = set()
    for match in re.finditer(r'M\.(\w+)\s*=\s*\{', text):
        stone_id = match.group(1)
        block = extract_stone_block(text, stone_id)
        if block is None:
            continue
        if 'effects = {}' in block and "upgrade_levels" not in block and "tags" not in block:
            if stone_id in ALL_UNIMPLEMENTED:
                continue
        ids.add(stone_id)
    return ids


def strip_conflict_markers(text: str) -> str:
    while "<<<<<<<" in text:
        text = re.sub(
            r"<<<<<<<[^\n]*\n(.*?)\n=======\n(.*?)\n>>>>>>>[^\n]*\n",
            r"\1\2",
            text,
            count=1,
            flags=re.DOTALL,
        )
    return text


def rebuild_unimplemented_list(text: str) -> str:
    implemented = implemented_stone_ids(text)
    remaining = [stone_id for stone_id in ALL_UNIMPLEMENTED if stone_id not in implemented]
    new_list = "local UNIMPLEMENTED_STONE_IDS = {\n" + "".join(
        f'\t"{stone_id}",\n' for stone_id in remaining
    ) + "}"
    return re.sub(
        r"local UNIMPLEMENTED_STONE_IDS = \{[^}]+\}",
        new_list,
        text,
        count=1,
    )


def inject_stone_block(text: str, block: str) -> str:
    stone_id_match = re.search(r'id\s*=\s*"(\w+)"', block)
    if stone_id_match is None:
        return text
    stone_id = stone_id_match.group(1)
    existing = extract_stone_block(text, stone_id)
    if existing:
        return text.replace(existing, block)
    anchor = "local function stub_stone"
    insert_at = text.find(anchor)
    if insert_at == -1:
        return text
    return text[:insert_at] + block + "\n\n" + text[insert_at:]


def merge_stones_file(path: Path, issue_num: int | None = None) -> None:
    text = path.read_text()
    text = strip_conflict_markers(text)

    if issue_num is not None:
        stone_id = ISSUE_STONES.get(issue_num)
        if stone_id:
            branch_ref = f"origin/agent/issue-{issue_num}"
            branch_text = git_show(branch_ref, str(path))
            if branch_text:
                block = extract_stone_block(branch_text, stone_id)
                if block:
                    text = inject_stone_block(text, block)

    text = rebuild_unimplemented_list(text)
    path.write_text(text)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: merge_stones_helper.py <stones.lua> [issue_num]", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    issue_num = int(sys.argv[2]) if len(sys.argv) > 2 else None
    merge_stones_file(path, issue_num)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
