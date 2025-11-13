#!/usr/bin/env python3
"""
Placeholder generator disabled.

The project uses emoji-only visuals and must not create or bundle
additional image files. This script previously generated PNG
placeholders under assets/images/png/ but is intentionally disabled
to enforce the repository policy that only google_logo.png remains in
the images folder.

If you need placeholder generation for local experimentation, re-enable
or create a local, non-committed copy of a generator script.
"""
import sys


def main():
    print("generate_placeholders.py is disabled: the project uses emoji-only visuals.")
    print("No image files will be created by this script.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
