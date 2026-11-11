"use client";

import { useEffect, useState } from "react";
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
  type Timestamp,
} from "firebase/firestore";

import { db } from "@/lib/firebase";
import type { AppUser, BellRequest } from "@/types";

type Live<T> = { data: T[]; loading: boolean; error: string | null };

/** All CampusBell users, live, sorted by name. */
export function useUsers(): Live<AppUser> {
  const [s, setS] = useState<Live<AppUser>>({
    data: [],
    loading: !!db,
    error: null,
  });
  useEffect(() => {
    if (!db) return;
    return onSnapshot(
      collection(db, "users"),
      (snap) =>
        setS({
          data: snap.docs
            .map((d) => ({ uid: d.id, ...d.data() }) as AppUser)
            .sort((a, b) => (a.name ?? "").localeCompare(b.name ?? "")),
          loading: false,
          error: null,
        }),
      (e) => setS({ data: [], loading: false, error: e.message }),
    );
  }, []);
  return s;
}

/**
 * Latest bells (newest first), live.
 * - no uid: all bells (main administrator; see firestore.rules)
 * - uid: only bells this person sent or received (HOD)
 */
export function useBells(max = 500, uid?: string): Live<BellRequest> {
  const [s, setS] = useState<Live<BellRequest>>({
    data: [],
    loading: !!db,
    error: null,
  });
  useEffect(() => {
    if (!db) return;
    const toBell = (d: { id: string; data: () => Record<string, unknown> }) => {
      const v = d.data();
      return {
        ...v,
        id: d.id,
        createdAt: (v.createdAt as Timestamp | undefined)?.toDate(),
      } as BellRequest;
    };
    const fail = (e: Error) => setS({ data: [], loading: false, error: e.message });

    if (!uid) {
      const q = query(
        collection(db, "bell_requests"),
        orderBy("createdAt", "desc"),
        limit(max),
      );
      return onSnapshot(
        q,
        (snap) =>
          setS({ data: snap.docs.map(toBell), loading: false, error: null }),
        fail,
      );
    }

    // Two live queries (sent + received), merged.
    let sent: BellRequest[] = [];
    let received: BellRequest[] = [];
    let ready = 0;
    const publish = () => {
      const map = new Map<string, BellRequest>();
      [...sent, ...received].forEach((b) => map.set(b.id, b));
      setS({
        data: [...map.values()]
          .sort((a, b) => (b.createdAt?.getTime() ?? 0) - (a.createdAt?.getTime() ?? 0))
          .slice(0, max),
        loading: ready < 2,
        error: null,
      });
    };
    const col = collection(db, "bell_requests");
    const stop1 = onSnapshot(
      query(col, where("senderUid", "==", uid), limit(max)),
      (snap) => {
        sent = snap.docs.map(toBell);
        ready++;
        publish();
      },
      fail,
    );
    const stop2 = onSnapshot(
      query(col, where("recipientUid", "==", uid), limit(max)),
      (snap) => {
        received = snap.docs.map(toBell);
        ready++;
        publish();
      },
      fail,
    );
    return () => {
      stop1();
      stop2();
    };
  }, [max, uid]);
  return s;
}
