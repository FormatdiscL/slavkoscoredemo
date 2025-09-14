import * as admin from 'firebase-admin';

// Singleton pattern for Firebase Admin
let app: admin.app.App;

export const getFirebaseAdmin = (): admin.app.App => {
  if (!app) {
    app = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      databaseURL: process.env.FIREBASE_DATABASE_URL,
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET
    });
  }
  return app;
};

export const getFirestore = (): admin.firestore.Firestore => {
  return getFirebaseAdmin().firestore();
};

export const getAuth = (): admin.auth.Auth => {
  return getFirebaseAdmin().auth();
};