/**
 * Firebase Cloud Functions for ParkourSpot App
 *
 * Import function triggers from their respective submodules:
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentCreated, onDocumentUpdated} = require(
 *     "firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at
 * https://firebase.google.com/docs/
 * functions
 */

const {onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require(
    "firebase-functions/v2/firestore");

// Example function that can be called from your Flutter app
exports.helloWorld = onCall(
    {region: "europe-west1"},
    (request) => {
      return "Hello from ParkourSpot Firebase Functions!";
    });

// Trigger when a new spot is created
exports.onSpotCreated = onDocumentCreated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const spotData = event.data.data();
      console.log("New parkour spot created:", {
        spotId: event.params.spotId,
        name: spotData.name,
        createdBy: spotData.createdBy,
      });

      // You can add logic here like:
      // - Send notifications to nearby users
      // - Update search indexes
      // - Validate spot data
    });

// Trigger when a spot is updated
exports.onSpotUpdated = onDocumentUpdated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      console.log("Parkour spot updated:", {
        spotId: event.params.spotId,
        name: afterData.name,
        ratingChanged: beforeData.rating !== afterData.rating,
      });

      // You can add logic here like:
      // - Update search indexes
      // - Send notifications about changes
      // - Log rating changes
    });

// Function to get nearby spots (can be called from Flutter app)
exports.getNearbySpots = onCall(
    {region: "europe-west1"},
    (request) => {
      const {latitude, longitude, radiusKm} = request.data;

      // This is a placeholder - you'd implement actual geospatial query logic
      return {
        message: "Nearby spots function called",
        params: {latitude, longitude, radiusKm},
      };
    });
