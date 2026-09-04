#!/usr/bin/env python3
"""
Patch caelestia-cli's parser.py to register a new 'keybinds' subcommand.

Usage:
  python3 patch-caelestia-cli.py path/to/parser.py
"""

import re
import sys
from pathlib import Path


def patch_parser(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    # 1. Add keybinds import
    import_block = "from caelestia.subcommands import (\n    clipboard,\n    emoji,\n    install,\n"
    if "    keybinds,\n" not in text:
        text = text.replace(
            import_block,
            import_block.replace("    install,\n", "    install,\n    keybinds,\n"),
        )

    # 2. Add keybinds parser registration after the shell parser block
    # Find the shell parser section and insert after it.
    shell_block_end = 'shell_parser.add_argument("--log-rules", metavar="RULES", help="log rules to apply")\n\n'
    keybinds_block = '''    # Create parser for keybinds opts
    keybinds_parser = command_parser.add_parser("keybinds", help="show keybinds cheatsheet")
    keybinds_parser.set_defaults(cls=keybinds.Command)
    keybinds_parser.add_argument(
        "filter",
        nargs="?",
        choices=["all", "caelestia", "hypr", "custom"],
        default="all",
        help="filter the cheatsheet (default: all)",
    )

'''
    if "keybinds_parser" not in text and shell_block_end in text:
        text = text.replace(shell_block_end, shell_block_end + keybinds_block)

    if text == original:
        print("No changes needed or patch already applied.")
        return False

    path.write_text(text, encoding="utf-8")
    print(f"Patched {path}")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path/to/parser.py>")
        sys.exit(1)

    success = patch_parser(Path(sys.argv[1]))
    sys.exit(0 if success else 1)
