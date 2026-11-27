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

<!-- impeccable:design-map -->
Name: ParkourSpot
Colors: primary: seed #007FA8; neutral: surface #F6FAFE; semantic: error #BA1A1A; primary: primary #186584; primary: primary-container #C1E8FF; neutral: on-surface #171C1F (+1 more in the sidecar)
Fonts: Fredoka (display, headline, title, body, label)
Spacing: xs 8px, sm 12px, md 16px, lg 24px, xl 28px
Radius: sm 8px, md 12px
North Star: "The Community Atlas"
Rules:
- The One Accent Rule. Primary teal appears on actions, selection, and wayfinding only.
- The Scheme-Only Rule. Extend `Theme.of(context).colorScheme` and shared widgets (`CustomButton`, `CustomTextField`).
- The Fredoka Unity Rule. Do not introduce a second UI sans for buttons, labels, or data.
- The Flat Chrome Rule. App bars, dividers, and table grids stay flat.
Elevation:
- Button rest: elevation: 2
- Map/list card: elevation: 2
- App bar: elevation: 0
Don't:
- Don't make the product feel like a cold corporate tool or a money grab; avoid stock SaaS hero layouts, fake urgency, or premium lock icons on core discovery
- Don't visually gate the map or spot list behind login walls, blur overlays, or "upgrade to see" patterns; core discovery stays open
- Don't invent one-off hex colors when a `colorScheme` role or semantic constant exists
- Don't use `border-left` or `border-right` greater than 1px as a colored accent stripe on cards, rows, or callouts
- Don't use gradient text, decorative glassmorphism, or neon-on-black crypto aesthetics
- Don't truncate admin comparison text when full values are needed for moderator decisions; prefer full-width stacked layouts for long fields
- Don't brittle-fix row heights or label widths that break in `de`, `nl`, or `pt` locales
- Don't add orchestrated page-load animation sequences; motion should convey state change only
Do:
- Do use `ColorScheme.fromSeed(seedColor: #007FA8)` and read roles from `colorScheme` at runtime
- Do use `CustomButton` and `CustomTextField` for primary actions and form fields
- Do keep primary actions at 56px height and chips at ≥40px touch height
- Do center content at 1200px max width with 16px padding on admin and detail pages
- Do route all user-facing strings through `AppLocalizations` and allow flexible layout for long translations
- (+2 more)
Full: .impeccable/design-full.md (read a section when you need its detail)
