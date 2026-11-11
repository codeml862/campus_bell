"use client";

import { createContext, useContext, useEffect, useState } from "react";
import { onAuthStateChanged, type User } from "firebase/auth";
import { doc, onSnapshot } from "firebase/firestore";

import { auth, db, firebaseReady } from "@/lib/firebase";
import type { AppUser } from "@/types";

type AdminState = {
  /** Firebase sign-in (null = signed out). */
  user: User | null;
  /** The user's CampusBell profile (users/{uid}), if any. */
  profile: AppUser | null;
  /** Administrator: full access to every department. */
  isAdmin: boolean;
  /** HOD: admin of their own department (staff and students only). */
  isHod: boolean;
  /** May use the portal at all (Administrator or HOD). */
  canUsePortal: boolean;
  /** null = all departments (Administrator); otherwise the HOD's department. */
  scopeDept: string | null;
  loading: boolean;
};

const NONE = {
  isAdmin: false,
  isHod: false,
  canUsePortal: false,
  scopeDept: null,
};

const Ctx = createContext<AdminState>({
  user: null,
  profile: null,
  ...NONE,
  loading: true,
});

/** Tracks who is signed in and whether they are an Administrator. */
export function AdminProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AdminState>({
    user: null,
    profile: null,
    ...NONE,
    loading: firebaseReady,
  });

  useEffect(() => {
    if (!auth || !db) return;
    let stopProfile: (() => void) | undefined;
    const stopAuth = onAuthStateChanged(auth, (user) => {
      stopProfile?.();
      if (!user) {
        setState({ user: null, profile: null, ...NONE, loading: false });
        return;
      }
      stopProfile = onSnapshot(
        doc(db!, "users", user.uid),
        (snap) => {
          const profile = snap.exists()
            ? ({ uid: snap.id, ...snap.data() } as AppUser)
            : null;
          const active = !!profile && profile.status !== "disabled";
          const isAdmin = active && profile!.role === "Administrator";
          const isHod = active && profile!.role === "HOD";
          setState({
            user,
            profile,
            isAdmin,
            isHod,
            canUsePortal: isAdmin || isHod,
            scopeDept: isHod ? profile!.department : null,
            loading: false,
          });
        },
        () =>
          setState({ user, profile: null, ...NONE, loading: false }),
      );
    });
    return () => {
      stopProfile?.();
      stopAuth();
    };
  }, []);

  return <Ctx.Provider value={state}>{children}</Ctx.Provider>;
}

export const useAdmin = () => useContext(Ctx);
