---
name: ParkourSpot
description: Community atlas for discovering, sharing, and trusting parkour spots worldwide.
colors:
  seed: "#007FA8"
  primary: "#186584"
  on-primary: "#FFFFFF"
  primary-container: "#C1E8FF"
  on-primary-container: "#004D67"
  secondary: "#4E616C"
  surface: "#F6FAFE"
  on-surface: "#171C1F"
  on-surface-variant: "#40484D"
  surface-container-low: "#F0F4F8"
  surface-container-highest: "#DFE3E7"
  outline: "#71787D"
  outline-variant: "#C0C7CD"
  error: "#BA1A1A"
typography:
  display:
    fontFamily: "Fredoka, system-ui, sans-serif"
    fontWeight: 600
    lineHeight: 1.2
  headline:
    fontFamily: "Fredoka, system-ui, sans-serif"
    fontWeight: 600
    lineHeight: 1.25
  title:
    fontFamily: "Fredoka, system-ui, sans-serif"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Fredoka, system-ui, sans-serif"
    fontWeight: 400
    fontSize: "16px"
    lineHeight: 1.5
  label:
    fontFamily: "Fredoka, system-ui, sans-serif"
    fontWeight: 600
    fontSize: "16px"
    lineHeight: 1.4
rounded:
  sm: "8px"
  md: "12px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "28px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    padding: "16px 24px"
    height: "56px"
  button-primary-disabled:
    backgroundColor: "{colors.surface-container-highest}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "16px 24px"
    height: "56px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "16px 24px"
    height: "56px"
  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "16px"
  quick-action-chip:
    backgroundColor: "{colors.surface-container-highest}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "8px 12px"
    height: "40px"
  spot-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.md}"
    padding: "0px"
---

# Design System: ParkourSpot

## 1. Overview

**Creative North Star: "The Community Atlas"**

ParkourSpot is a map-first community tool used at home and on the move. The visual system should feel like a trustworthy atlas the community owns: warm enough to invite contribution, clear enough to read outdoors, energetic without hype. Material 3 provides the scaffolding; Fredoka gives the product a friendly, sport-native voice; the `#007FA8` seed anchors every accent to cool coastal teal that reads as water, sky, and open movement rather than corporate SaaS blue.

Hierarchy comes from tonal surfaces (`surface`, `surfaceContainerLow`, `surfaceContainerHighest`) and typographic weight, not decorative chrome. Maps, photos, ratings, and spot metadata stay scannable. Admin and moderator surfaces inherit the same vocabulary so trust carries through every task.

The system explicitly rejects cold corporate product aesthetics, extractive paywall patterns, and artificial scarcity cues. It should never feel like an outside company "about" parkour. Core discovery stays visually open.

**Key Characteristics:**

- Material 3 with `ColorScheme.fromSeed` (`#007FA8`), light and dark themes following system preference
- Single type family (Fredoka) across display through label roles
- 12px radius on primary interactive surfaces; 8px on compact nested elements
- Tonal layering over heavy shadow stacks
- 56px primary touch targets; 40px minimum for compact chips and app bar controls
- 1200px max content width, 16px page padding, centered on wide viewports
- Semantic color from `Theme.of(context).colorScheme`; one-off colors only for true semantics (error, access states)

## 2. Colors

A restrained coastal teal palette: one seed accent on a cool neutral surface family, with Material 3 generating light and dark tonal ramps automatically.

### Primary

- **Coastal Teal Seed** (`#007FA8`): The explicit brand anchor passed to `ColorScheme.fromSeed`. Use as the seed reference, not as a hand-painted fill on arbitrary widgets.
- **Training Teal** (`#186584` light / `#8ECFF2` dark): Generated `primary`. Primary buttons, map pin accents, selected radios, focused input borders, key wayfinding icons.
- **Mist Container** (`#C1E8FF` light / `#004D67` dark container): `primaryContainer`. Intro panels, upcoming-event callouts, feature chip washes at low alpha (0.1–0.35).

### Secondary

- **Slate Trail** (`#4E616C` light / `#B5C9D7` dark): Generated `secondary`. Supporting accents when a second hue is needed; defer to primary for actions.

### Neutral

- **Atlas Surface** (`#F6FAFE` light / `#0F1417` dark): `surface`. Page backgrounds, filled input backgrounds.
- **Ink Body** (`#171C1F` light / `#DFE3E7` dark): `onSurface`. Primary reading text.
- **Muted Caption** (`#40484D` / `#C0C7CD`): `onSurfaceVariant`. Secondary labels, table cell text, metadata.
- **Shelf Low** (`#F0F4F8` / `#171C1F`): `surfaceContainerLow`. Table header bands, subtle row backgrounds.
- **Shelf High** (`#DFE3E7` / `#313539`): `surfaceContainerHighest`. Disabled button fills, chip backgrounds, image placeholders.
- **Trail Outline** (`#71787D` / `#8A9297`): `outline`. Default input borders at 50% alpha when enabled.
- **Trail Outline Soft** (`#C0C7CD` / `#40484D`): `outlineVariant`. Table dividers, comparison grid borders.

### Named Rules

**The One Accent Rule.** Primary teal appears on actions, selection, and wayfinding only. It should occupy ≤10% of any screen. Its rarity signals importance; do not flood panels with `primaryContainer` unless the content is genuinely highlighted (intro callouts, event panels).

**The Scheme-Only Rule.** Extend `Theme.of(context).colorScheme` and shared widgets (`CustomButton`, `CustomTextField`). Do not hardcode hex fills except the seed constant in theme setup and documented semantic exceptions (access chip colors).

## 3. Typography

**Display Font:** Fredoka (via `google_fonts`, system-ui fallback)
**Body Font:** Fredoka (same family; no separate body pairing)
**Label Font:** Fredoka semibold for controls

**Character:** Rounded, approachable, sport-native. One family keeps the product feeling cohesive and community-made rather than split between "marketing display" and "tool UI." Weight and Material type roles carry hierarchy.

### Hierarchy

- **Display** (600, `headlineLarge`/`displaySmall`, 1.2): Splash moments, hero spot titles on detail. Rare; do not stack multiple display sizes on one screen.
- **Headline** (600, `titleLarge`, 1.25): Page titles in `PageScaffold`, result preview names, section headers that anchor a view.
- **Title** (600, `titleMedium`/`titleSmall`, 1.3): Card titles, spot names in lists, table column headers, comparison option labels.
- **Body** (400, 16px, 1.5): Descriptions, form content, intro summaries. Cap prose blocks at 65–75ch where width allows; admin tables may run denser.
- **Label** (600, 16px on primary buttons, `labelLarge` elsewhere): Button labels, chip text, field labels, grid row labels.

### Named Rules

**The Fredoka Unity Rule.** Do not introduce a second UI sans for buttons, labels, or data. If a monospace is ever needed (IDs, coordinates), use it only for inline code-like values, never for navigation or actions.

## 4. Elevation

ParkourSpot is predominantly **tonal, not shadow-driven**. Depth is conveyed by `surface` → `surfaceContainerLow` → `surfaceContainerHighest`, outline borders at 35% alpha, and primary container washes. Shadows are a secondary signal for floating map cards and primary buttons at rest.

### Shadow Vocabulary

- **Button rest** (`elevation: 2` on filled `CustomButton`): Lifts primary actions slightly off the page surface.
- **Map/list card** (`elevation: 2` on `SpotCard`/`EventCard` list variant): Separates scrollable results from the map without heavy drop shadows.
- **App bar** (`elevation: 0`): Full-width Material tint only; toolbar content constrained to 1200px.

### Named Rules

**The Flat Chrome Rule.** App bars, dividers, and table grids stay flat. Shadows appear on actionable floats (buttons, cards over maps), not on every container. If a surface reads as a "card" only because of shadow, prefer a 1px `outlineVariant` border or tonal background instead.

## 5. Components

### Buttons (`CustomButton`)

- **Shape:** Gently rounded (12px radius), 56px height, optional full-width via `width`
- **Primary:** `primary` fill, `onPrimary` text, 16px/600 label, optional leading icon (20px) with 8px gap
- **Outlined:** Transparent fill, 2px `primary` border, `primary` text, zero elevation
- **Disabled / loading:** `surfaceContainerHighest` fill (filled) or transparent (outlined); foreground via alpha-blended `onSurface` for WCAG-safe muted state; 24px spinner
- **Hover / Focus:** Inherit Material `ElevatedButton` states; do not custom-animate layout

### Chips

- **Feature / good-for chips:** `primaryContainer` at 10% alpha, `onPrimaryContainer` text, 16px avatar icon in `primary`, Material `Chip` compact density
- **Quick action chips (`SpotDetailQuickActionChip`):** `surfaceContainerHighest` at 45% alpha, 1px outline at 35% alpha, 12px radius, min height 40px, horizontal 12px / vertical 8px padding, `labelLarge` text
- **Access chips:** Semantic pastels (green/orange/blue) for access level; default falls back to `surfaceContainerHighest`

### Cards / Containers

- **Corner style:** 12px on list cards and surfaced detail blocks; 8px on thumbnails and nested media
- **Background:** `surface` for `Card`; `primaryContainer` washes for informational callouts
- **Shadow strategy:** Elevation 2 on list cards over explore; bordered containers (`outlineVariant`) for comparison tables and admin grids
- **Border:** `SpotDetailUi.outlineBorder` (1px, `outline` at 35% alpha) for chips and community panels
- **Internal padding:** 16px horizontal standard (`SpotDetailUi.contentHorizontalPadding`); detail cards 16×14px

### Inputs / Fields (`CustomTextField`)

- **Style:** Filled `surface`, 12px outline border, 16px padding, 16px input text
- **Focus:** 2px `primary` border on `focusedBorder`
- **Error:** `error` border, 2px when focused
- **Labels / hints:** `onSurface` at 70% / 50% alpha

### Navigation (`PageScaffold`)

- **App bar:** M3 `AppBar`, zero elevation, centered 1200px toolbar, `BackButton` leading, title `titleMedium` ellipsis
- **Page body:** 16px padding, centered `maxWidth: 1200`, scrollable by default
- **Mobile:** Same structure; touch targets prioritized over density

### Map overlay cards (`SpotCard` / `EventCard` overlay variant)

- **Character:** Photo-forward floaters over the map; pointer-intercepted for web
- **Shape:** 12px radius, elevation 2, image carousel with horizontal paging
- **Actions:** Quick chips and icon buttons aligned to spot detail patterns

## 6. Do's and Don'ts

Concrete guardrails for AI-generated and hand-built UI. Strategic anti-references from PRODUCT.md are enforced here visually.

### Do:

- **Do** use `ColorScheme.fromSeed(seedColor: #007FA8)` and read roles from `colorScheme` at runtime
- **Do** use `CustomButton` and `CustomTextField` for primary actions and form fields
- **Do** keep primary actions at 56px height and chips at ≥40px touch height
- **Do** center content at 1200px max width with 16px padding on admin and detail pages
- **Do** route all user-facing strings through `AppLocalizations` and allow flexible layout for long translations
- **Do** use tonal surfaces (`surfaceContainerLow`, `surfaceContainerHighest`) to separate table headers, excluded rows, and disabled states
- **Do** respect reduced-motion preferences as motion patterns are added

### Don't:

- **Don't** make the product feel like a cold corporate tool or a money grab; avoid stock SaaS hero layouts, fake urgency, or premium lock icons on core discovery
- **Don't** visually gate the map or spot list behind login walls, blur overlays, or "upgrade to see" patterns; core discovery stays open
- **Don't** invent one-off hex colors when a `colorScheme` role or semantic constant exists
- **Don't** use `border-left` or `border-right` greater than 1px as a colored accent stripe on cards, rows, or callouts
- **Don't** use gradient text, decorative glassmorphism, or neon-on-black crypto aesthetics
- **Don't** truncate admin comparison text when full values are needed for moderator decisions; prefer full-width stacked layouts for long fields
- **Don't** brittle-fix row heights or label widths that break in `de`, `nl`, or `pt` locales
- **Don't** add orchestrated page-load animation sequences; motion should convey state change only
