import {defineConfig} from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://about.parkour.spot",
  trailingSlash: "never",
  // Astro 7 defaults to JSX whitespace collapsing, which drops spaces between
  // inline elements. Keep the HTML-aware behavior this site was built with.
  compressHTML: true,
  build: {
    format: "directory",
  },
  integrations: [
    sitemap({
      filter: (page) => {
        const path = new URL(page).pathname;
        return path !== "/blog" && path !== "/partners";
      },
    }),
  ],
});
