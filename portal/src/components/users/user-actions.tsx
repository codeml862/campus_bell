"use client";

import { useState } from "react";
import {
  Ban,
  CheckCircle2,
  MoreHorizontal,
  Pencil,
  Shield,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";

import {
  removeUser,
  setRole,
  setStatus,
  STAFF_ROLES,
  updateUser,
} from "@/lib/actions";
import { DEPARTMENTS, ROLES } from "@/lib/format";
import { useAdmin } from "@/hooks/use-admin";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { AppUser, Role } from "@/types";

async function attempt(fn: () => Promise<unknown>, ok: string) {
  try {
    await fn();
    toast.success(ok);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : "Something went wrong");
  }
}

/** Row menu: change role, edit details, disable / enable. */
export function UserActions({ user }: { user: AppUser }) {
  const { user: me, isAdmin, isHod, scopeDept } = useAdmin();
  const self = me?.uid === user.uid;
  const disabled = user.status === "disabled";
  const [editing, setEditing] = useState(false);
  const [removing, setRemoving] = useState(false);

  // Main administrator: everyone. HOD: staff/students of own department.
  const canManage =
    !self &&
    (isAdmin ||
      (isHod &&
        user.department === scopeDept &&
        STAFF_ROLES.includes(user.role)));
  const roles = isAdmin ? ROLES : STAFF_ROLES;

  if (!canManage) {
    return <span className="block w-9" aria-hidden />;
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger
          render={
            <Button variant="ghost" size="icon" aria-label={`Actions for ${user.name}`} />
          }
        >
          <MoreHorizontal className="size-4" />
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-52">
          <DropdownMenuGroup>
            <DropdownMenuLabel className="truncate">{user.name}</DropdownMenuLabel>
          </DropdownMenuGroup>
          <DropdownMenuSeparator />
          <DropdownMenuItem onClick={() => setEditing(true)}>
            <Pencil className="size-4" /> Edit details
          </DropdownMenuItem>
          <DropdownMenuSub>
            <DropdownMenuSubTrigger>
              <Shield className="size-4" /> Change role
            </DropdownMenuSubTrigger>
            <DropdownMenuSubContent>
              <DropdownMenuRadioGroup
                value={user.role}
                onValueChange={(v) =>
                  attempt(
                    () => setRole(user.uid, v as Role),
                    `${user.name} is now ${v}`,
                  )
                }
              >
                {roles.map((r) => (
                  <DropdownMenuRadioItem key={r} value={r}>
                    {r}
                  </DropdownMenuRadioItem>
                ))}
              </DropdownMenuRadioGroup>
            </DropdownMenuSubContent>
          </DropdownMenuSub>
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className={disabled ? undefined : "text-destructive"}
            onClick={() =>
              attempt(
                () => setStatus(user.uid, disabled ? "active" : "disabled"),
                disabled ? `${user.name} enabled` : `${user.name} disabled`,
              )
            }
          >
            {disabled ? (
              <>
                <CheckCircle2 className="size-4" /> Enable account
              </>
            ) : (
              <>
                <Ban className="size-4" /> Disable account
              </>
            )}
          </DropdownMenuItem>
          <DropdownMenuItem
            className="text-destructive"
            onClick={() => setRemoving(true)}
          >
            <Trash2 className="size-4" /> Remove from CampusBell
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <EditUserDialog
        user={user}
        open={editing}
        onOpenChange={setEditing}
        canChangeDept={isAdmin}
      />
      <Dialog open={removing} onOpenChange={setRemoving}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Remove {user.name}?</DialogTitle>
            <DialogDescription>
              Their CampusBell profile is deleted. They stop getting bells and
              must sign up again to use the app. This can&apos;t be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRemoving(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={async () => {
                await attempt(() => removeUser(user.uid), `${user.name} removed`);
                setRemoving(false);
              }}
            >
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

function EditUserDialog({
  user,
  open,
  onOpenChange,
  canChangeDept,
}: {
  user: AppUser;
  open: boolean;
  onOpenChange: (o: boolean) => void;
  canChangeDept: boolean;
}) {
  const [name, setName] = useState(user.name);
  const [dept, setDept] = useState(user.department);
  const [staffId, setStaffId] = useState(user.staffId ?? "");
  const [busy, setBusy] = useState(false);

  async function save() {
    if (name.trim().length < 2) {
      toast.error("Enter a name.");
      return;
    }
    setBusy(true);
    await attempt(
      () =>
        updateUser(user.uid, {
          name: name.trim(),
          // HODs can't move people to another department.
          ...(canChangeDept ? { department: dept } : {}),
          staffId: staffId.trim() || null,
        }),
      "Details saved",
    );
    setBusy(false);
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Edit details</DialogTitle>
          <DialogDescription>{user.email}</DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="name">Full name</Label>
            <Input id="name" value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="dept">Department</Label>
            <select
              id="dept"
              disabled={!canChangeDept}
              value={dept}
              onChange={(e) => setDept(e.target.value)}
              className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
            >
              {[...new Set([dept, ...DEPARTMENTS])].map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="sid">Employee / Student ID</Label>
            <Input
              id="sid"
              value={staffId}
              placeholder="Optional"
              onChange={(e) => setStaffId(e.target.value)}
            />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button onClick={save} disabled={busy}>
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
