# BudgetSense: UI/UX Design Language

This document is the single source of truth for the visual identity, interaction
patterns, and experience philosophy of BudgetSense. Every color, token, and
component value here is taken verbatim from the codebase. SPEC.md references this
file for all design tokens rather than repeating them, so the two never drift.

Pair this file with SPEC.md. Together they let any developer or AI agent rebuild
BudgetSense as an identical copy.

---

## Design Philosophy

BudgetSense is designed to feel like a **quiet paper journal**, not a fintech
dashboard. The experience should be meditative rather than anxious. Users should
feel calm reviewing their finances, not stressed.

**Guiding principles:**

1. **Calm over loud.** No aggressive alerts, no red panic screens, no gamification.
2. **Paper over plastic.** Warm off-white backgrounds, fine borders, no shadows.
3. **Clarity over density.** Generous spacing, one idea per card, readable type.
4. **Honest over decorative.** Numbers are presented plainly. Motion is subtle.
5. **Accessible over beautiful.** Status is communicated with text plus icon, never color alone.

**On "addictive" beauty:** the app aims to be tactile and lovely enough that
opening it feels good. That pull comes from craft (paper grain, hand-drawn
line-art, gentle haptics, calm color), never from engagement dark patterns. There
are no streaks, no badges, no variable-reward loops, no nagging notifications.
Beauty is the honest hook; manipulation is off the table.

---

## Color System

Colors are defined once in `lib/core/theme/app_colors.dart` as an `AppColors`
`ThemeExtension`, with four concrete palettes plus six accent presets. Screens
read colors via `context.colors` (the theme extension), never hard-coded hex.

`AppThemeVariant` enum: `system, light, dark, amoled, glass`. `system` is not a
palette; it resolves to light or dark at runtime from OS brightness.

### Light Theme (`AppColors.light`)

| Role | Hex | Character |
|---|---|---|
| background | `#F3ECDE` | Warm cream paper |
| surface | `#FAF5EA` | Slightly lighter card fill |
| surfaceMuted | `#EDE6D6` | Input fill, secondary panels |
| border | `#D9D1BF` | Fine hairline separators |
| textPrimary | `#262219` | Deep warm ink |
| textSecondary | `#57534A` | Supporting copy |
| textFaint | `#8C887C` | Labels, timestamps |
| onAccent | `#FCFAF4` | Text/icons on accent fills |
| positive | `#6E8B6A` | Desaturated sage green |
| negative | `#B4675E` | Desaturated red-clay |
| warning | `#7C5E1E` | Dark ochre, WCAG AA on paper (5.1:1) |
| critical | `#A85A50` | Deeper clay |
| info | `#4A6675` | Dark slate blue, WCAG AA on paper (5.2:1) |
| glassTint | `#00000000` | Unused outside glass |
| usesBlur | `false` | not used |

Note: `warning` and `info` were darkened from earlier lighter values to meet
WCAG AA (4.5:1) for text on the cream surface. The Sand and Pale-blue *accents*
(below) keep their original lighter hexes; those are fills, not body text.

### Dark Theme (`AppColors.dark`)

| Role | Hex |
|---|---|
| background | `#23221F` (soft charcoal, never pure black) |
| surface | `#2C2B27` |
| surfaceMuted | `#34332E` |
| border | `#44423B` |
| textPrimary | `#E6E2D8` (warm grey) |
| textSecondary | `#B4B0A6` |
| textFaint | `#817E76` |
| onAccent | `#1E1D1A` |
| positive | `#8AA585` |
| negative | `#C08379` |
| warning | `#CBAE85` |
| critical | `#C57C71` |
| info | `#93AAB8` |

### AMOLED Theme (`AppColors.amoled`)

| Role | Hex |
|---|---|
| background | `#000000` (true black for OLED power savings) |
| surface | `#0A0A0A` |
| surfaceMuted | `#141414` |
| border | `#2A2A28` |
| textPrimary | `#EDEAE1` |
| textSecondary | `#AFACA3` |
| textFaint | `#6F6D66` |
| onAccent | `#000000` |
| positive | `#87A282` |
| negative | `#C08379` |
| warning | `#CBAE85` |
| critical | `#C57C71` |
| info | `#8FA7B5` |

### Glass Theme (`AppColors.glass`)

| Role | Hex |
|---|---|
| background | `#1B1F24` |
| surface | `#33FFFFFF` (translucent frosted panel) |
| surfaceMuted | `#22FFFFFF` |
| border | `#33FFFFFF` |
| textPrimary | `#F2F1EC` |
| textSecondary | `#CFCEC7` |
| textFaint | `#9B9A93` |
| onAccent | `#1B1F24` |
| positive | `#9CB697` |
| negative | `#D08E84` |
| warning | `#D6BA92` |
| critical | `#D08579` |
| info | `#9FB6C4` |
| glassTint | `#22FFFFFF` |
| usesBlur | `blurSupported` (backdrop blur sigma 18 when the device supports it; graceful fallback to the solid translucent fill otherwise) |

### Accent Presets (6 choices, `AccentPreset` enum)

| Name | Hex | Mood |
|---|---|---|
| clay | `#B07C5E` | Warm terracotta, the **default** |
| olive | `#7B7F52` | Earthy green |
| sand | `#C4A374` | Wheat, desert |
| paleBlue | `#7E97A6` | Cool, oceanic |
| ink | `#4A4A48` | Neutral charcoal |
| plum | `#8E6E7E` | Muted berry |

Accents are identical across all four themes (muted enough to work in both light
and dark). No neon, no pure blue, no corporate gradients.

### Category Color Palette (8 swatches)

Offered in the Category manager (`category_manager_screen.dart`, `static const
palette`). Distinct from the semantic palette above.

`#B07C5E`, `#7B7F52`, `#C4A374`, `#7E97A6`, `#8E6E7E`, `#6E8B6A`, `#B4675E`, `#4A4A48`

---

## Typography

Defined in `lib/core/theme/app_typography.dart`. Base scale is font-agnostic;
`withFont` overlays the chosen family in one place. Line height defaults to 1.35
(display/headline styles override to 1.2 to 1.3).

### Scale

| Style | Size | Weight | Letter spacing | Usage |
|---|---|---|---|---|
| displaySmall | 30 | w600 | 0 (height 1.2) | Balance headline |
| headlineMedium | 24 | w600 | 0 (height 1.25) | Section headers |
| headlineSmall | 20 | w600 | 0 (height 1.3) | Onboarding titles |
| titleLarge | 18 | w600 | 0 | Screen titles, card headings |
| titleMedium | 16 | w500 | 0 | Stat values, row titles |
| titleSmall | 14 | w500 | 0 | Transaction names |
| bodyLarge | 16 | w400 | 0 | Main body copy |
| bodyMedium | 14 | w400 | 0 | Secondary copy |
| bodySmall | 12 | w400 | 0 | Timestamps, meta |
| labelLarge | 14 | w500 | 0.2 | Button text |
| labelMedium | 12 | w500 | 0.3 | Chip labels |
| labelSmall | 11 | w500 | 0.4 | Tiny annotations |

Colors: primary styles use `textPrimary`; `titleSmall`, `bodyMedium`,
`labelMedium` use `textSecondary`; `bodySmall`, `labelSmall` use `textFaint`.

### Font Families (`FontChoice` enum)

| Choice | family | sizeFactor | Description |
|---|---|---|---|
| system | (platform default) | 1.0 | Clean and familiar (San Francisco / Roboto) |
| zenMaru | `ZenMaruGothic` | 1.0 | Soft rounded Japanese gothic |
| caveat | `Caveat` | 1.22 | Flowing casual handwriting |
| patrickHand | `PatrickHand` | 1.06 | Neat handwritten print |
| gochiHand | `GochiHand` | 1.08 | Relaxed marker script |
| architectsDaughter | `ArchitectsDaughter` | 1.08 | Hand-lettered blueprint style |

`isHandwritten` is true for everything except `system` and `zenMaru`. Handwritten
faces have smaller x-heights, so `sizeFactor > 1.0` nudges sizes up via
`TextTheme.apply(fontSizeFactor:)` to keep amounts legible. Picker preview line:
`Coffee  ·  ₹4.50`.

### Dynamic type

The app honors the OS font-size setting but clamps it to `[0.85, 1.4]` via
`MediaQuery.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4)` in
`app.dart`, so calm layouts never break at extreme sizes.

---

## Spacing Tokens (`Insets`)

| Token | Value | Usage |
|---|---|---|
| xxs | 2 | Micro gaps between icon and text |
| xs | 4 | Tight vertical spacing |
| sm | 8 | Between related items |
| md | 12 | Standard padding, field gaps |
| lg | 16 | Card padding, screen edge insets |
| xl | 24 | Major section breaks |
| xxl | 32 | Page-level / empty-state padding |

`Insets.card` = `EdgeInsets.all(16)`.

## Corner Radii (`Corners`)

| Token | Radius | Usage |
|---|---|---|
| sm | 6 | Chips, small badges |
| md | 10 | Cards, inputs, buttons |
| lg | 16 | Bottom sheet top corners |

Rounding is used sparingly to keep a flat-paper aesthetic with soft key points.

## Borders (`Strokes`)

- **hairline: 0.75** for card outlines, dividers, input borders
- **thin: 1.0** for focused inputs, active states

No thick borders. No drop shadows on cards. Elevation is always 0. Structure
comes from borders and background contrast alone.

## Motion (`Motion`)

| Token | Value | Usage |
|---|---|---|
| fast | 150ms | Nav-item selection, small toggles |
| base | 250ms | Theme changes, page transitions |
| slow | 400ms | Onboarding page swipes |

**Reduce motion:** when the user enables "Reduce motion" in settings (or the OS
sets it), `app.dart` forces `MediaQuery.disableAnimations = true` and theme
animation duration to `Duration.zero`. Every micro-animation checks reduce-motion
through one shared accessor, `context.reduceMotion` (a `BuildContext` extension in
`theme_resolver.dart`), and collapses its duration to zero.

**No ripple effects.** The app uses `NoSplash.splashFactory` globally. Taps are
acknowledged through subtle color shifts, not expanding ink.

---

## Paper Texture Overlay

`lib/core/theme/paper_texture.dart` wraps the entire app (in `app.dart`, above
the router) so the UI reads like ink printed on soft paper (e-ink feel). It is a
`CustomPaint` layered above content inside `IgnorePointer` + `RepaintBoundary`,
so it never affects interaction or scroll performance.

Deterministic (`Random(1974)` seed) so the grain is stable, never shimmers:

- **Flecks:** count = `width * height / 520`. Dark flecks
  `#3B342A @ 0.035` alpha; light flecks `#FFFFFF @ 0.030` alpha. Radius 0.3 to
  1.0. In dark mode 72% are light flecks; in light mode 22% are light flecks
  (the rest ink).
- **Fibres:** count = `width * height / 9000`. Short faint strokes (length 3 to
  12, random angle), color white (dark mode) or `#2B2A27` (light) at 0.018 alpha,
  strokeWidth 0.6, round cap.
- **Vignette:** radial gradient, transparent center to edge tint (black in dark
  at 0.10 alpha, `#2B2A27` in light at 0.028 alpha), stops `[0.72, 1.0]`.

Repaints only when brightness changes.

---

## Micro-delight (Phase 4)

Small tactile touches that reward use without manipulating it. All are
reduce-motion aware and rely only on the Flutter SDK (no packages, no audio).

### Confetti on "all clear" (`confetti_overlay.dart`)

When the dashboard Payments card shows "Nothing due right now. Breathe easy.",
double-tapping it rains a full-screen confetti shower: a single root `Overlay`
entry driven by one `AnimationController` and a `CustomPainter` (staggered
falling pieces, drift, spin and a fade at the end), wrapped in `IgnorePointer` so
it never blocks a tap, and it removes itself when done. For smoothness the
painter repaints straight from the controller (`CustomPainter(repaint:
controller)`) rather than an `AnimatedBuilder`, so there is no per-frame widget
rebuild or painter allocation, it reuses a couple of hoisted `Paint` objects
instead of allocating per piece, sits under a `RepaintBoundary`, and marks the
layer `willChange` so the raster cache leaves it alone. Hand-rolled, no package,
no assets, and a no-op when `disableAnimations` is set. A confirm haptic fires
alongside it. A quiet reward for reaching a clear month.

### Quick add card (`dashboard/quick_add_card.dart`)

An accent-washed, collapsed-by-default card under the balance, carrying a faint
app-mark as light branding that bleeds off the bottom-right corner and sits
behind the content (a nonchalant flourish, kept clear of the header chevron so it
never reads as a halo around the arrow). It is the calm "just get it done" path: expense name,
amount and category, always dated today. Inputs sit on a legible surface panel so
text stays readable on the accent (WCAG contrast); the header uses `onAccent`.

### Animated bottom-nav selection (`app_shell.dart`)

The selected tab item animates:

- `AnimatedScale` to `1.12` (unselected `1.0`), curve `Curves.easeOut`.
- Icon color via `TweenAnimationBuilder<Color?>` with `ColorTween` from
  `textFaint` to `accent`.
- Label color via `AnimatedDefaultTextStyle`.
- Duration `Motion.fast`, or `Duration.zero` when `disableAnimations`.

### Section transition (`app_shell.dart`)

Moving between the five sections (by horizontal swipe over the content, or by
tapping the bottom bar) plays one subtle, calming transition rather than an
abrupt `IndexedStack` swap:

- A single `AnimationController` (`Motion.base`) drives an incoming
  fade (opacity `0.35 -> 1.0`) and a short directional slide
  (`26px -> 0`, from the right when advancing, from the left when going back),
  eased with `Curves.easeOutCubic`.
- The direction is derived from the change in `currentIndex` in
  `didUpdateWidget`, so swipe and tap feel identical.
- Honors reduce-motion: when `disableAnimations` is set the controller jumps
  straight to the resting state (no fade, no slide).
- The swipe fling threshold is a gentle `220 px/s`; the dashboard month header
  and the expenses filter chips still win horizontal drags in their own area.

### Haptics

All haptic feedback goes through one helper, `Haptics` (`core/utils/haptics.dart`),
so the app speaks a single, consistent tactile language and every buzz can be
tuned or silenced from one place. Following Android's haptics principles, it is
deliberately restrained: feedback confirms a meaningful, discrete moment the user
caused, and stays silent otherwise (never on scroll, never decorative).

The vocabulary is semantic, not raw impact strengths, so call sites say what
happened rather than how hard to buzz:

- `Haptics.selection()` (a light tick): moving between discrete choices. Bottom-nav
  tab switch, month change, opening/closing a collapsible card, the dashboard eye
  toggle, choosing a chip, toggling a switch, each new step of `CalmSlider`, and
  the primary `CalmFab` press.
- `Haptics.confirm()` (a soft light impact): a small action landed. Saving a
  transaction, restoring from trash, a completed backup or restore, sending a
  test reminder.
- `Haptics.impact()` (a firmer medium pulse, used sparingly): a weightier or
  destructive commit. Moving an item to trash, emptying the trash, deleting for
  good.
- `Haptics.warning()` (the strongest, rare): reserved for genuine errors.

Everything is gated by `Haptics.enabled`, which mirrors the **Haptic feedback**
setting (Appearance). The app keeps the flag in sync on every settings change, so
turning haptics off makes every call an instant no-op. Turning it on gives one
confirming tick; turning it off is silent (no parting buzz).

On Android the feedback is driven **natively** through a `Vibrator` method
channel (`com.budgetsense.budgetsense/haptics`) rather than Flutter's
`HapticFeedback`. This matters: `HapticFeedback` routes through
`View.performHapticFeedback`, which a lot of Android devices render as nothing,
or ignore when the system "touch vibration" toggle is off, so the buzzes were
effectively invisible. The native side uses `VibrationEffect.createOneShot` with
an explicit amplitude (falling back to `DEFAULT_AMPLITUDE` when the motor has no
amplitude control, and to the deprecated `vibrate(ms)` on API 24 to 25) tagged
with `USAGE_TOUCH` on API 33+. Predefined effects (`EFFECT_TICK` etc.) were
deliberately avoided because they are silent no-ops on many OEM devices. Durations
scale with weight (selection 20ms, confirm 30ms, impact 45ms, warning is a short
double-tap waveform), raised further on manufacturers known to ship
higher-threshold motors (Motorola, reported silent even at our normal tuning).
Because these are direct `Vibrator` calls, they are not
gated by the system touch-feedback toggle, so they fire on any device with a
motor. Every other platform, and any channel failure, falls back to
`HapticFeedback` (which is excellent on iOS via the Taptic engine).

### Sound

Intentionally none. Silence is calmer, and there is no audio dependency.

---

## Component Patterns

Defined in `lib/features/common/calm_widgets.dart` unless noted.

### CalmCard
Foundational surface: `surface` fill, hairline `border`, 10px radius, 16px
padding, no shadow, elevation 0. In the Glass theme it wraps content in a
`BackdropFilter` (blur sigma 18) when blur is supported, else the solid
translucent fill. When given `onTap`, it wraps in `Semantics(button: true)` +
`InkWell`.

### CollapsibleCard
A `CalmCard` with a tappable header (title, optional collapsed-state trailing
`subtitle`, and a rotating `expand_more` chevron) that expands/collapses its body
with `AnimatedSize`. Used on the dashboard so secondary sections ("Where it went",
"Rates", "Payments") stay collapsed by default, keeping the home screen calm.
Tapping gives a selection haptic.

### Hidden amounts (dashboard eye-toggle)
The dashboard balance card keeps the balance always visible but hides Income /
Spent / Invested behind a heavy blur (`ImageFilter.blur`, sigma 14, genuinely
unreadable, not merely dimmed) until the user taps the eye icon
(`visibility_off_outlined` / `visibility_outlined`). Blurred figures are wrapped
in `ExcludeSemantics` and covered by a "Amounts hidden" semantics label so screen
readers never leak the value. The reveal state is session-scoped.

### StatTile
Label-value pair for grids: optional leading icon (14px, `textFaint`), label
(`labelMedium`), value (`titleMedium`, optionally colored). Wrapped in
`Semantics(label: "<label>: <value>")`.

### CalmProgressBar
Horizontal usage bar: 8px height, fully rounded, `surfaceMuted` track,
contextual fill color, display clamped to 0 to 100% (value may exceed logically),
`Semantics(value: "N%")`.

### CalmEmptyState
Warm empty state: centered, `titleMedium` title, `bodyMedium` message. Shows
either a hand-drawn line-art illustration (preferred) or a Material icon
fallback:

- `illustration` (optional `CalmIllustration` enum: `sprig`, `journal`,
  `wallet`, `calendar`, `coin`, `chart`, `enso`). When set, renders a 76x76
  `CustomPaint`.
- `icon` (default `Icons.spa_outlined`, 40px, `textFaint`). Used when no
  illustration is given, so error states and existing call sites are unchanged.

The line-art (`_CalmIllustrationPainter`) is authored in a 72x72 space and scaled.
Each motif is quiet ink strokes (`textFaint` 1.8 wide, plus a softer
`textFaint @ 0.55` 1.4 wide) with a single clay `accent` dot:

- **sprig:** a curving stem with three almond leaves and an `accent` bud.
- **journal:** an open book (two page paths meeting at a spine) with ruled lines.
- **wallet:** a rounded billfold with a fold-over flap and an `accent` clasp.
- **calendar:** a grid with two hanging rings, day ticks and an `accent` day.
- **coin:** a face-on coin stacked over a back-rim oval, with an `accent` glint.
- **chart:** two axes with a gently rising line to an `accent` high point.
- **enso:** a single near-closed brush ring (the mark that names the app) with
  an `accent` bead where the brush lifts. The arc is drawn by the shared
  `paintEnsoRing` helper (see `brand_watermark.dart`), so the illustration and
  the watermark stay one motif, not two.

Wired usage: Expenses uses `wallet`; Recurring-payments uses `calendar`; Loans
use `coin`; Trash uses `sprig`; Categories use `sprig`; Thresholds use `chart`;
Custom fields use `journal`; Reference lists use `coin`. The Insights all-zero
state uses `chart`, and the first-run / empty-month Dashboard uses `enso` (the
single most-seen empty state, so it gets the nicest motif). Error states still
fall back to a Material icon.

### BrandWatermark
Lays a very faint `enso` mark (default 4.5% opacity, 240px) behind a screen's
content, bleeding off a corner as quiet brand texture. It is wrapped in
`IgnorePointer` + `ExcludeSemantics` so it never intercepts touches or reaches
screen readers, and it colours from `textPrimary` so it reads on light, dark,
AMOLED and glass alike. Currently placed behind the Insights reports only; the
Dashboard was deliberately left clean (no per-card or per-screen watermark).
Shares `paintEnsoRing` with the empty-state `enso` motif.

### CalmFab
Circular FAB: flat (elevation 0), `accent` fill, `onAccent` icon, `CircleBorder`.
Each screen supplies its own icon and action.

### CalmSlider
A `Slider` that emits `Haptics.selection()` on each new step.

### ShimmerBlock / DashboardSkeleton
Loading placeholders. `ShimmerBlock` animates a 1200ms gradient sweep between
`surfaceMuted` and `surface`. `DashboardSkeleton` composes blocks into the
dashboard shape while data loads.

### MonthNavigator
Left/right chevrons plus a centered month label. Tapping the label (when not the
current month) resets to today; a `Icons.today` accent glyph appears when off the
current month. Chevron and reset taps fire selection haptics. The "next" chevron
is disabled on the current month.

### Bottom Sheets
All editors (quick add, payment, loan, category, threshold, custom field) use
bottom sheets: drag handle, 16px top corners, scrollable content, full-width save
button, keyboard-aware padding, safe area respected.

### Bottom Navigation (`app_shell.dart`)
`BottomAppBar`, 64px height, elevation 0, `surface` color, hairline top border.
Five tabs, each `Expanded`, with **icon plus text label**:

1. Dashboard: `Icons.dashboard_outlined`
2. Expenses: `Icons.receipt_long_outlined`
3. Payments: `Icons.event_repeat_outlined`
4. Insights: `Icons.insights_outlined`
5. Settings: `Icons.settings_outlined`

Selected uses `accent`, unselected `textFaint`, with the animated scale/color
described above. Each `_NavItem` is `Semantics(button: true, selected: ...,
label: ...)`. Tapping the active tab pops that branch to its root. There is **no
center FAB**; each screen provides its own FAB (Payments uses a
`FloatingActionButton.extended`).

---

## App Icon

The app icon is a bespoke **ensō**, a single hand-inked brush circle (espresso
ink `#262219`) with a small terracotta clay dot (`#B07C5E`) at the brush-lift gap,
pressed into warm cream letterpress paper. Calm, editorial, unmistakably not
fintech. It ships as committed raster PNGs at each required density, not vectors.

- **Default (`mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml`):** an
  adaptive icon whose background is the warm cream paper colour
  (`@color/ic_launcher_background`, `#F5EAD1`) and whose foreground is the
  transparent ensō mark (`@mipmap/ic_launcher_foreground`, 108-432px),
  **safe-zoned** so the launcher mask never clips the brush circle. Legacy
  `mipmap-*/ic_launcher.png` (square) and `ic_launcher_round.png` (disc) carry the
  same cream-plus-ensō art for pre-API-26 devices.
- **iOS:** `AppIcon.appiconset` is the same opaque art at every required size.

There is **one** launcher icon, with no user-selectable variants. Every icon (Android
adaptive/legacy/round + iOS) is a committed raster PNG at each required density,
so the mark is identical and crisp on every density and platform.

**Centring.** The dot juts well to the right of the ring, so centring the mark's
full bounding box would shove the ring off to the upper-left (a bug we hit). The
generator instead isolates the ring (the largest connected blob, via SciPy) and
puts *its* geometric centre at the icon centre, sizing the square so the dot still
fits with symmetric padding. The ring lands dead-centre with the dot floating in
its gap. The adaptive foreground fills ~64% of the canvas so the whole mark, dot
included, stays inside the launcher-mask safe zone.

### In-app branding

The ensō mark carries the identity inside the app: it sits as the header on the
About screen and the onboarding welcome page, quiet on the paper surface.

The mark is two-colour (an ink ring plus a terracotta dot), so it ships as a
light/dark pair and is chosen with `BrandMarks.of(context)` from
`core/constants/branding.dart`, because espresso ink would be invisible on a dark
surface. Single-colour brand decoratives ship instead as alpha masks and are
tinted at draw time through `BrandMarks.tinted`, so one file serves every theme.
See [Branding](branding.md).

---

## Home-screen Widgets

Three Android widgets share a paper look via `res/values/colors.xml` (light) and
`res/values-night/colors.xml` (dark, follows the **system** dark setting, not the
in-app theme). Shape drawables reference `@color/widget_*`, so they re-theme for
free.

Widget palette (light / night):

| Token | Light | Night |
|---|---|---|
| widget_paper | `#FAF5EA` | `#2C2B27` |
| widget_paper_alt | `#F3ECDE` | `#23221F` |
| widget_ink | `#262219` | `#E6E2D8` |
| widget_ink_soft | `#5C574A` | `#B4B0A6` |
| widget_ink_faint | `#8C887C` | `#817E76` |
| widget_border | `#E0D8C6` | `#44423B` |
| widget_accent | `#B07C5E` | `#B07C5E` |
| widget_positive | `#5B7A5B` | `#8AA585` |
| widget_negative | `#A8574B` | `#C08379` |
| widget_on_accent | `#FBF6EE` | `#1E1D1A` |

The three widgets: **Dashboard** (balance + income/spend/invested, breakdown
revealed when tall), **Insights** (income/expenses, rates + projection when
tall), **Quick Add** (a static "Add expense" button that deep-links into the
quick-add sheet). See SPEC.md for the data bridge and layout details.

---

## Interaction Patterns

### Transactions (Expenses screen)
- **Leading icon.** Each row shows a circular icon: the transaction's own icon,
  else its category icon, else a neutral fallback, tinted by the category color.
- **Tap** opens the edit sheet.
- **Long press** enters multi-select mode (checkbox UI, count in the app bar).
- **Swipe** (endToStart) moves the item to the Trash (soft delete), with a
  10-second "Moved to Trash" Undo snackbar. Nothing is destroyed on swipe.
- **Popup menu** for edit / duplicate / move to trash. Duplicate makes a copy
  with a new id and current timestamp.
- **Trash** (Settings > Data > Trash) lists soft-deleted items to restore or
  delete forever, and survives backup/restore.
- Search field, horizontal type filter chips (All + each `TransactionType`),
  sort popup (newest, oldest, amount high-low, amount low-high), group-by-date
  toggle.

### Payments and Loans
- **Tap** opens the editor sheet (recurring). Loans are **expandable cards**:
  tapping the header expands to reveal the last EMI (amount + date + time), a
  custom-amount field (blank = the EMI), a date/time picker (defaults to now), a
  "Record EMI" button and an "Edit loan" link. Collapsed by default so the tab
  stays calm.
- **"Mark paid"** (recurring) acts inline with a confirmation snackbar, and is
  the only thing that ever turns a commitment into a real transaction. Nothing
  posts itself: a SIP, rent or subscription that came due while the app was
  closed does not become an expense on next launch. Launch only rolls the
  schedule forward so the due date is never stale, and the list shows the
  current period's occurrence.
- **Recording an EMI** (loan) writes a loan-payment transaction (custom or EMI
  amount, clamped to what is owed) and updates the outstanding balance inline.

### Category Management
- **Drag handle** reorders (`ReorderableListView`).
- **Tap** opens the color/icon editor: an 8-swatch palette and a searchable icon
  picker over the ~200-icon `kCategoryIcons` library. The icon auto-suggests from
  the category name as you type (Splitwise-style), and you can override it.
- **Popup menu** for set-default / archive / delete.
- **Delete** prompts a replacement picker if the category is in use.

### Settings
- Changes save **immediately** on interaction (no explicit save button).
- Snackbar feedback for destructive actions only.

### Backup and restore (`backup_screen.dart`)
- **Create backup** captures everything (data + all settings, profile, theme,
  accent, font, app icon) in the chosen format: **JSON** (recommended), **CSV**
  (sectioned), or **XML**. A one-line hint describes each format; the file is
  handed to the native share sheet.
- **Restore from file** accepts any file and **auto-detects** the format. A
  preview shows what will change before you confirm: nothing is ever
  overwritten or deleted, new records are added, id collisions are appended as
  new records, and settings are merged (existing values win unless unset). On
  success it reapplies the launcher icon and shows a calm result line (records
  inserted/skipped/remapped, settings applied). Foreign files (e.g. Paisa) are
  refused with a gentle message pointing to Settings > Import.

### Onboarding (5 pages, skippable)
1. Welcome ("Hi there"): privacy promise, author credit.
2. Profile: required first name; optional nickname, age, phone, email.
3. Money: currency symbol (max 4 chars, default the rupee symbol) and financial
   month start day (1 to 28).
4. Cloud backup: an explainer for the optional encrypted Google Drive backup,
   with no control on the page. It is switched on later, in Settings.
5. Defaults: toggle to seed starter categories and thresholds.

"Maybe later" (top right) is always available; it still seeds default categories
so the app is immediately usable. Horizontal page swipe with dot indicators.

---

## Status Communication

**Critical rule:** status is NEVER communicated by color alone. Every indicator
uses at least two channels: color plus an icon or text label.

Examples:
- Threshold exceeded: `critical`/`negative` color + `Icons.error_outline` + "Exceeded".
- Threshold approaching: `warning` color + warning icon + "Approaching limit".
- Below target: `info` color + `Icons.trending_down` + "Below target".
- Overdue payment: `critical` color + error icon + "Overdue".

### Calm figures (Phase 3)

Money that could read as a verdict is deliberately kept neutral:

- **Dashboard balance** uses `textPrimary` (never red), even when negative. When
  negative, a quiet `bodySmall` caption appears in `textSecondary`: "You've spent
  a little more than you earned this month."
- **Insights projected balance** uses `textPrimary`, never alarming red. In the
  first 5 days of the current month it shows a `textFaint` caption: "This
  estimate settles after the first few days of the month." Otherwise, if the
  projection is negative: "At your current pace, spending may edge past income
  this month." (`textSecondary`).
- **Dashboard "Where it went" breakdown** is fully dynamic: it lists the month's
  top spending categories (by spend), each with the category's own icon and
  color, using the same `_bucketRow` layout (icon + label + amount). It shows a
  gentle "No categorised spending yet this month." line when there is nothing to
  break down. Nothing is hardcoded to any category name.

---

## Financial Display Conventions

- **Income:** positive (sage) color; **expenses:** negative (clay-red) color;
  **investments:** info (slate blue) color. Row amounts are colored by type.
- **Balance and projection headlines:** neutral `textPrimary` (see above).
- **Currency symbol:** always before the number, user-configurable (default the
  rupee symbol).
- **Decimal precision:** always 2 places (for example 1,234.56).
- **Thousands separator:** locale-aware (1,234.56 or 1.234,56).
- **Compact mode:** optional "1.2K" form for tight spaces (`formatCompact`).

---

## Empty States

Every list screen has a warm, encouraging empty state. Most now carry a
hand-drawn motif rather than a flat glyph; error states keep a Material icon.

| Screen | Title | Message | Visual |
|---|---|---|---|
| Dashboard (first run) | "A calm, clean slate" | "Tap the + below to log your first income or expense." | `CalmIllustration.enso` |
| Expenses | "Nothing here yet" | "Add your first transaction with the + button below." | `CalmIllustration.wallet` |
| Recurring | "No recurring payments yet" | "Add SIPs, subscriptions, rent, EMIs and more. Auto-add and reminders are supported." | `CalmIllustration.calendar` |
| Loans | "No loans tracked" | "Add a loan to track EMIs, outstanding balance and repayment progress." | `CalmIllustration.coin` |
| Insights (no data) | "Insights arrive with your first entries" | "Once you log a little income and spending, this is where your trends take shape." | `CalmIllustration.chart` |
| Trash | "Trash is empty" | "Removed transactions land here. You can restore them any time." | `CalmIllustration.sprig` |
| Categories | "No categories" | "Add your first category to organize spending." | `CalmIllustration.sprig` |
| Custom fields | "No custom fields" | "Create fields like 'Mood', 'Trip', or 'Receipt #'." | `CalmIllustration.journal` |
| Thresholds | "No thresholds" | "Add a percentage or fixed-amount limit to get gentle nudges." | `CalmIllustration.chart` |
| Reference lists | "Nothing here yet" | (per-list message) | `CalmIllustration.coin` |

---

## Dark Mode Considerations

- Dark mode uses warm charcoal (`#23221F`), never pure black (unless AMOLED).
- Text is warm grey, not stark white.
- Accent colors are identical across themes.
- Glass theme is always dark (translucent panels on a dark background).
- Android `values-night/styles.xml` uses `Theme.Black.NoTitleBar` for launch and
  normal window themes; `values/styles.xml` uses `Theme.Light.NoTitleBar`.

---

## The Journal Feel

What makes this feel like a paper journal rather than a banking app:

1. **Warm cream backgrounds** instead of clinical white or blue-grey.
2. **A subtle paper-grain overlay** on every screen (flecks, fibres, vignette).
3. **Handwritten font options** that mimic pencil on paper.
4. **Earthy, muted colors** inspired by craft paper, clay, and dried herbs.
5. **Fine hairline borders** that evoke ruled notebook lines.
6. **Generous breathing room.** Content is never crammed.
7. **Quiet outlined icons.** Never filled or bold.
8. **Hand-drawn line-art** empty states (sprig, journal, wallet, calendar, coin,
   chart, and the enso brush mark) instead of flat glyphs, plus a faint enso
   watermark behind the busier screens.
9. **Gentle haptics and a softly animated nav.** Tactile, not flashy.
10. **No gamification, no anxiety triggers.** No streaks, badges, red banners, or urgent pushes.

The user should feel like they are writing in a personal notebook, not being
judged by a financial advisor.
