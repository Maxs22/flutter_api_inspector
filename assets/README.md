# Release media

The `demo-*.png` files show the real Flutter `example/` Android app with the
0.4.0 inspector. They are native `adb exec-out screencap -p` captures from a
Pixel 6 Pro emulator (Android 16 / API36, 1440×3120), not HTML prototypes or
widget-test renders. Requests use the example's offline stubs; no customer or
production data is shown. Captured 2026-11-13.

## Reproduce

1. Run `flutter pub get` and `flutter run` from `example/` with an Android target.
2. Tap **Run stub call** on Home, navigate to Detail and run its stub call.
3. Open the inspector's bottom-right launcher. Resize the panel using the
   bottom handle so both request cards are visible; let the host SnackBar expire.
4. Capture Timeline, Routes, the `/detail` endpoint list, and its request detail.
5. Save each screenshot with `adb exec-out screencap -p > <file>.png`.

The example host retains its own Material icons and typeface. Only the inspector
uses bundled Lucide, Inter and JetBrains Mono. Light/dark Flutter widget renders
were also checked locally but are not passed off as device screenshots.

`demo.gif` is a historical 0.3.4 recording. It is intentionally no longer embedded
in the README because it does not show the current UI. It is retained for history,
not presented as evidence of 0.4.0.
