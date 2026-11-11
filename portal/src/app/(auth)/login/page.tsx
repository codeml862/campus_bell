"use client";

import { useState } from "react";
import Link from "next/link";
import { Eye, EyeOff, Loader2 } from "lucide-react";
import { toast } from "sonner";

import { authMessage, resetPassword, signInEmail, signInGoogle } from "@/lib/auth";
import {
  AuthHeading,
  FormError,
  GoogleButton,
  OrDivider,
} from "@/components/auth/auth-parts";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAuthRedirect } from "@/hooks/use-auth-redirect";
import { FullLoader } from "@/components/layout/full-loader";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState<"email" | "google" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const checking = useAuthRedirect(setError);

  async function run(kind: "email" | "google", fn: () => Promise<unknown>) {
    setBusy(kind);
    setError(null);
    try {
      await fn(); // useAuthRedirect sends us to the dashboard
    } catch (e) {
      setError(authMessage(e));
    } finally {
      setBusy(null);
    }
  }

  async function forgot() {
    if (!email.includes("@")) {
      setError("Type your email above, then click Forgot password.");
      return;
    }
    try {
      await resetPassword(email);
      toast.success(`Reset link sent to ${email}`);
    } catch (e) {
      setError(authMessage(e));
    }
  }

  if (checking) return <FullLoader />;

  return (
    <>
      <AuthHeading
        title="Sign in"
        subtitle="Welcome back. Sign in to the CampusBell admin portal."
      />

      <form
        className="space-y-4"
        onSubmit={(e) => {
          e.preventDefault();
          run("email", () => signInEmail(email.trim(), password));
        }}
      >
        <div className="space-y-1.5">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            autoComplete="email"
            placeholder="name@college.edu"
            className="h-10"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>

        <div className="space-y-1.5">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">Password</Label>
            <button
              type="button"
              onClick={forgot}
              className="text-xs font-medium text-primary hover:underline"
            >
              Forgot password?
            </button>
          </div>
          <div className="relative">
            <Input
              id="password"
              type={show ? "text" : "password"}
              autoComplete="current-password"
              placeholder="Your password"
              className="h-10 pr-10"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <button
              type="button"
              aria-label={show ? "Hide password" : "Show password"}
              onClick={() => setShow((s) => !s)}
              className="absolute inset-y-0 right-0 flex w-10 items-center justify-center text-muted-foreground hover:text-foreground"
            >
              {show ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
            </button>
          </div>
        </div>

        <FormError message={error} />

        <Button
          type="submit"
          className="h-10 w-full font-medium"
          disabled={busy !== null}
        >
          {busy === "email" && <Loader2 className="size-4 animate-spin" />}
          Sign in
        </Button>
      </form>

      <div className="my-6">
        <OrDivider />
      </div>

      <GoogleButton
        loading={busy === "google"}
        onClick={() => run("google", signInGoogle)}
      />

      <p className="mt-8 text-center text-sm text-muted-foreground">
        New to CampusBell?{" "}
        <Link href="/signup" className="font-medium text-primary hover:underline">
          Create an account
        </Link>
      </p>
    </>
  );
}
