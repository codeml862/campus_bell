"use client";

import { useEffect } from "react";

const PACKAGE = "com.hodcall.alaram_bell";

/**
 * Android intent URL for campusbell://join/<id>. The browser resolves it
 * against installed apps: it opens CampusBell when present, otherwise it
 * navigates to browser_fallback_url (this page with ?install=1).
 */
function intentUrl(groupId: string) {
  const fallback = `${window.location.origin}/join/${encodeURIComponent(groupId)}?install=1`;
  return (
    `intent://join/${encodeURIComponent(groupId)}` +
    `#Intent;scheme=campusbell;package=${PACKAGE};` +
    `S.browser_fallback_url=${encodeURIComponent(fallback)};end`
  );
}

export function OpenApp({ groupId }: { groupId: string }) {
  useEffect(() => {
    window.location.replace(intentUrl(groupId));
  }, [groupId]);

  // Browsers that only allow app hand-off from a tap get this button.
  return (
    <button
      type="button"
      onClick={() => window.location.assign(intentUrl(groupId))}
      className="mt-6 block w-full rounded-full bg-blue-700 px-6 py-3 font-semibold text-white"
    >
      Open CampusBell &amp; join
    </button>
  );
}
