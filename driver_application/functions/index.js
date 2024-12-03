/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.checkUnacceptedRides = functions.database.ref('/rides/{rideId}')
  .onCreate((snapshot, context) => {
    const rideData = snapshot.val();
    const rideId = context.params.rideId;
    const userId = rideData.user;  // User ID associated with the ride
    const rideTime = new Date(rideData.time);  // Parse the ride's time

    // Calculate the delay to check 30 minutes before the ride time
    const now = new Date();
    const delay = rideTime - now - 30 * 60 * 1000;

    // Proceed if the calculated delay is positive (future date)
    if (delay > 0) {
      setTimeout(async () => {
        const rideRef = admin.database().ref(`/rides/${rideId}`);
        const rideSnapshot = await rideRef.once('value');
        const updatedRideData = rideSnapshot.val();

        // Check if the ride is still unassigned
        if (updatedRideData && updatedRideData.assigned === false) {
          // Delete the ride from Firebase
          await rideRef.remove();

          // Also delete the ride info from user_ride using the userId
          const userRideRef = admin.database().ref(`/user_ride/${userId}`);
          const userRideSnapshot = await userRideRef.once('value');
          const userRideData = userRideSnapshot.val();

          // Verify that the ride ID in user_ride matches the unaccepted ride ID
          if (userRideData && userRideData.currentRideId === rideId) {
            await userRideRef.remove();  // Delete the entry from user_ride
          }

          // Prepare the notification payload for the user
          const payload = {
            notification: {
              title: "Ride Unavailable",
              body: "Unable to find a driver for your ride, please book another ride.",
            },
          };

        // Send the notification to the user (assuming you store a device token under the user in Firebase)
        //   const userRef = admin.database().ref(`/users/${userId}`);
        //   const userSnapshot = await userRef.once('value');
        //   const userToken = userSnapshot.val().deviceToken;

        //   if (userToken) {
        //     await admin.messaging().sendToDevice(userToken, payload);
        //   }
        }
      }, delay);
    }
  });


// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
