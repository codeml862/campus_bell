import { initials, STATUS } from "@/lib/format";
import { cn } from "@/lib/utils";
import type { BellStatus, Role } from "@/types";

export function UserAvatar({
  name,
  className,
}: {
  name: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-semibold text-primary",
        className,
      )}
    >
      {initials(name)}
    </div>
  );
}

export function StatusBadge({ status }: { status: BellStatus }) {
  const s = STATUS[status] ?? STATUS.pending;
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        s.cls,
      )}
    >
      {s.label}
    </span>
  );
}

export function RoleBadge({ role }: { role: Role | string }) {
  const admin = role === "Administrator";
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium",
        admin ? "bg-primary text-primary-foreground" : "bg-primary/10 text-primary",
      )}
    >
      {role}
    </span>
  );
}

export function ActiveDot({ disabled }: { disabled: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
      <span
        className={cn(
          "size-1.5 rounded-full",
          disabled ? "bg-rose-500" : "bg-emerald-500",
        )}
      />
      {disabled ? "Disabled" : "Active"}
    </span>
  );
}
