#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import re
from pathlib import Path


TASK_RE = re.compile(r"^(\s*[-*]\s+\[[^\]]*\]\s+)(.*?)(\s*)$")
TITLE_RE = re.compile(r"^\s*#")
PRIORITY_ORDER = {"H": 0, "M": 1, "N": 2}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Edit the todo_wallpaper markdown file.")
    parser.add_argument(
        "--display-order-priorities",
        default="true",
        help="When true, list and line-numbered operations follow display priority order instead of markdown order.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    add_parser = subparsers.add_parser("add", help="Add a task at the end or at a 1-based task position.")
    add_parser.add_argument("todo_file", type=Path)
    priority_group = add_parser.add_mutually_exclusive_group()
    priority_group.add_argument("-H", "--high", dest="priority", action="store_const", const="high")
    priority_group.add_argument("-M", "--medium", dest="priority", action="store_const", const="medium")
    priority_group.add_argument("-N", "--normal", dest="priority", action="store_const", const="normal")
    add_parser.add_argument("-n", "--line-number", dest="line_number", type=int)
    add_parser.add_argument("text", nargs="+")

    replace_parser = subparsers.add_parser("replace", help="Replace a task at a 1-based task position.")
    replace_parser.add_argument("todo_file", type=Path)
    replace_priority_group = replace_parser.add_mutually_exclusive_group()
    replace_priority_group.add_argument("-H", "--high", dest="priority", action="store_const", const="high")
    replace_priority_group.add_argument("-M", "--medium", dest="priority", action="store_const", const="medium")
    replace_priority_group.add_argument("-N", "--normal", dest="priority", action="store_const", const="normal")
    replace_parser.add_argument("-n", "--line-number", dest="line_number", type=int, required=True)
    replace_parser.add_argument("text", nargs="+")

    change_priority_parser = subparsers.add_parser(
        "change-priority",
        help="Change the priority marker of a task at a 1-based task position.",
    )
    change_priority_parser.add_argument("todo_file", type=Path)
    change_priority_parser.add_argument("-n", "--line-number", dest="line_number", type=int, required=True)
    change_priority_group = change_priority_parser.add_mutually_exclusive_group(required=True)
    change_priority_group.add_argument("-H", "--high", dest="priority", action="store_const", const="high")
    change_priority_group.add_argument("-M", "--medium", dest="priority", action="store_const", const="medium")
    change_priority_group.add_argument("-N", "--normal", dest="priority", action="store_const", const="normal")
    change_priority_group.add_argument("priority_name", nargs="?", choices=["high", "medium", "normal"])

    list_parser = subparsers.add_parser("list", help="List tasks by 1-based task position.")
    list_parser.add_argument("todo_file", type=Path)

    remove_parser = subparsers.add_parser("remove", help="Remove one or more tasks by 1-based task position.")
    remove_parser.add_argument("todo_file", type=Path)
    remove_parser.add_argument("-n", "--line-number", dest="line_numbers", action="append", required=True)

    done_parser = subparsers.add_parser("done", help="Mark one or more tasks done by 1-based task position.")
    done_parser.add_argument("todo_file", type=Path)
    done_parser.add_argument("-n", "--line-number", dest="line_numbers", action="append", required=True)

    undone_parser = subparsers.add_parser("undone", help="Mark one or more tasks not done by 1-based task position.")
    undone_parser.add_argument("todo_file", type=Path)
    undone_parser.add_argument("-n", "--line-number", dest="line_numbers", action="append", required=True)

    return parser.parse_args()


def normalize_task_text(raw: str) -> str:
    text = raw.strip()
    if not text:
        raise ValueError("task text cannot be empty")
    if TASK_RE.match(text):
        return text
    if re.match(r"^\[[^\]]+\]\s+", text):
        return f"- {text}"
    return f"- [ ] {text}"


def apply_priority_shorthand(priority_flag: str | None, text: str) -> str:
    if not priority_flag:
        return text
    prefix = {"high": "[H]", "medium": "[M]", "normal": "[ ]"}[priority_flag]
    if TASK_RE.match(text) or re.match(r"^\[[^\]]+\]\s+", text.strip()):
        return text
    return f"{prefix} {text}"


def read_lines(todo_file: Path) -> list[str]:
    if todo_file.exists():
        return todo_file.read_text(encoding="utf-8").splitlines()
    return ["# TODO", ""]


def backup_todo_file(todo_file: Path) -> None:
    if not todo_file.exists():
        return
    backup_path = todo_file.with_name(f"{todo_file.name}.bak")
    shutil.copyfile(todo_file, backup_path)


def task_indices(lines: list[str]) -> list[int]:
    indices: list[int] = []
    for i, line in enumerate(lines):
        if TASK_RE.match(line):
            indices.append(i)
    return indices


def parse_task_priority(line: str) -> str:
    match = TASK_RE.match(line)
    if not match:
        return "N"
    marker_match = re.search(r"\[([^\]]*)\]", match.group(1))
    if not marker_match:
        return "N"
    marker = marker_match.group(1).strip().upper()
    if marker in {"H", "M"}:
        return marker
    return "N"


def parse_bool(value: str | None) -> bool:
    if value is None:
        return True
    return value.strip().lower() not in {"0", "false", "no", "off"}


def task_indices_in_display_order(lines: list[str], display_order_priorities: bool) -> list[int]:
    indices = task_indices(lines)
    if not display_order_priorities:
        return indices
    return sorted(indices, key=lambda index: (PRIORITY_ORDER.get(parse_task_priority(lines[index]), 2), index))


def ensure_header(lines: list[str]) -> list[str]:
    if any(TITLE_RE.match(line) for line in lines):
        return lines
    if lines and lines[0].strip():
        return ["# TODO", "", *lines]
    return ["# TODO", "", *lines]


def add_task(lines: list[str], line_number: int | None, text: str, display_order_priorities: bool) -> list[str]:
    lines = ensure_header(lines)
    entry = normalize_task_text(text)
    indices = task_indices_in_display_order(lines, display_order_priorities)

    if line_number is None:
        insert_at = len(lines)
        if insert_at > 0 and lines[-1].strip():
            lines.append("")
            insert_at = len(lines)
        lines.insert(insert_at, entry)
        return lines

    if line_number < 1:
        raise ValueError("line number must be >= 1")

    if not indices:
        insert_at = len(lines)
        if insert_at > 0 and lines[-1].strip():
            lines.append("")
            insert_at = len(lines)
        lines.insert(insert_at, entry)
        return lines

    if line_number > len(indices):
        insert_at = indices[-1] + 1
        lines.insert(insert_at, entry)
        return lines

    insert_at = indices[line_number - 1]
    lines.insert(insert_at, entry)
    return lines


def remove_task(lines: list[str], line_number: int, display_order_priorities: bool) -> list[str]:
    indices = task_indices_in_display_order(lines, display_order_priorities)
    if line_number < 1 or line_number > len(indices):
        raise ValueError(f"task line number out of range: {line_number}")
    del lines[indices[line_number - 1]]
    return lines


def replace_task(lines: list[str], line_number: int, text: str, display_order_priorities: bool) -> list[str]:
    indices = task_indices_in_display_order(lines, display_order_priorities)
    if line_number < 1 or line_number > len(indices):
        raise ValueError(f"task line number out of range: {line_number}")
    lines[indices[line_number - 1]] = normalize_task_text(text)
    return lines


def set_done_state(lines: list[str], line_number: int, done: bool, display_order_priorities: bool) -> list[str]:
    indices = task_indices_in_display_order(lines, display_order_priorities)
    if line_number < 1 or line_number > len(indices):
        raise ValueError(f"task line number out of range: {line_number}")

    index = indices[line_number - 1]
    match = TASK_RE.match(lines[index])
    if not match:
        raise ValueError(f"task line number out of range: {line_number}")

    prefix, task_text, suffix = match.groups()
    marker = "X" if done else " "
    lines[index] = re.sub(r"\[[^\]]*\]", f"[{marker}]", prefix, count=1) + task_text + suffix
    return lines


def change_priority(lines: list[str], line_number: int, priority: str, display_order_priorities: bool) -> list[str]:
    indices = task_indices_in_display_order(lines, display_order_priorities)
    if line_number < 1 or line_number > len(indices):
        raise ValueError(f"task line number out of range: {line_number}")

    index = indices[line_number - 1]
    match = TASK_RE.match(lines[index])
    if not match:
        raise ValueError(f"task line number out of range: {line_number}")

    prefix, task_text, suffix = match.groups()
    marker = {"high": "H", "medium": "M", "normal": " "}[priority]
    lines[index] = re.sub(r"\[[^\]]*\]", f"[{marker}]", prefix, count=1) + task_text + suffix
    return lines


def parse_remove_numbers(raw_values: list[str]) -> list[int]:
    numbers: list[int] = []
    for raw in raw_values:
        for part in raw.split(","):
            value = part.strip()
            if not value:
                continue
            numbers.append(int(value))
    if not numbers:
        raise ValueError("no line numbers provided")
    unique_desc = sorted(set(numbers), reverse=True)
    return unique_desc


def format_task_list(lines: list[str], display_order_priorities: bool) -> str:
    output: list[str] = []
    for counter, index in enumerate(task_indices_in_display_order(lines, display_order_priorities), start=1):
        line = lines[index]
        match = TASK_RE.match(line)
        if not match:
            continue
        output.append(f"{counter:02d}  {line.strip()}")
    if not output:
        return "No tasks."
    return "\n".join(output)


def main() -> int:
    args = parse_args()
    todo_file = args.todo_file.expanduser()
    lines = read_lines(todo_file)
    display_order_priorities = parse_bool(args.display_order_priorities)

    if args.command == "add":
        line_number = args.line_number
        text = " ".join(args.text).strip()
        if not text:
            raise SystemExit("missing task text for add")
        text = apply_priority_shorthand(args.priority, text)
        updated = add_task(lines, line_number, text, display_order_priorities)
    elif args.command == "replace":
        text = " ".join(args.text).strip()
        if not text:
            raise SystemExit("missing task text for replace")
        text = apply_priority_shorthand(args.priority, text)
        updated = replace_task(lines, args.line_number, text, display_order_priorities)
    elif args.command == "list":
        print(format_task_list(lines, display_order_priorities))
        return 0
    elif args.command == "done":
        updated = lines
        for line_number in parse_remove_numbers(args.line_numbers):
            updated = set_done_state(updated, line_number, True, display_order_priorities)
    elif args.command == "undone":
        updated = lines
        for line_number in parse_remove_numbers(args.line_numbers):
            updated = set_done_state(updated, line_number, False, display_order_priorities)
    elif args.command == "change-priority":
        priority = args.priority or args.priority_name
        updated = change_priority(lines, args.line_number, priority, display_order_priorities)
    else:
        updated = lines
        for line_number in parse_remove_numbers(args.line_numbers):
            updated = remove_task(updated, line_number, display_order_priorities)

    backup_todo_file(todo_file)
    todo_file.write_text("\n".join(updated).rstrip() + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
