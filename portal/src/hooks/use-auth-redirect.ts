"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";

import { auth } from "@/lib/firebase";
import { authMessage, completeGoogleRedirect } from "@/lib/auth";

/**
 * On the login / sign-up pages: finish a Google redirect sign-in and send
 * anyone who is signed in to the dashboard. This is the ONLY place that
 * navigates after sign-in, so there is no double jump.
 *
 * Returns true while auth is still being checked or we're redirecting —
 * show the loader then, not the form.
 */
export function useAuthRedirect(onError: (message: string) => void) {
  const router = useRouter();
  const [busy, setBusy] = useState(!!auth);

  useEffect(() => {
    if (!auth) return;
    completeGoogleRedirect().catch((e) => onError(authMessage(e)));
    return onAuthStateChanged(auth, (u) => {
      if (u) {
        setBusy(true);
        router.replace("/dashboard");
      } else {
        setBusy(false);
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [router]);

  return busy;
}
