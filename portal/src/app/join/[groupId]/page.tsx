import type { Metadata } from "next";
import { headers } from "next/headers";
import { Suspense } from "react";
import { OpenApp } from "./open-app";

export const metadata: Metadata = {
  title: "Join group · CampusBell",
  robots: { index: false },
};

const APK_URL = "/CampusBell.apk";

type Props = {
  params: Promise<{ groupId: string }>;
  searchParams: Promise<{ install?: string }>;
};

/**
 * Group invite landing page.
 *
 * When CampusBell is installed, Android opens https://<host>/join/<id> in the
 * app directly (verified App Link, see public/.well-known/assetlinks.json), so
 * this page is only reached when the link was not handed to the app:
 *  - Android: hand off through an intent:// URL. The browser opens the app if
 *    it is installed, otherwise it follows browser_fallback_url back here with
 *    ?install=1.
 *  - ?install=1 or any other platform: show the install screen.
 */
export default function JoinGroupPage(props: Props) {
  return (
    <Suspense fallback={<Shell title="Opening invitation…" />}>
      <Invitation {...props} />
    </Suspense>
  );
}

async function Invitation({ params, searchParams }: Props) {
  const [{ groupId }, { install }, h] = await Promise.all([
    params,
    searchParams,
    headers(),
  ]);

  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(groupId)) {
    return (
      <Shell title="Invalid group link">
        <p className="mt-4 text-slate-600">
          Ask your teacher to share the group link again.
        </p>
      </Shell>
    );
  }

  const android = /android/i.test(h.get("user-agent") ?? "");

  if (android && install !== "1") {
    return (
      <Shell title="Opening CampusBell…">
        <p className="mt-4 text-slate-600">
          You will join the group after signing in with your student account.
        </p>
        <OpenApp groupId={groupId} />
      </Shell>
    );
  }

  return (
    <Shell title="Install CampusBell to join">
      <p className="mt-4 text-slate-600">
        {android
          ? "CampusBell isn’t installed on this phone. Install it, sign in with your student account, then open this group link again to join."
          : "CampusBell is an Android app. Open this link on your Android phone to install the app and join the group."}
      </p>
      {android && (
        <a
          href={APK_URL}
          download="CampusBell.apk"
          className="mt-6 block rounded-full bg-blue-700 px-6 py-3 font-semibold text-white"
        >
          Install CampusBell
        </a>
      )}
    </Shell>
  );
}

function Shell({
  title,
  children,
}: {
  title: string;
  children?: React.ReactNode;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-50 px-6">
      <div className="w-full max-w-md rounded-3xl bg-white p-8 text-center shadow-sm">
        <p className="mb-3 text-sm font-semibold text-blue-700">CampusBell</p>
        <h1 className="text-2xl font-bold">{title}</h1>
        {children}
      </div>
    </main>
  );
}
