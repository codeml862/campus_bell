"use client";

import { AlertCircle, Bell, Loader2 } from "lucide-react";

import { firebaseReady } from "@/lib/firebase";
import { Button } from "@/components/ui/button";

/** Logo + title + subtitle (logo shows only where the brand panel is hidden). */
export function AuthHeading({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <div className="mb-8 space-y-6">
      <div className="flex items-center gap-2.5 lg:hidden">
        <div className="flex size-9 items-center justify-center rounded-xl bg-primary text-primary-foreground">
          <Bell className="size-[18px]" strokeWidth={2.25} />
        </div>
        <span className="text-base font-semibold tracking-tight">
          CampusBell
        </span>
      </div>
      <div className="space-y-1.5">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="text-sm text-muted-foreground">{subtitle}</p>
      </div>
      {!firebaseReady && (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
          Firebase isn&apos;t connected yet. Add the Web app keys to{" "}
          <code className="font-mono">.env.local</code> to sign in.
        </p>
      )}
    </div>
  );
}

export function FormError({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p
      role="alert"
      className="flex items-start gap-2 rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive"
    >
      <AlertCircle className="mt-0.5 size-4 shrink-0" />
      {message}
    </p>
  );
}

export function OrDivider() {
  return (
    <div className="flex items-center gap-3 text-xs text-muted-foreground">
      <span className="h-px flex-1 bg-border" />
      or
      <span className="h-px flex-1 bg-border" />
    </div>
  );
}

export function GoogleButton({
  loading,
  onClick,
}: {
  loading: boolean;
  onClick: () => void;
}) {
  return (
    <Button
      type="button"
      variant="outline"
      className="h-10 w-full gap-2 font-medium"
      disabled={loading}
      onClick={onClick}
    >
      {loading ? (
        <Loader2 className="size-4 animate-spin" />
      ) : (
        <svg viewBox="0 0 48 48" className="size-4" aria-hidden>
          <path
            fill="#EA4335"
            d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.6 5.4 2.7 13.2l7.9 6.2C12.5 13.7 17.8 9.5 24 9.5z"
          />
          <path
            fill="#4285F4"
            d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.7 6c4.5-4.2 6.9-10.3 6.9-17.7z"
          />
          <path
            fill="#FBBC05"
            d="M10.6 28.6c-.5-1.4-.8-3-.8-4.6s.3-3.2.8-4.6l-7.9-6.2C1 16.6 0 20.2 0 24s1 7.4 2.7 10.8l7.9-6.2z"
          />
          <path
            fill="#34A853"
            d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.7-6c-2.1 1.4-4.9 2.3-8.2 2.3-6.2 0-11.5-4.2-13.4-9.9l-7.9 6.2C6.6 42.6 14.6 48 24 48z"
          />
        </svg>
      )}
      Continue with Google
    </Button>
  );
}
