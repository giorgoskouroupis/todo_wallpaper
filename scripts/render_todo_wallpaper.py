#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


DEFAULT_WIDTH = 2560
DEFAULT_HEIGHT = 1600
DEFAULT_SCALE = 2.0

BG_TOP = "#0C1220"
BG_BOTTOM = "#11192A"


def font_search_dirs() -> list[Path]:
    return [
        Path.home() / ".local" / "share" / "fonts",
        Path.home() / ".fonts",
        Path("/usr/local/share/fonts"),
        Path("/usr/share/fonts"),
    ]


@lru_cache(maxsize=None)
def resolve_font_by_name(font_name: str) -> Path | None:
    target = font_name.strip().casefold().replace(" ", "").replace("-", "")
    if not target:
        return None
    matches = []
    for search_dir in font_search_dirs():
        if not search_dir.exists():
            continue
        for candidate in search_dir.rglob("*"):
            if not candidate.is_file() or candidate.suffix.lower() not in {".ttf", ".otf", ".ttc"}:
                continue
            candidate_name = candidate.name.casefold().replace(" ", "").replace("-", "")
            candidate_stem = candidate.stem.casefold().replace(" ", "").replace("-", "")
            if target in candidate_name or target in candidate_stem:
                matches.append(candidate)
    if not matches:
        return None
    matches.sort(key=lambda path: (
        "bold" not in path.name.casefold(),
        "regular" not in path.name.casefold() and "medium" not in path.name.casefold(),
        len(str(path))
    ))
    return matches[0]

TITLE = "#F3F7FB"
BODY = "#DCE5F0"
MUTED = "#8FA1B8"
ACCENT = "#ADC8E6"
MARK = "#ADC8E6"
DIVIDER = (255, 255, 255, 20)
LINE_GAP = 18
PRIORITY_MARK_COLORS = {
    "H": "#D64A3A",
    "M": "#E0B93B",
    "N": MARK,
}
DISPLAY_PRIORITY_ORDER = {"H": 0, "M": 1, "N": 2}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render a TODO markdown file into a wallpaper PNG.")
    parser.add_argument("input", type=Path, help="Path to the markdown or text TODO file.")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path.home() / "Pictures" / "Wallpapers" / "TODO" / "todo-demo.png",
        help="Output PNG path.",
    )
    parser.add_argument("--apply", action="store_true", help="Apply the rendered wallpaper through the detected backend.")
    parser.add_argument("--backend", default="auto", help="Wallpaper application backend. Defaults to auto.")
    parser.add_argument("--screen", default="all", help="Wallpaper target screen. Defaults to all.")
    parser.add_argument("--width", type=int, help="Final wallpaper width in pixels.")
    parser.add_argument("--height", type=int, help="Final wallpaper height in pixels.")
    parser.add_argument(
        "--scale",
        type=float,
        default=DEFAULT_SCALE,
        help="Internal supersampling factor used before downsampling. Higher is crisper but slower.",
    )
    parser.add_argument("--box-position", default="right", help="Compatibility option. Old renderer keeps its original layout.")
    parser.add_argument("--font", help="Compatibility option. Old renderer keeps its original font selection.")
    parser.add_argument(
        "--unique-output",
        action="store_true",
        help="Rotate output names to avoid wallpaper cache reuse.",
    )
    parser.add_argument(
        "--display-order-priorities",
        default="true",
        help="When true, display tasks grouped as high, medium, then normal while preserving order within each group.",
    )
    return parser.parse_args()


def load_font(
    size: int,
    bold: bool = False,
    font_type: str = "default",
    body_font_name: str = "IBM Plex Serif",
) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if font_type in ("title", "body"):
        preferred_name = body_font_name if font_type == "body" and not bold else "IBM Plex Serif"
        font_path = resolve_font_by_name(preferred_name) or resolve_font_by_name("IBM Plex Serif")
        candidates = [font_path] if font_path else []
    else:
        candidates = [
            Path.home() / ".local" / "share" / "fonts" / "Lilex" / "Lilex[wght].ttf",
            Path.home() / ".local" / "share" / "fonts" / "IBM_Plex_Sans" / "IBMPlexSans-VariableFont_wdth,wght.ttf",
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
            Path("/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"),
        ]
    for candidate in candidates:
        if candidate and candidate.exists():
            try:
                return ImageFont.truetype(candidate, size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def parse_todo_lines(text: str) -> tuple[str, list[tuple[str, bool, str]]]:
    title = "TODO"
    tasks: list[tuple[str, bool, str]] = []

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            title = line.lstrip("#").strip() or title
            continue

        match = re.match(r"^[-*]\s+\[([^\]]*)\]\s+(.*)$", line)
        if match:
            marker = match.group(1).strip().upper()
            task_text = match.group(2).strip()
            if marker in {"X", "*"}:
                tasks.append((task_text, True, "N"))
            elif marker in PRIORITY_MARK_COLORS:
                tasks.append((task_text, False, marker))
            else:
                tasks.append((task_text, False, "N"))
        else:
            plain = re.sub(r"^[-*]\s+", "", line).strip()
            tasks.append((plain or line, False, "N"))

    return title, tasks[:12]


def parse_bool(value: str | None) -> bool:
    if value is None:
        return True
    return value.strip().lower() not in {"0", "false", "no", "off"}


def sort_tasks_for_display(tasks: list[tuple[str, bool, str]], enabled: bool) -> list[tuple[str, bool, str]]:
    if not enabled:
        return tasks
    indexed = list(enumerate(tasks))
    indexed.sort(key=lambda item: (DISPLAY_PRIORITY_ORDER.get(item[1][2], 2), item[0]))
    return [task for _index, task in indexed]


def draw_gradient(base: Image.Image, canvas_width: int, canvas_height: int) -> None:
    draw = ImageDraw.Draw(base)
    top = tuple(int(BG_TOP[i : i + 2], 16) for i in (1, 3, 5))
    bottom = tuple(int(BG_BOTTOM[i : i + 2], 16) for i in (1, 3, 5))
    for y in range(canvas_height):
        ratio = y / max(canvas_height - 1, 1)
        color = tuple(int(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        draw.line([(0, y), (canvas_width, y)], fill=color)


def draw_background_shapes(base: Image.Image) -> None:
    return


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    if not words:
        return [""]

    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def measure_list_block(
    draw: ImageDraw.ImageDraw,
    tasks: list[tuple[str, bool, str]],
    body_font: ImageFont.ImageFont,
    mark_font: ImageFont.ImageFont,
    max_text_width: int,
    number_column_width: int,
    text_gap: int,
) -> tuple[int, list[list[str]]]:
    wrapped_tasks: list[list[str]] = []
    max_width = 0
    for index, (task, _done, _priority) in enumerate(tasks, start=1):
        marker = f"{index:02d}"
        marker_width = draw.textbbox((0, 0), marker, font=mark_font)[2]
        wrapped = wrap_text(draw, task, body_font, max_text_width)
        wrapped_tasks.append(wrapped)
        text_width = max(int(draw.textlength(line, font=body_font)) for line in wrapped)
        total_width = max(number_column_width, marker_width) + text_gap + text_width
        max_width = max(max_width, total_width)
    return max_width, wrapped_tasks


def measure_text_column_width(
    draw: ImageDraw.ImageDraw,
    wrapped_tasks: list[list[str]],
    body_font: ImageFont.ImageFont,
) -> int:
    max_width = 0
    for wrapped in wrapped_tasks:
        line_width = max(int(draw.textlength(line, font=body_font)) for line in wrapped)
        max_width = max(max_width, line_width)
    return max_width


def scaled(value: float, factor: float) -> int:
    return max(1, int(round(value * factor)))


def collect_resolutions(node: object) -> list[tuple[int, int]]:
    resolutions: list[tuple[int, int]] = []
    if isinstance(node, dict):
        width = node.get("width")
        height = node.get("height")
        if isinstance(width, int) and isinstance(height, int) and width >= 800 and height >= 600:
            resolutions.append((width, height))
        for value in node.values():
            resolutions.extend(collect_resolutions(value))
    elif isinstance(node, list):
        for item in node:
            resolutions.extend(collect_resolutions(item))
    return resolutions


def detect_smallest_monitor_resolution() -> tuple[int, int]:
    commands = [
        ["niri", "msg", "outputs", "--json"],
        ["wlr-randr", "--json"],
    ]
    for command in commands:
        try:
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=5)
            data = json.loads(result.stdout)
            resolutions = collect_resolutions(data)
            if resolutions:
                return min(resolutions, key=lambda item: item[0] * item[1])
        except (subprocess.SubprocessError, json.JSONDecodeError, OSError):
            continue
    return DEFAULT_WIDTH, DEFAULT_HEIGHT


def choose_body_font_name(tasks: list[tuple[str, bool, str]]) -> str:
    task_count = len(tasks)
    total_chars = sum(len(task) for task, _done, _priority in tasks)
    if task_count >= 6 or total_chars > 90:
        return "IBM Plex Serif Light"
    return "IBM Plex Serif"


def choose_layout_density(tasks: list[tuple[str, bool, str]]) -> float:
    task_count = len(tasks)
    total_chars = sum(len(task) for task, _done, _priority in tasks)
    if task_count <= 6 and total_chars <= 90:
        return 1.08
    if task_count >= 8 or total_chars >= 180:
        return 0.94
    return 1.0


def draw_empty_state(
    draw: ImageDraw.ImageDraw,
    internal_width: int,
    internal_height: int,
    title_font: ImageFont.ImageFont,
    body_font: ImageFont.ImageFont,
    meta_font: ImageFont.ImageFont,
    fit_factor: float,
    layout_density: float,
    title: str,
    footer: str,
    box_position: str,
) -> None:
    outer_margin = scaled(120, fit_factor * layout_density)
    zone_left, zone_right, center_x = resolve_horizontal_zone(internal_width, outer_margin, box_position)
    top = scaled(220, fit_factor * layout_density)

    title_box = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_box[2] - title_box[0]
    draw.text((center_x - title_width / 2, top), title, font=title_font, fill=TITLE)
    top += scaled(156, fit_factor * layout_density)

    date_text = dt.datetime.now().strftime("%d %B %Y")
    date_box = draw.textbbox((0, 0), date_text.upper(), font=meta_font)
    date_width = date_box[2] - date_box[0]
    draw.text((center_x - date_width / 2, top), date_text.upper(), font=meta_font, fill=ACCENT)
    top += scaled(84, fit_factor * layout_density)

    message = "nothing to do, have a beer"
    message_box = draw.textbbox((0, 0), message, font=body_font)
    message_width = message_box[2] - message_box[0]
    divider_half_width = max(title_width // 2, message_width // 2) + scaled(28, fit_factor * layout_density)
    divider_side_padding = scaled(48, fit_factor * layout_density)
    max_divider_half_width = max(
        max(title_width // 2, message_width // 2),
        min(
            center_x - zone_left - divider_side_padding,
            zone_right - center_x - divider_side_padding,
        ),
    )
    divider_half_width = min(divider_half_width, max_divider_half_width)
    draw.line(
        (center_x - divider_half_width, top, center_x + divider_half_width, top),
        fill=DIVIDER,
        width=max(1, scaled(4, fit_factor * layout_density)),
    )
    top += scaled(104, fit_factor * layout_density)

    draw.text((center_x - message_width / 2, top), message, font=body_font, fill=BODY)

    footer_box = draw.textbbox((0, 0), footer, font=meta_font)
    footer_width = footer_box[2] - footer_box[0]
    draw.text((center_x - footer_width / 2, internal_height - scaled(150, fit_factor * layout_density)), footer, font=meta_font, fill=MUTED)


def has_poor_wraps(tasks: list[tuple[str, bool, str]], wrapped_tasks: list[list[str]]) -> bool:
    short_wrap_cases = 0
    for (task, _done, _priority), wrapped in zip(tasks, wrapped_tasks):
        words = len(task.split())
        if words < 4 or len(wrapped) < 2:
            continue

        average_words_per_line = words / len(wrapped)
        shortest_line_words = min(len(line.split()) for line in wrapped if line.strip())
        if average_words_per_line <= 2.25 or shortest_line_words <= 1:
            short_wrap_cases += 1

    return short_wrap_cases >= 1


def resolve_horizontal_zone(internal_width: int, outer_margin: int, box_position: str) -> tuple[int, int, int]:
    half_width = internal_width // 2
    half_gap = max(outer_margin // 2, 1)

    if box_position == "left":
        zone_left = outer_margin
        zone_right = max(zone_left + 1, half_width - half_gap)
        zone_center = (zone_left + zone_right) // 2
        return zone_left, zone_right, zone_center

    if box_position == "center":
        zone_left = outer_margin
        zone_right = internal_width - outer_margin
        zone_center = internal_width // 2
        return zone_left, zone_right, zone_center

    zone_left = min(internal_width - outer_margin - 1, half_width + half_gap)
    zone_right = internal_width - outer_margin
    zone_center = (zone_left + zone_right) // 2
    return zone_left, zone_right, zone_center


def render_wallpaper(
    todo_path: Path,
    output_path: Path,
    width: int,
    height: int,
    scale_factor: float,
    box_position: str,
    display_order_priorities: bool,
) -> None:
    text = todo_path.read_text(encoding="utf-8")
    title, tasks = parse_todo_lines(text)
    tasks = sort_tasks_for_display(tasks, display_order_priorities)
    body_font_name = choose_body_font_name(tasks)
    layout_density = choose_layout_density(tasks)
    canvas_width = max(width, 1)
    canvas_height = max(height, 1)
    internal_width = scaled(canvas_width, scale_factor)
    internal_height = scaled(canvas_height, scale_factor)
    size_factor = min(internal_width / DEFAULT_WIDTH, internal_height / DEFAULT_HEIGHT)

    base = Image.new("RGBA", (internal_width, internal_height), BG_TOP)
    draw_gradient(base, internal_width, internal_height)
    draw_background_shapes(base)

    draw = ImageDraw.Draw(base)
    footer = todo_path.name

    if not tasks:
        fit_factor = size_factor
        title_font = load_font(scaled(112, fit_factor * layout_density), bold=False, font_type="title")
        body_font = load_font(scaled(54, fit_factor * layout_density), bold=False, font_type="body", body_font_name=body_font_name)
        meta_font = load_font(scaled(24, fit_factor * layout_density), bold=True)
        draw_empty_state(draw, internal_width, internal_height, title_font, body_font, meta_font, fit_factor, layout_density, title, footer, box_position)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        final = base.resize((canvas_width, canvas_height), Image.Resampling.LANCZOS)
        final.convert("RGB").save(output_path, format="PNG")
        return

    fit_factor = size_factor
    layout = None
    for _ in range(18):
        title_font = load_font(scaled(112, fit_factor * layout_density), bold=False, font_type="title")
        body_font = load_font(scaled(60, fit_factor * layout_density), bold=False, font_type="body", body_font_name=body_font_name)
        meta_font = load_font(scaled(28, fit_factor * layout_density), bold=True)
        mark_font = load_font(scaled(46, fit_factor * layout_density), bold=True)

        top = scaled(220, fit_factor * layout_density)
        number_column_width = scaled(120, fit_factor * layout_density)
        text_gap = scaled(44, fit_factor * layout_density)
        outer_margin = scaled(120, fit_factor * layout_density)
        box_left, box_right, target_center_x = resolve_horizontal_zone(internal_width, outer_margin, box_position)
        available_width = box_right - box_left
        max_text_width = max(1, available_width - number_column_width - text_gap)

        list_block_width, wrapped_tasks = measure_list_block(
            draw, tasks, body_font, mark_font, max_text_width, number_column_width, text_gap
        )

        if list_block_width > available_width:
            widened_available_width = box_right - box_left
            widened_text_width = max(1, widened_available_width - number_column_width - text_gap)
            widened_block_width, widened_wrapped_tasks = measure_list_block(
                draw, tasks, body_font, mark_font, widened_text_width, number_column_width, text_gap
            )
            if widened_block_width <= widened_available_width:
                available_width = widened_available_width
                max_text_width = widened_text_width
                list_block_width = widened_block_width
                wrapped_tasks = widened_wrapped_tasks

        text_column_width = measure_text_column_width(draw, wrapped_tasks, body_font)
        target_block_left = target_center_x - text_column_width // 2 - number_column_width - text_gap
        block_left = max(box_left, min(box_right - list_block_width, target_block_left))
        if block_left < box_left:
            fit_factor *= 0.92
            continue

        if has_poor_wraps(tasks, wrapped_tasks) and fit_factor > size_factor * 0.72:
            fit_factor *= 0.95
            continue

        text_left = block_left + number_column_width + text_gap
        visible_block_right = text_left + text_column_width
        block_right = box_right
        content_center_x = (text_left + visible_block_right) // 2

        estimated_top = top + scaled(156, fit_factor * layout_density) + scaled(84, fit_factor * layout_density) + scaled(104, fit_factor * layout_density)
        line_height = body_font.size + scaled(LINE_GAP, fit_factor * layout_density)
        total_task_height = sum(len(lines) * line_height + scaled(22, fit_factor * layout_density) for lines in wrapped_tasks)
        footer_y = internal_height - scaled(150, fit_factor * layout_density)
        if estimated_top + total_task_height <= footer_y - scaled(32, fit_factor * layout_density):
            layout = {
                "title_font": title_font,
                "body_font": body_font,
                "meta_font": meta_font,
                "mark_font": mark_font,
                "top": top,
                "number_column_width": number_column_width,
                "text_left": text_left,
                "wrapped_tasks": wrapped_tasks,
                "block_left": block_left,
                "visible_block_right": visible_block_right,
                "block_right": block_right,
                "content_center_x": content_center_x,
                "fit_factor": fit_factor,
            }
            break

        fit_factor *= 0.92

    if layout is None:
        title_font = load_font(scaled(84, fit_factor * layout_density), bold=False, font_type="title")
        body_font = load_font(scaled(44, fit_factor * layout_density), bold=False, font_type="body", body_font_name=body_font_name)
        meta_font = load_font(scaled(22, fit_factor * layout_density), bold=True)
        mark_font = load_font(scaled(34, fit_factor * layout_density), bold=True)
        top = scaled(180, fit_factor * layout_density)
        number_column_width = scaled(96, fit_factor * layout_density)
        text_gap = scaled(36, fit_factor * layout_density)
        outer_margin = scaled(90, fit_factor * layout_density)
        box_left, block_right, target_center_x = resolve_horizontal_zone(internal_width, outer_margin, box_position)
        max_text_width = max(1, (block_right - box_left) - number_column_width - text_gap)
        list_block_width, wrapped_tasks = measure_list_block(
            draw, tasks, body_font, mark_font, max_text_width, number_column_width, text_gap
        )
        text_column_width = measure_text_column_width(draw, wrapped_tasks, body_font)
        target_block_left = target_center_x - text_column_width // 2 - number_column_width - text_gap
        block_left = max(box_left, min(block_right - list_block_width, target_block_left))
        text_left = block_left + number_column_width + text_gap
        visible_block_right = text_left + text_column_width
        content_center_x = (text_left + visible_block_right) // 2
    else:
        title_font = layout["title_font"]
        body_font = layout["body_font"]
        meta_font = layout["meta_font"]
        mark_font = layout["mark_font"]
        top = layout["top"]
        number_column_width = layout["number_column_width"]
        text_left = layout["text_left"]
        wrapped_tasks = layout["wrapped_tasks"]
        block_left = layout["block_left"]
        visible_block_right = layout["visible_block_right"]
        block_right = layout["block_right"]
        content_center_x = layout["content_center_x"]
        fit_factor = layout["fit_factor"]

    title_box = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_box[2] - title_box[0]
    draw.text((content_center_x - title_width / 2, top), title, font=title_font, fill=TITLE)
    top += scaled(156, fit_factor * layout_density)

    date_text = dt.datetime.now().strftime("%d %B %Y")
    date_box = draw.textbbox((0, 0), date_text.upper(), font=meta_font)
    date_width = date_box[2] - date_box[0]
    draw.text((content_center_x - date_width / 2, top), date_text.upper(), font=meta_font, fill=ACCENT)
    top += scaled(84, fit_factor * layout_density)

    longest_row_half_width = 0
    for wrapped in wrapped_tasks:
        for wrapped_line in wrapped:
            wrapped_line_width = int(draw.textlength(wrapped_line, font=body_font))
            row_left = block_left
            row_right = text_left + wrapped_line_width
            longest_row_half_width = max(
                longest_row_half_width,
                content_center_x - row_left,
                row_right - content_center_x,
            )

    divider_content_half_width = max((title_width + 1) // 2, longest_row_half_width)
    divider_half_width = divider_content_half_width + scaled(28, fit_factor * layout_density)
    divider_side_padding = scaled(48, fit_factor * layout_density)
    max_divider_half_width = max(
        divider_content_half_width,
        min(
            content_center_x - block_left - divider_side_padding,
            block_right - content_center_x - divider_side_padding,
        ),
    )
    divider_half_width = min(divider_half_width, max_divider_half_width)
    draw.line(
        (content_center_x - divider_half_width, top, content_center_x + divider_half_width, top),
        fill=DIVIDER,
        width=max(1, scaled(4, fit_factor * layout_density)),
    )
    top += scaled(104, fit_factor * layout_density)
    body_line_box = draw.textbbox((0, 0), "Ag", font=body_font)
    body_line_height = body_line_box[3] - body_line_box[1]

    for index, ((task, done, priority), wrapped) in enumerate(zip(tasks, wrapped_tasks), start=1):
        marker = f"{index:02d}"
        marker_box = draw.textbbox((0, 0), marker, font=mark_font)
        marker_width = marker_box[2] - marker_box[0]
        marker_height = marker_box[3] - marker_box[1]
        marker_y = top + body_line_box[1] + (body_line_height - marker_height) / 2 - marker_box[1] - scaled(5, fit_factor * layout_density)
        marker_color = PRIORITY_MARK_COLORS.get(priority, MARK)
        draw.text((block_left + number_column_width - marker_width, marker_y), marker, font=mark_font, fill=marker_color)

        line_top = top
        for wrapped_line in wrapped:
            draw.text((text_left, line_top), wrapped_line, font=body_font, fill=MUTED if done else BODY)
            line_top += body_font.size + scaled(LINE_GAP, fit_factor * layout_density)
        if done:
            first_line = wrapped[0]
            strike_y = top + body_font.size // 2 + scaled(8, fit_factor * layout_density)
            strike_end = min(text_left + draw.textlength(first_line, font=body_font), block_right)
            draw.line((text_left, strike_y, strike_end, strike_y), fill=(180, 190, 205, 220), width=max(1, scaled(4, fit_factor * layout_density)))
        top = line_top + scaled(22, fit_factor * layout_density)

    footer_box = draw.textbbox((0, 0), footer, font=meta_font)
    footer_width = footer_box[2] - footer_box[0]
    draw.text((content_center_x - footer_width / 2, internal_height - scaled(150, fit_factor * layout_density)), footer, font=meta_font, fill=MUTED)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    final = base.resize((canvas_width, canvas_height), Image.Resampling.LANCZOS)
    final.convert("RGB").save(output_path, format="PNG")


def resolve_output_path(output_path: Path, unique_output: bool) -> Path:
    output_path = output_path.expanduser()
    if unique_output:
        return next_rotating_output_path(output_path)
    return output_path


def next_rotating_output_path(output_path: Path, pool_size: int = 2) -> Path:
    state_path = output_path.with_name(f".{output_path.stem}.state.json")
    slot = 0

    if state_path.exists():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            slot = int(state.get("next_slot", 0))
        except (json.JSONDecodeError, OSError, ValueError, TypeError):
            slot = 0

    chosen_slot = slot % pool_size
    next_slot = (chosen_slot + 1) % pool_size
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps({"next_slot": next_slot}), encoding="utf-8")
    if chosen_slot == 0:
        return output_path
    return output_path.with_name(f".{output_path.stem}.tmp{output_path.suffix}")


def apply_wallpaper(output_path: Path, backend: str, screen: str) -> None:
    script_path = Path(__file__).with_name("apply_wallpaper.sh")
    subprocess.run([str(script_path), "apply", backend, str(output_path), screen], check=True)


def main() -> int:
    args = parse_args()
    output_path = resolve_output_path(args.output, args.unique_output)
    width, height = args.width, args.height
    if width is None or height is None:
        detected_width, detected_height = detect_smallest_monitor_resolution()
        width = width or detected_width
        height = height or detected_height
    render_wallpaper(
        args.input.expanduser(),
        output_path,
        width,
        height,
        args.scale,
        args.box_position,
        parse_bool(args.display_order_priorities),
    )
    if args.apply:
        apply_wallpaper(output_path, args.backend, args.screen)
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
