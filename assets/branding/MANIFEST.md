# Brand asset masters

The hand-authored BudgetSense artwork. **This is the only directory where brand
images are edited by hand.**

None of these files ship in the app (together they are roughly 40 MB). They are
build-time inputs to `tool/brand_assets.py`, which writes the size-optimised
derivatives that actually ship. See [`docs/branding.md`](../../docs/branding.md)
for the usage rules and the regeneration command.

Transparency and colour figures below come from a pixel-level audit of each file,
not from its filename. Several names promise things the pixels do not, so check
this table rather than trusting a name.

## In use

| Master | Transparent | Derived into |
| --- | --- | --- |
| `BudgetSense_Primary_Transparent.png` | yes, clean alpha | The light logo, the launcher tile, the adaptive foreground, the light splash mark |
| `Dark_Background_Hero_BudgetSense_Logo_Transparent.png` | yes, clean alpha | The dark logo, the dark splash mark, the social card |
| `BudgetSense_Flaticon_Transparent.png` | yes, clean alpha | The compact mark, every favicon, the maskable PWA icon |
| `BudgetSense_BrushStroke_withoutDot_Transparent.png` | yes, clean alpha | `budgetsense-enso-ring` (loading, clean-slate empty state) |
| `Light_Theme_BudgetSense_App_Icon.png` | no, baked cream | The monochrome/themed icon layer and the notification silhouette, via luminance masking |
| `Leaf_Branding_BudgetSense.png` | yes, clean alpha | `budgetsense-botanical` |
| `Meditative_Enso_with_Terracotta_Accent_BudgetSense.png` | yes, clean alpha | `budgetsense-milestone` |
| `Horizontal_Brush_Stroke_Divider_BudgetSense.png` | yes, clean alpha | `budgetsense-divider-espresso`, and the site divider |
| `Short_Terracota_Underline_BudgetSense.png` | yes, clean alpha | `budgetsense-underline-terracotta` |
| `Sweeping_Espresso_Ink_Waves_BudgetSense.png` | yes, clean alpha | `budgetsense-waves` |
| `Budgetsense_Seal_Transparent.png` | yes, clean alpha | `budgetsense-seal-terracotta` |
| `Dark_Espresso_Paper_Texture_Background_BudgetSense.png` | no, baked espresso | The social card's paper field |
| `Dark_Theme_BudgetSense_App_Icon.png` | no, baked espresso | Documentation preview only |

## Held in reserve

Genuine, on-brand artwork that no current surface calls for. Kept because it is
part of the family, not because it is unused by mistake.

| Master | Transparent | Note |
| --- | --- | --- |
| `BudgetSense_for_DarkBackground_Transparent.png` | yes, cream ink | A second cream logo. The hero variant is used instead; this one is squarer |
| `Enso_with_Leaf_BudgetSense_Transparent.png` | yes | Ensō with a botanical detail |
| `Enso_Terracota_Pattern_Budgetsense_Transparent.png` | yes, sparse | A repeating field. Would need very low opacity to stay calm |
| `Terracota_BudgetSense_Dot.png` | yes | The dot enlarged as its own motif |
| `Circular_Sticker_BudgetSense_Light.png` | yes, cream disc | A badge/sticker treatment |
| `Dark_Background_EnsoArc_BudgetSense.png` | no, baked espresso | An arc accent on a dark field |
| `Cream_Paper_Texture_Background_BudgetSense.png` | no, baked cream | The light counterpart of the espresso texture |
| `Splash_Screen_BudgetSense_Dark.png` | no, baked espresso | A pre-composed portrait splash. Not used: the splash is assembled from a colour plus a mark so it adapts to any screen shape |

## Cautions

- The six baked-background files above have **no usable alpha**. Compositing one
  over a coloured surface produces a visible rectangle. Only the files marked
  transparent are safe as overlays.
- Espresso-ink artwork is invisible on espresso; cream-ink artwork is invisible on
  cream. Pair the ink to the surface.
- Do not hand-edit anything under `derived/`. Change the recipe in
  `tool/brand_assets.py` and re-run it.
