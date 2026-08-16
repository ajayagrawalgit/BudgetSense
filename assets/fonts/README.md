# Bundled Fonts

All fonts here are licensed under the **SIL Open Font License 1.1 (OFL)** and
are redistributable with the app. Sourced from the Google Fonts project
(https://github.com/google/fonts).

| Family              | Files                              | Use                    |
| ------------------- | ---------------------------------- | ---------------------- |
| Zen Maru Gothic     | Regular / Medium / Bold            | Refined UI alternative |
| Caveat              | Regular (variable)                 | Flowing handwriting    |
| Patrick Hand        | Regular                            | Neat handwritten print |
| Gochi Hand          | Regular                            | Marker script          |
| Architect's Daughter| Regular                            | Blueprint hand-lettering |

The system default (San Francisco on iOS, Roboto on Android) is offered as the
first, non-bundled option in Settings → Typeface.

`OFL.txt` in this folder holds the licence text and the per-family copyright
notices taken from the font files. It is bundled as an app asset and registered
with Flutter's licence registry at startup (see `lib/main.dart`), so the notice
is reachable in the app under Settings → About → Open source licences. The OFL
requires that notice to be distributed with the fonts, so please keep the asset
entry in `pubspec.yaml` if you add or swap a typeface.

Full OFL text and FAQ: https://openfontlicense.org
