#!/usr/bin/env python3
"""Migrate Material Icons usages to AppIcons / AppIcon (HugeIcons)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
IMPORT_LINE = "import 'package:estimation/core/icons/app_icons.dart';"

# Material Icons.<name> -> AppIcons.<camelName>
ICON_MAP: dict[str, str] = {
    "account_circle_rounded": "accountCircle",
    "add_circle_outline_rounded": "addCircleOutline",
    "arrow_back_ios_new_rounded": "arrowBackIosNew",
    "arrow_back_rounded": "arrowBack",
    "arrow_circle_down_rounded": "arrowCircleDown",
    "arrow_circle_up_rounded": "arrowCircleUp",
    "arrow_forward_ios_rounded": "arrowForwardIos",
    "arrow_forward_rounded": "arrowForward",
    "assignment_turned_in_rounded": "assignmentTurnedIn",
    "auto_awesome_rounded": "autoAwesome",
    "autorenew_rounded": "autorenew",
    "badge_rounded": "badge",
    "balance_rounded": "balance",
    "bar_chart_rounded": "barChart",
    "block_rounded": "block",
    "bolt_rounded": "bolt",
    "cached_rounded": "cached",
    "calculate_rounded": "calculate",
    "camera_alt_rounded": "cameraAlt",
    "cancel_rounded": "cancel",
    "casino_rounded": "casino",
    "chat_bubble_outline_rounded": "chatBubbleOutline",
    "check_circle_outline_rounded": "checkCircleOutline",
    "check_circle_rounded": "checkCircle",
    "check_rounded": "checkRounded",
    "check": "check",
    "circle": "circle",
    "close_rounded": "close",
    "cloud_off_rounded": "cloudOff",
    "cloud_sync_rounded": "cloudSync",
    "copy_rounded": "copy",
    "download_rounded": "download",
    "edit_note_rounded": "editNote",
    "edit_rounded": "edit",
    "emoji_events_rounded": "emojiEvents",
    "error_outline_rounded": "errorOutline",
    "error_rounded": "error",
    "exit_to_app_rounded": "exitToApp",
    "extension_rounded": "extension",
    "flag_circle_rounded": "flagCircle",
    "flag_rounded": "flag",
    "flash_on_rounded": "flashOn",
    "flip_rounded": "flip",
    "format_list_numbered_rounded": "formatListNumbered",
    "gavel_rounded": "gavel",
    "gps_fixed_rounded": "gpsFixed",
    "grid_view_rounded": "gridView",
    "group_rounded": "group",
    "groups_rounded": "groups",
    "help_outline_rounded": "helpOutline",
    "history_rounded": "history",
    "history_toggle_off_rounded": "historyToggleOff",
    "home_rounded": "home",
    "hourglass_bottom_rounded": "hourglassBottom",
    "hourglass_empty_rounded": "hourglassEmpty",
    "info_outline_rounded": "infoOutline",
    "info_rounded": "info",
    "insights_rounded": "insights",
    "ios_share_rounded": "iosShare",
    "keyboard_arrow_down_rounded": "keyboardArrowDown",
    "keyboard_arrow_up_rounded": "keyboardArrowUp",
    "keyboard_double_arrow_down_rounded": "keyboardDoubleArrowDown",
    "keyboard_double_arrow_up_rounded": "keyboardDoubleArrowUp",
    "lan_rounded": "lan",
    "layers_rounded": "layers",
    "leaderboard_rounded": "leaderboard",
    "lightbulb_rounded": "lightbulb",
    "local_fire_department_rounded": "localFireDepartment",
    "lock_rounded": "lock",
    "login_rounded": "login",
    "logout_rounded": "logout",
    "menu_book_rounded": "menuBook",
    "military_tech_rounded": "militaryTech",
    "open_in_browser_rounded": "openInBrowser",
    "palette_outlined": "palette",
    "pan_tool_alt_rounded": "panToolAlt",
    "person_rounded": "person",
    "photo_library_rounded": "photoLibrary",
    "pie_chart_rounded": "pieChart",
    "play_arrow_rounded": "playArrow",
    "play_circle_fill_rounded": "playCircleFill",
    "play_circle_rounded": "playCircle",
    "priority_high_rounded": "priorityHigh",
    "psychology_alt_rounded": "psychologyAlt",
    "psychology_rounded": "psychology",
    "public_rounded": "public",
    "query_stats_rounded": "queryStats",
    "record_voice_over_rounded": "recordVoiceOver",
    "refresh_rounded": "refresh",
    "remove_rounded": "remove",
    "replay_circle_filled_rounded": "replayCircleFilled",
    "school_rounded": "school",
    "search_off_rounded": "searchOff",
    "settings_outlined": "settingsOutlined",
    "settings_rounded": "settings",
    "share_rounded": "share",
    "shield_rounded": "shield",
    "smart_toy_outlined": "smartToy",
    "sports_esports_rounded": "sportsEsports",
    "star_rounded": "star",
    "stars_rounded": "stars",
    "style_rounded": "style",
    "style": "style",
    "swap_horizontal_circle_outlined": "swapHorizontalCircle",
    "swipe_rounded": "swipe",
    "sync_rounded": "sync",
    "system_update_alt_rounded": "systemUpdateAlt",
    "tag_rounded": "tag",
    "task_alt_rounded": "taskAlt",
    "touch_app_rounded": "touchApp",
    "track_changes_rounded": "trackChanges",
    "trending_up_rounded": "trendingUp",
    "tune_rounded": "tune",
    "verified_rounded": "verified",
    "verified_user_rounded": "verifiedUser",
    "vibration_rounded": "vibration",
    "videogame_asset_rounded": "videogameAsset",
    "volume_mute_rounded": "volumeMute",
    "volume_off_rounded": "volumeOff",
    "volume_up_rounded": "volumeUp",
    "warning_amber_rounded": "warningAmber",
    "warning_rounded": "warning",
    "whatshot_rounded": "whatshot",
    "wifi_find_rounded": "wifiFind",
    "wifi_off_rounded": "wifiOff",
    "wifi_rounded": "wifi",
    "wifi_tethering_rounded": "wifiTethering",
    "workspace_premium_rounded": "workspacePremium",
}

# Longer Material names first so check_circle_rounded wins over check / circle.
_SORTED_KEYS = sorted(ICON_MAP.keys(), key=len, reverse=True)
_ICON_RE = re.compile(
    r"\bIcons\.(" + "|".join(re.escape(k) for k in _SORTED_KEYS) + r")\b"
)
_ICON_WIDGET_RE = re.compile(r"(?<![A-Za-z0-9_])Icon\(")
_CONST_ICON_WIDGET_RE = re.compile(r"\bconst\s+AppIcon\(")
_ICON_DATA_RE = re.compile(r"\bIconData\b")


def migrate_text(text: str) -> tuple[str, bool]:
    if "Icons." not in text and "IconData" not in text and not re.search(r"(?<![A-Za-z0-9_])Icon\(", text):
        return text, False

    original = text
    changed = False

    def repl_icon(match: re.Match[str]) -> str:
        nonlocal changed
        key = match.group(1)
        changed = True
        return f"AppIcons.{ICON_MAP[key]}"

    text = _ICON_RE.sub(repl_icon, text)

    # Only rewrite Icon(...) widgets in files that now reference AppIcons,
    # or that already used IconData params we are converting.
    if "AppIcons." in text or "IconData" in text:
        new_text = _ICON_WIDGET_RE.sub("AppIcon(", text)
        if new_text != text:
            text = new_text
            changed = True
        # IconData type -> AppIconData
        new_text = _ICON_DATA_RE.sub("AppIconData", text)
        if new_text != text:
            text = new_text
            changed = True

    # const AppIcon is valid; keep it.
    # Ensure package import when AppIcons/AppIcon/AppIconData are used.
    if changed and (
        "AppIcons." in text or "AppIcon(" in text or "AppIconData" in text
    ):
        if IMPORT_LINE not in text and "core/icons/app_icons.dart" not in text:
            # Insert after the last import line.
            lines = text.splitlines(keepends=True)
            insert_at = 0
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    insert_at = i + 1
            lines.insert(insert_at, IMPORT_LINE + "\n")
            text = "".join(lines)

    return text, text != original


def main() -> None:
    updated = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name == "app_icons.dart":
            continue
        raw = path.read_text(encoding="utf-8")
        new, changed = migrate_text(raw)
        if changed:
            path.write_text(new, encoding="utf-8", newline="\n")
            updated += 1
            print(f"updated: {path.relative_to(ROOT.parent)}")
    print(f"Done. Files updated: {updated}")


if __name__ == "__main__":
    main()
