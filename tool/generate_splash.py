#!/usr/bin/env python3
"""Writes the launch-screen logos from the same drawing as the app icon.

    python3 tool/generate_splash.py

Run through tool/generate_splash.sh, which also rebuilds the native screens.

Writes (transparent, so the splash background shows through):

- branding/splash_logo.png         768x768, iOS and Android before 12.
                                    flutter_native_splash treats it as 4x,
                                    so it shows at 192pt / 192dp.
- branding/splash_logo_android12.png
                                    960x960, Android 12+ splash icon. The
                                    system crops it to a circle, so the bills
                                    stay inside the middle two thirds.
- assets/brand/splash_logo.png     the same 768 logo, which the app draws at
                                    192x192 on its first frame and animates
                                    away, so the hand-off from the native
                                    splash doesn't jump.
"""

from __future__ import annotations

from generate_icons import ADAPTIVE, FULL, ROOT, bills, save


def main() -> None:
    logo = bills(768, width=FULL, background=None)
    save(logo, ROOT / "branding" / "splash_logo.png")
    save(logo, ROOT / "assets" / "brand" / "splash_logo.png")
    save(bills(960, width=ADAPTIVE, background=None), ROOT / "branding" / "splash_logo_android12.png")


if __name__ == "__main__":
    main()
