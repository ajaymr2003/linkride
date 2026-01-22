const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  // Only allow if an admin is logged in (you can make this check stricter)
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Admin only.");
  }

  const uid = data.uid;

  try {
    // 1. Delete user from Firebase Authentication
    await admin.auth().deleteUser(uid);

    // 2. Delete user from Firestore
    await admin.firestore().collection("users").doc(uid).delete();

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError("internal", error.message);
  }
});