"use client";

import { useState } from "react";
import Link from "next/link";
import { Check, Eye, EyeOff, Loader2 } from "lucide-react";

import { authMessage, signInGoogle, signUpEmail } from "@/lib/auth";
import {
  AuthHeading,
  FormError,
  GoogleButton,
  OrDivider,
} from "@/components/auth/auth-parts";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { useAuthRedirect } from "@/hooks/use-auth-redirect";
import { FullLoader } from "@/components/layout/full-loader";

export default function SignupPage() {
  const [first, setFirst] = useState("");
  const [last, setLast] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState<"email" | "google" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const checking = useAuthRedirect(setError);

  const rules = [
    { ok: password.length >= 8, text: "8+ characters" },
    { ok: /[A-Za-z]/.test(password), text: "A letter" },
    { ok: /\d/.test(password), text: "A number" },
  ];
  const strength = rules.filter((r) => r.ok).length;

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

  function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!first.trim() || !last.trim()) {
      setError("Enter your first and last name.");
      return;
    }
    if (strength < 3) {
      setError("Password needs 8+ characters with a letter and a number.");
      return;
    }
    run("email", () =>
      signUpEmail(`${first.trim()} ${last.trim()}`, email.trim(), password),
    );
  }

  if (checking) return <FullLoader />;

  return (
    <>
      <AuthHeading
        title="Create an account"
        subtitle="An existing admin will give you access after you sign up."
      />

      <form className="space-y-4" onSubmit={submit}>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div className="space-y-1.5">
            <Label htmlFor="first">First name</Label>
            <Input
              id="first"
              autoComplete="given-name"
              placeholder="First"
              className="h-10"
              value={first}
              onChange={(e) => setFirst(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="last">Last name</Label>
            <Input
              id="last"
              autoComplete="family-name"
              placeholder="Last"
              className="h-10"
              value={last}
              onChange={(e) => setLast(e.target.value)}
            />
          </div>
        </div>

        <div className="space-y-1.5">
          <Label htmlFor="email">Work email</Label>
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
          <Label htmlFor="password">Password</Label>
          <div className="relative">
            <Input
              id="password"
              type={show ? "text" : "password"}
              autoComplete="new-password"
              placeholder="Create a password"
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
          {/* Strength bar + rules */}
          <div className="flex gap-1 pt-1">
            {[0, 1, 2].map((i) => (
              <span
                key={i}
                className={cn(
                  "h-1 flex-1 rounded-full bg-muted transition-colors",
                  i < strength && "bg-primary",
                )}
              />
            ))}
          </div>
          <ul className="flex flex-wrap gap-x-4 gap-y-1 pt-1">
            {rules.map((r) => (
              <li
                key={r.text}
                className={cn(
                  "flex items-center gap-1 text-xs text-muted-foreground",
                  r.ok && "text-primary",
                )}
              >
                <Check className="size-3" />
                {r.text}
              </li>
            ))}
          </ul>
        </div>

        <FormError message={error} />

        <Button
          type="submit"
          className="h-10 w-full font-medium"
          disabled={busy !== null}
        >
          {busy === "email" && <Loader2 className="size-4 animate-spin" />}
          Create account
        </Button>
      </form>

      <div className="my-6">
        <OrDivider />
      </div>

      <GoogleButton
        loading={busy === "google"}
        onClick={() => run("google", signInGoogle)}
      />

      <p className="mt-6 text-center text-xs text-muted-foreground">
        By creating an account you agree to your college&apos;s acceptable use
        policy.
      </p>
      <p className="mt-4 text-center text-sm text-muted-foreground">
        Already have an account?{" "}
        <Link href="/login" className="font-medium text-primary hover:underline">
          Sign in
        </Link>
      </p>
    </>
  );
}
