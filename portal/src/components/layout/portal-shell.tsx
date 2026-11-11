"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { signOut } from "firebase/auth";
import { ShieldAlert } from "lucide-react";

import { auth, firebaseReady } from "@/lib/firebase";
import { AdminProvider, useAdmin } from "@/hooks/use-admin";
import { AppSidebar } from "@/components/layout/app-sidebar";
import { FullLoader } from "@/components/layout/full-loader";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";

/**
 * Responsive shell + access control.
 * - mobile (< 768px): sidebar is a drawer (menu button in header)
 * - tablet (768–1279px): sidebar collapsed to icons
 * - laptop/desktop (>= 1280px): full sidebar
 * Signed-out users go to /login; non-admins see "Access pending".
 */
export function PortalShell({ children }: { children: React.ReactNode }) {
  return (
    <AdminProvider>
      <Gate>{children}</Gate>
    </AdminProvider>
  );
}

function Gate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, profile, canUsePortal, loading } = useAdmin();

  // No guest mode: signed-out (or Firebase not set up) always goes to /login.
  useEffect(() => {
    if (!firebaseReady || (!loading && !user)) router.replace("/login");
  }, [loading, user, router]);

  if (!firebaseReady || loading || !user) {
    return <FullLoader />;
  }

  if (!canUsePortal) {
    return (
      <div className="flex min-h-svh items-center justify-center p-6">
        <div className="w-full max-w-sm space-y-4 text-center">
          <div className="mx-auto flex size-12 items-center justify-center rounded-full bg-primary/10 text-primary">
            <ShieldAlert className="size-6" />
          </div>
          <h1 className="text-xl font-semibold">Access pending</h1>
          <p className="text-sm text-muted-foreground">
            {profile?.status === "disabled"
              ? "Your account is disabled. Contact an administrator."
              : `You're signed in as ${user?.email}. Only Administrators and HODs can use the portal. Ask an administrator for access.`}
          </p>
          <Button
            variant="outline"
            className="w-full"
            onClick={async () => {
              if (auth) await signOut(auth);
              router.replace("/login");
            }}
          >
            Sign out
          </Button>
        </div>
      </div>
    );
  }

  return <Shell>{children}</Shell>;
}

function Shell({ children }: { children: React.ReactNode }) {
  const [open, setOpen] = useState(true);

  useEffect(() => {
    const mq = window.matchMedia("(min-width: 1280px)");
    const sync = () => setOpen(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);

  return (
    <SidebarProvider open={open} onOpenChange={setOpen}>
      <AppSidebar />
      <SidebarInset className="h-svh min-w-0 overflow-hidden">
        <header className="sticky top-0 z-10 flex h-14 shrink-0 items-center gap-2 border-b bg-background/80 px-3 backdrop-blur sm:px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-1 h-4" />
          <span className="truncate text-sm font-semibold">
            CampusBell Admin
          </span>
        </header>
        <main className="flex-1 overflow-y-auto">
          <div className="mx-auto w-full max-w-7xl p-4 sm:p-6 lg:p-8">
            {children}
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
