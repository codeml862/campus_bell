"use client";

import { useMemo, useState } from "react";
import { Search, ShieldCheck, ShieldMinus, UserPlus } from "lucide-react";
import { toast } from "sonner";

import { setRole } from "@/lib/actions";
import { deptShort, ROLES } from "@/lib/format";
import { useUsers } from "@/hooks/use-data";
import { useAdmin } from "@/hooks/use-admin";
import {
  EmptyState,
  ErrorNote,
  LoadingRows,
  PageHeader,
  Panel,
} from "@/components/layout/page";
import { RoleBadge, UserAvatar } from "@/components/common";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import type { AppUser, Role } from "@/types";

export default function AdminsView() {
  const { data, loading, error } = useUsers();
  const { user: me } = useAdmin();
  const [adding, setAdding] = useState(false);
  const [removing, setRemoving] = useState<AppUser | null>(null);

  const admins = data.filter((u) => u.role === "Administrator");
  const others = data.filter(
    (u) => u.role !== "Administrator" && u.status !== "disabled",
  );

  return (
    <>
      <PageHeader
        title="Admins"
        description="Admins can use this portal and manage everyone in the app."
        actions={
          <Button onClick={() => setAdding(true)}>
            <UserPlus className="size-4" /> Add admin
          </Button>
        }
      />

      <Panel>
        {error && <ErrorNote message={error} />}
        {loading ? (
          <LoadingRows rows={3} />
        ) : admins.length === 0 ? (
          <EmptyState
            title="No admins yet"
            text="Add someone as an admin to let them manage CampusBell."
          />
        ) : (
          <ul className="divide-y">
            {admins.map((a) => (
              <li key={a.uid} className="flex flex-wrap items-center gap-3 p-4 sm:px-5">
                <UserAvatar name={a.name} />
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">
                    {a.name}
                    {a.uid === me?.uid && (
                      <span className="ml-2 text-xs font-normal text-muted-foreground">
                        (you)
                      </span>
                    )}
                  </p>
                  <p className="truncate text-xs text-muted-foreground">
                    {a.email} · {deptShort(a.department)}
                  </p>
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={a.uid === me?.uid}
                  onClick={() => setRemoving(a)}
                >
                  <ShieldMinus className="size-4" /> Remove admin
                </Button>
              </li>
            ))}
          </ul>
        )}
      </Panel>

      <AddAdminDialog open={adding} onOpenChange={setAdding} users={others} />
      <RemoveAdminDialog user={removing} onClose={() => setRemoving(null)} />
    </>
  );
}

function AddAdminDialog({
  open,
  onOpenChange,
  users,
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  users: AppUser[];
}) {
  const [q, setQ] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const list = useMemo(() => {
    const s = q.trim().toLowerCase();
    return users
      .filter(
        (u) =>
          !s ||
          u.name?.toLowerCase().includes(s) ||
          u.email?.toLowerCase().includes(s),
      )
      .slice(0, 50);
  }, [users, q]);

  async function make(u: AppUser) {
    setBusy(u.uid);
    try {
      await setRole(u.uid, "Administrator");
      toast.success(`${u.name} is now an admin`);
      onOpenChange(false);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not add admin");
    } finally {
      setBusy(null);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Add admin</DialogTitle>
          <DialogDescription>
            Pick a person. They get admin access in the portal and the app.
          </DialogDescription>
        </DialogHeader>
        <div className="relative">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            autoFocus
            placeholder="Search name or email"
            className="pl-9"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        <ul className="-mx-2 max-h-80 overflow-y-auto">
          {list.length === 0 && (
            <li className="px-2 py-6 text-center text-sm text-muted-foreground">
              No one found.
            </li>
          )}
          {list.map((u) => (
            <li key={u.uid}>
              <button
                disabled={busy !== null}
                onClick={() => make(u)}
                className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-muted disabled:opacity-60"
              >
                <UserAvatar name={u.name} className="size-8" />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium">{u.name}</p>
                  <p className="truncate text-xs text-muted-foreground">{u.email}</p>
                </div>
                <RoleBadge role={u.role} />
                <ShieldCheck className="size-4 text-primary" />
              </button>
            </li>
          ))}
        </ul>
      </DialogContent>
    </Dialog>
  );
}

function RemoveAdminDialog({
  user,
  onClose,
}: {
  user: AppUser | null;
  onClose: () => void;
}) {
  const [role, setNewRole] = useState<Role>("Professor");
  const [busy, setBusy] = useState(false);

  async function remove() {
    if (!user) return;
    setBusy(true);
    try {
      await setRole(user.uid, role);
      toast.success(`${user.name} is now ${role}`);
      onClose();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not remove admin");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={!!user} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Remove admin</DialogTitle>
          <DialogDescription>
            {user?.name} will lose portal access. Choose their new role.
          </DialogDescription>
        </DialogHeader>
        <select
          value={role}
          onChange={(e) => setNewRole(e.target.value as Role)}
          className="h-9 w-full rounded-md border bg-background px-3 text-sm"
        >
          {ROLES.filter((r) => r !== "Administrator").map((r) => (
            <option key={r} value={r}>
              {r}
            </option>
          ))}
        </select>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="destructive" onClick={remove} disabled={busy}>
            Remove admin
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
