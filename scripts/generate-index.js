#!/usr/bin/env node

/**
 * Build script to generate web/index.html from the shared template
 * This ensures both the regular index.html and spotPage function stay in sync
 */

const fs = require('fs');
const path = require('path');

// Import the shared template
const { generateHtmlPage } = require('../functions/html-template');

// Generate the default index.html
const html = generateHtmlPage({
  title: "Parkour.Spot",
  description: "Discover and share parkour spots around the world",
  image: "icons/Icon-512.png",
  url: null,
  siteName: "Parkour.Spot",
  isDynamic: false,
  serviceWorkerVersion: "{{flutter_service_worker_version}}"
});

// Write to web/index.html
const indexPath = path.join(__dirname, '..', 'web', 'index.html');
fs.writeFileSync(indexPath, html);

console.log('✅ Generated web/index.html from shared template');
