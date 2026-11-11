import { deleteDoc, doc, updateDoc } from "firebase/firestore";

import { db } from "@/lib/firebase";
import type { Role } from "@/types";

function need() {
  if (!db) throw new Error("Firebase isn't connected yet.");
  return db;
}

/** Change a user's role (Administrator gives portal + app admin access). */
export const setRole = (uid: string, role: Role) =>
  updateDoc(doc(need(), "users", uid), { role });

/** Disable (blocks the app and portal) or re-enable a user. */
export const setStatus = (uid: string, status: "active" | "disabled") =>
  updateDoc(doc(need(), "users", uid), { status });

/** Edit profile fields an admin may change. */
export const updateUser = (
  uid: string,
  data: { name?: string; department?: string; staffId?: string | null },
) => updateDoc(doc(need(), "users", uid), data);

/**
 * Remove someone from CampusBell (deletes their profile). They can no longer
 * use the app until they sign up again.
 */
export const removeUser = (uid: string) => deleteDoc(doc(need(), "users", uid));

/** Roles a HOD may manage / assign (staff and students). */
export const STAFF_ROLES: Role[] = ["Professor", "Assistant", "Student"];
