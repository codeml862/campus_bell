import { FirebaseError } from "firebase/app";
import {
  GoogleAuthProvider,
  createUserWithEmailAndPassword,
  getRedirectResult,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signInWithRedirect,
  updateProfile,
} from "firebase/auth";

import { auth } from "@/lib/firebase";

function need() {
  if (!auth) throw new Error("not-configured");
  return auth;
}

export const signInEmail = (email: string, password: string) =>
  signInWithEmailAndPassword(need(), email, password);

/**
 * Google sign-in: try a popup; if the browser blocks it, fall back to a
 * full-page redirect (the result is picked up by completeGoogleRedirect).
 */
export async function signInGoogle() {
  const a = need();
  const provider = new GoogleAuthProvider();
  provider.setCustomParameters({ prompt: "select_account" });
  try {
    return await signInWithPopup(a, provider);
  } catch (e) {
    if (
      e instanceof FirebaseError &&
      (e.code === "auth/popup-blocked" ||
        e.code === "auth/operation-not-supported-in-this-environment")
    ) {
      await signInWithRedirect(a, provider);
      return null; // the page navigates away
    }
    throw e;
  }
}

/** Finishes a Google redirect sign-in (call once on the login page). */
export const completeGoogleRedirect = () =>
  auth ? getRedirectResult(auth) : Promise.resolve(null);

export async function signUpEmail(name: string, email: string, password: string) {
  const cred = await createUserWithEmailAndPassword(need(), email, password);
  await updateProfile(cred.user, { displayName: name });
  return cred;
}

export const resetPassword = (email: string) =>
  sendPasswordResetEmail(need(), email);

/** Friendly message for Firebase auth errors. */
export function authMessage(e: unknown): string {
  if (e instanceof Error && e.message === "not-configured") {
    return "Firebase isn't connected yet. Add the Web app keys to .env.local.";
  }
  if (e instanceof FirebaseError) {
    switch (e.code) {
      case "auth/invalid-credential":
      case "auth/wrong-password":
      case "auth/user-not-found":
        return "Wrong email or password.";
      case "auth/email-already-in-use":
        return "This email already has an account. Sign in instead.";
      case "auth/invalid-email":
        return "Enter a valid email address.";
      case "auth/weak-password":
        return "Password is too weak.";
      case "auth/too-many-requests":
        return "Too many attempts. Try again in a few minutes.";
      case "auth/popup-closed-by-user":
      case "auth/cancelled-popup-request":
        return "Google sign-in was closed.";
      case "auth/unauthorized-domain":
        return "This website isn't allowed for Google sign-in yet. Add it under Firebase Authentication > Settings > Authorized domains.";
      case "auth/operation-not-allowed":
        return "Google sign-in isn't enabled in Firebase Authentication.";
      case "auth/network-request-failed":
        return "No internet connection.";
    }
    return e.message;
  }
  return "Something went wrong. Try again.";
}
