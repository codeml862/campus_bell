import { PortalShell } from "@/components/layout/portal-shell";

/** All admin pages share the responsive shell (fixed sidebar + scroll). */
export default function PortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <PortalShell>{children}</PortalShell>;
}
