#!/usr/bin/env python3
"""Fetch public-domain images from Wikimedia Commons for a small set of food terms.

For each term this script will:
 - Query the Commons API for File: pages matching the term (namespace=6)
 - Look for an image whose extmetadata indicates a public-domain or CC0 license
 - Download the image and convert it to PNG
 - Save it to ../assets/images/png/<term>.png

This script attempts to be conservative about licenses but you should verify the
selected images manually before redistribution.
"""
import json
import os
import sys
import shutil
from io import BytesIO

try:
    import requests
except Exception:
    print("requests not installed, attempting to install...")
    os.system(f"{sys.executable} -m pip install requests")
    import requests

try:
    from PIL import Image
except Exception:
    print("Pillow not installed, attempting to install...")
    os.system(f"{sys.executable} -m pip install pillow")
    from PIL import Image


TERMS = [
    ("avocado", "Avocado"),
    ("apple", "Apple"),
    ("banana", "Banana"),
    ("bread", "Bread"),
    ("chicken", "Chicken"),
    ("salad", "Salad"),
]

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "png")
os.makedirs(OUT_DIR, exist_ok=True)

#!/usr/bin/env python3
"""No-op fetcher: this project uses emoji-only visuals.

Historically we had a script here to download public-domain images from
Wikimedia Commons. Per project policy we no longer fetch images from the
network; instead we render emoji-based visuals. This script now simply
prints instructions and exits so CI or local runs don't accidentally
pull images.
"""
import sys


def main():
    print("fetch_wikimedia_pd.py is disabled: this project uses emoji-only visuals.")
    print("To regenerate emoji PNG placeholders, run: python3 tools/generate_placeholders.py")
    return 0


if __name__ == '__main__':
    sys.exit(main())