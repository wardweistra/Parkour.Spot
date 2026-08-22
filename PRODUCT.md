# Impeccable — ParkourSpot

Persistent design context for AI-assisted work. Update this file when product or brand direction changes.

## Design Context

### Users

**Who:** Anyone practicing parkour (parkourists), including: individuals choosing where to train; trainers sharing a location with students; gym owners who want more visitors; jam and event organizers who need a spot map or a place to surface their event.

**Context:** Used **while planning at home** and **on the go**—finding where others are, sharing where you train, and discovering or passing on where to go next. Maps, photos, and ratings stay scannable in both modes; flows for spots and sharing should work outdoors and in motion.

**Job to be done:** Find trustworthy spots, understand them quickly (map, images, ratings), save or share them, and contribute so the map stays useful and welcoming for the whole community.

### Brand Personality

**Three words:** *Community-minded · Energetic · Trustworthy*

**Voice & stance:** By and for the community—made from love for the sport and culture, **not** a cold corporate product or a money grab. It should always feel clear that this comes **from** the parkour world, not an outside company “about” it.

**Contrast with the market:** Many apps **gate core content** behind logins or payment. ParkourSpot’s direction is different: **core discovery and community value stay open**; only **extra features** might someday be paid—never the basic “find and share spots” promise behind a wall.

**Emotional goals:** Belonging and trust; clarity when navigating maps and forms; warmth and legitimacy as a community tool—not hype, extraction, or artificial scarcity.

### Aesthetic Direction

**Visual tone:** Material 3, rounded UI (e.g. primary controls with ~12px radius), friendly display typography (**Fredoka** via `google_fonts`). Primary palette from seed **`#007FA8`** (`ColorScheme.fromSeed`) for light and dark themes.

**Brand assets:** Lottie splash (`assets/images/lottie*.json`), SVG wordmarks and square marks (light/dark variants under `assets/images/`).

**Theme:** Light and dark themes are implemented; today **`themeMode` follows the system**. An **in-app light/dark toggle** is a reasonable future enhancement when settings UX is ready.

**Localization:** First-class support for `en`, `de`, `es`, `fr`, `nl`, `pt`—UI copy and layout should avoid brittle truncation; prefer flexible strings and locale-aware formats.

### Accessibility & inclusion

No formal WCAG target is required right now. **Default to inclusion where it’s practical:** readable contrast, sensible touch targets, and reduced-motion awareness as patterns are added—without blocking shipping on a full audit unless priorities change.

### Design Principles

1. **Clarity over chrome** — Maps, spot detail, and forms stay readable at a glance; hierarchy beats decoration.
2. **Consistent Material 3 + seed palette** — Extend `Theme.of(context).colorScheme` and shared widgets (e.g. `CustomButton`) rather than one-off colors, unless semantic (error, success).
3. **Global-ready** — All user-facing strings through `AppLocalizations`; consider RTL and long translations when laying out rows and dialogs.
4. **Touch-friendly, mobile-aware** — Primary actions and targets sized for phones; PWA and web remain first-class alongside native.
5. **Community-first, not extractive** — UX and copy reinforce shared ownership and open discovery; avoid patterns that feel like locking the community’s own map behind paywalls or unnecessary friction for core flows.
6. **Motion with purpose** — Splash and transitions welcome; prefer respecting reduced-motion preferences when the platform exposes them, applied consistently as the app evolves.
7. **Sentence case for UI copy** — Buttons, fields, titles, and menu items capitalize the first word only, plus proper nouns and acronyms (API, URLs, Jumpflix). Prefer “Add new spot” over “Add New Spot”.
