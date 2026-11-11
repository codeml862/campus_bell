"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  EmailAuthProvider,
  reauthenticateWithCredential,
  signOut,
  updatePassword,
} from "firebase/auth";
import { LogOut } from "lucide-react";
import { toast } from "sonner";

import { auth, firebaseReady } from "@/lib/firebase";
import { authMessage } from "@/lib/auth";
import { deptShort } from "@/lib/format";
import { useAdmin } from "@/hooks/use-admin";
import { PageHeader, Panel } from "@/components/layout/page";
import { RoleBadge, UserAvatar } from "@/components/common";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export default function SettingsView() {
  const router = useRouter();
  const { user, profile } = useAdmin();
  const name = profile?.name || user?.displayName || "Admin";
  const hasPassword = user?.providerData.some((p) => p.providerId === "password");

  return (
    <>
      <PageHeader title="Settings" description="Your admin account." />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Account */}
        <Panel className="p-5 lg:col-span-1">
          <div className="flex items-center gap-3">
            <UserAvatar name={name} className="size-12 text-sm" />
            <div className="min-w-0">
              <p className="truncate font-semibold">{name}</p>
              <p className="truncate text-sm text-muted-foreground">
                {user?.email ?? "Not signed in"}
              </p>
            </div>
          </div>
          <dl className="mt-5 space-y-3 text-sm">
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Role</dt>
              <dd>{profile ? <RoleBadge role={profile.role} /> : "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Department</dt>
              <dd>{profile ? deptShort(profile.department) : "—"}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-muted-foreground">Sign-in</dt>
              <dd>{hasPassword ? "Email + password" : user ? "Google" : "—"}</dd>
            </div>
          </dl>
          <Button
            variant="outline"
            className="mt-6 w-full text-destructive"
            disabled={!firebaseReady}
            onClick={async () => {
              if (auth) await signOut(auth);
              router.replace("/login");
            }}
          >
            <LogOut className="size-4" /> Sign out
          </Button>
        </Panel>

        {/* Password */}
        <Panel className="p-5 lg:col-span-2">
          <h2 className="font-semibold">Change password</h2>
          <p className="mb-5 text-sm text-muted-foreground">
            {hasPassword
              ? "Use 8+ characters with a letter and a number."
              : "You sign in with Google, so there's no password to change."}
          </p>
          {hasPassword && <PasswordForm />}
        </Panel>
      </div>
    </>
  );
}

function PasswordForm() {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    const u = auth?.currentUser;
    if (!u?.email) return;
    if (next.length < 8 || !/\d/.test(next) || !/[A-Za-z]/.test(next)) {
      toast.error("New password needs 8+ characters with a letter and a number.");
      return;
    }
    if (next !== confirm) {
      toast.error("New passwords don't match.");
      return;
    }
    setBusy(true);
    try {
      await reauthenticateWithCredential(u, EmailAuthProvider.credential(u.email, current));
      await updatePassword(u, next);
      toast.success("Password changed");
      setCurrent("");
      setNext("");
      setConfirm("");
    } catch (err) {
      toast.error(authMessage(err).replace("Wrong email or password.", "Current password is wrong."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="grid max-w-md gap-4">
      {[
        { id: "cur", label: "Current password", v: current, set: setCurrent, ac: "current-password" },
        { id: "new", label: "New password", v: next, set: setNext, ac: "new-password" },
        { id: "con", label: "Confirm new password", v: confirm, set: setConfirm, ac: "new-password" },
      ].map((f) => (
        <div key={f.id} className="space-y-1.5">
          <Label htmlFor={f.id}>{f.label}</Label>
          <Input
            id={f.id}
            type="password"
            autoComplete={f.ac}
            value={f.v}
            onChange={(e) => f.set(e.target.value)}
            required
          />
        </div>
      ))}
      <Button type="submit" className="w-fit" disabled={busy}>
        Update password
      </Button>
    </form>
  );
}
