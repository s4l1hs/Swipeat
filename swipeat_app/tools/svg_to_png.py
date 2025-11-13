#!/usr/bin/env python3
"""
Disabled SVG→PNG converter.

This project has switched to emoji-only visuals and does not generate or
bundle image assets. The original svg->png converter required system
dependencies (cairo) and could produce files under assets/images/png/.

To avoid accidentally creating or bundling images this script is now a
no-op that prints guidance.
"""
import sys


def main():
    print("svg_to_png.py is disabled: the project uses emoji-only visuals.")
    print("If you really need image conversion, re-enable this script locally")
    print("and ensure cairosvg plus its native dependencies are installed.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
