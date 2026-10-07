import {SITE_NAME} from "./brand";

export interface ScreenshotInfo {
  src: string;
  alt: string;
  width: number;
  height: number;
  kind: "desktop" | "mobile";
}

export const SCREENSHOTS = {
  mapDesktop: {
    src: "/screenshots/map-desktop.webp",
    alt: `The ${SITE_NAME} world map in a desktop browser, with spot pins and event pins across every continent and a panel counting spots and events in view.`,
    width: 1024,
    height: 837,
    kind: "desktop",
  },
  eventsMobile: {
    src: "/screenshots/events-mobile.webp",
    alt: `${SITE_NAME} on a phone showing upcoming events near Boston, starting with the Join or Die 8 jam, with share and show-on-map buttons.`,
    width: 476,
    height: 1024,
    kind: "mobile",
  },
  spotCommunityMobile: {
    src: "/screenshots/spot-community-mobile.webp",
    alt: `A spot page on ${SITE_NAME} for Utrecht Moreelsepark, with photos, a community rating, who is training there now, and a plan to train button.`,
    width: 476,
    height: 1024,
    kind: "mobile",
  },
} satisfies Record<string, ScreenshotInfo>;

export type ScreenshotId = keyof typeof SCREENSHOTS;
