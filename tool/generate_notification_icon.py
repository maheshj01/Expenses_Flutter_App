#!/usr/bin/env python3
"""Writes Android's status-bar notification icon from the app icon drawing.

    python3 tool/generate_notification_icon.py

Android draws it as a silhouette (only the alpha counts), 24dp with 2dp of
air, so it uses the one-colour version of the bills from generate_icons.py.
AndroidManifest.xml points FCM at it (default_notification_icon).
"""

from __future__ import annotations

import os

from generate_icons import ROOT, monochrome, save


def main() -> None:
    res = ROOT / "android/app/src/main/res"
    for name, factor in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        save(monochrome(round(24 * factor), width=20 / 24), res / f"drawable-{name}/ic_notification.png")


if __name__ == "__main__":
    os.chdir(ROOT)
    main()
