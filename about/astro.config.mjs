import {defineConfig} from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://about.parkour.spot",
  trailingSlash: "never",
  build: {
    format: "directory",
  },
  integrations: [sitemap()],
});
