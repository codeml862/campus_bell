// Same Firebase project as the CampusBell app (alaram-bell-fcdb2),
// so the portal reads/writes the same users and bells.
import { getApp, getApps, initializeApp, type FirebaseApp } from "firebase/app";
import { getAuth, type Auth } from "firebase/auth";
import { getFirestore, type Firestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  // On a live HTTPS site use our own host (/__/auth is proxied to Firebase
  // in next.config.ts) so Google redirect sign-in survives blocked
  // third-party storage. Local http://localhost can't serve https, so it
  // uses Firebase's own domain.
  authDomain:
    typeof window !== "undefined" && window.location.protocol === "https:"
      ? window.location.host
      : process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

/** False until .env.local has the Web app keys (see .env.local.example). */
export const firebaseReady = Boolean(
  firebaseConfig.apiKey && firebaseConfig.appId,
);

export const app: FirebaseApp | null = firebaseReady
  ? getApps().length
    ? getApp()
    : initializeApp(firebaseConfig)
  : null;
export const auth: Auth | null = app ? getAuth(app) : null;
export const db: Firestore | null = app ? getFirestore(app) : null;
