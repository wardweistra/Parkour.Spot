const https = require('https');

// Simple manual test: calls Google Places Autocomplete using a provided key.
// Usage: node test-places.js "amsterdam" YOUR_KEY
const [,, input, key] = process.argv;
if (!input || !key) {
  console.log('Usage: node test-places.js "query" GOOGLE_API_KEY');
  process.exit(1);
}

const params = new URLSearchParams();
params.append('input', input);
params.append('key', key);
params.append('types', 'geocode');

const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`;

https.get(url, (res) => {
  let data = '';
  res.on('data', (chunk) => data += chunk);
  res.on('end', () => {
    try {
      const json = JSON.parse(data);
      console.log(JSON.stringify(json, null, 2));
    } catch (e) {
      console.error('Failed to parse response', e);
    }
  });
}).on('error', (err) => {
  console.error('HTTP error', err);
});

