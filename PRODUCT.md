# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Anyone practicing parkour (parkourists), including individuals choosing where to train; trainers sharing a location with students; gym owners who want more visitors; jam and event organizers who need a spot map or a place to surface their event.

Used while planning at home and on the go—finding where others are, sharing where you train, and discovering or passing on where to go next. Maps, photos, and ratings stay scannable in both modes; flows for spots and sharing should work outdoors and in motion.

**Job to be done:** Find trustworthy spots, understand them quickly (map, images, ratings), save or share them, and contribute so the map stays useful and welcoming for the whole community.

## Product Purpose

ParkourSpot is a community atlas for discovering, reporting, rating, and sharing parkour spots worldwide. It exists so the parkour community can find and pass on trustworthy places to train without relying on closed or extractive platforms. Success means spots are easy to find and understand, contribution feels welcoming, and core discovery stays useful for people who are not locked into an account wall.

## Positioning

Core spot discovery and community value stay open—no login or paywall on the map itself. Only optional extras might someday be paid; the basic “find and share spots” promise is never gated. Many neighboring apps lock core content behind accounts or payment; ParkourSpot’s claim is open discovery owned by the community.

## Operating Context

Planning at home (browse, save, share) and on the go (map, photos, ratings outdoors). Trainers may share locations with students; gym owners and jam/event organizers use the map to attract visitors or surface events. Primary surface is a Flutter web PWA installable on desktop and mobile browsers—not a native iOS/Android app.

## Capabilities and Constraints

Confirmed today: authentication and profiles; spot discovery/search; interactive maps; add spots with photos; ratings/reviews; Firebase backend; user / moderator / admin roles; localization for `en`, `de`, `es`, `fr`, `nl`, `pt`; PWA on web. Live production: [https://Parkour.Spot](https://Parkour.Spot).

Undecided / future: in-app light/dark toggle (system preference today); any paid “extra features” remain unspecified and must not gate core discovery.

Technical stack is established in-repo (Flutter web + Firebase); no greenfield stack choice.

## Brand Commitments

- **Name:** ParkourSpot (Parkour·Spot in some marketing copy)
- **Personality:** Community-minded · Energetic · Trustworthy
- **Voice:** By and for the parkour community—from love of the sport and culture, not a cold corporate product or money grab. Must feel from the parkour world, not an outside company “about” it.
- **Emotional goals:** Belonging and trust; clarity navigating maps and forms; warmth and legitimacy as a community tool—not hype, extraction, or artificial scarcity.
- **Assets:** Lottie splash (`assets/images/lottie*.json`); SVG/PNG wordmarks and square marks light/dark under `assets/images/`; Jumpflix mark (`assets/images/jumpflix-logo.webp`) where that feature appears.
- **UI copy:** Sentence case—capitalize the first word only, plus proper nouns and acronyms (API, URLs, Jumpflix). Prefer “Add new spot” over “Add New Spot”.

Visual system (Material 3, Fredoka, `#007FA8` seed, radii, components) is recorded in DESIGN.md, not here.

## Evidence on Hand

- Brand assets under `assets/images/` (logos, Lottie, wordmarks, splash).
- Live production app at Parkour.Spot with real community spots.
- Local/emulator seed data (`scripts/seed-data/`) is sample only for development—not marketing proof.
- No approved testimonials, press quotes, or case studies on hand—future work must not fabricate them.

## Product Principles

1. **Open core discovery** — The map and basic find/share flows stay usable without paywalls or unnecessary account gates.
2. **Clarity at a glance** — Spots must be understandable quickly via map, images, and ratings, at home and outdoors.
3. **Community-owned, not extractive** — UX and copy reinforce shared ownership; avoid patterns that lock the community’s own map behind friction or scarcity theater.
4. **Global-ready** — First-class locales; layout and copy tolerate long translations and avoid brittle truncation.
5. **At-home and on-the-go** — Design for planning and for motion outdoors; touch-friendly, PWA-first on desktop and mobile web.

## Accessibility & Inclusion

No formal WCAG target required right now. Default to inclusion where practical: readable contrast, sensible touch targets, and reduced-motion awareness as patterns are added—without blocking shipping on a full audit unless priorities change.
