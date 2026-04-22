/* global importScripts, firebase */

importScripts('https://www.gstatic.com/firebasejs/12.4.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.4.0/firebase-messaging-compat.js');

// Keep the service worker valid and ready for FCM token registration.
// Flutter initializes Firebase in the app runtime; background handling can be
// expanded later when push delivery is implemented.
