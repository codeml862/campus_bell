// Pages wait for sign-in in the browser, so skip instant-navigation
// prerender validation (Next.js 16).
export const instant = false;

import UsersView from "./view";

export default function Page() {
  return <UsersView />;
}
