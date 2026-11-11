import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  // Hide the Next.js "N" badge in the corner during development.
  devIndicators: false,
  cacheComponents: true,
  partialPrefetching: true,
  // Serve Firebase's sign-in helper from our own domain so Google
  // sign-in (redirect flow) works even when the browser blocks popups
  // and third-party storage. See firebase.google.com/docs/auth/web/redirect-best-practices
  async rewrites() {
    return [
      {
        source: "/__/auth/:path*",
        destination: "https://alaram-bell-fcdb2.firebaseapp.com/__/auth/:path*",
      },
      {
        source: "/__/firebase/:path*",
        destination:
          "https://alaram-bell-fcdb2.firebaseapp.com/__/firebase/:path*",
      },
    ];
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
