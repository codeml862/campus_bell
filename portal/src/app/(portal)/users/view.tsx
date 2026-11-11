"use client";

import { Suspense, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Search } from "lucide-react";

import { useUsers } from "@/hooks/use-data";
import { useAdmin } from "@/hooks/use-admin";
import { deptShort, ROLES } from "@/lib/format";
import { cn } from "@/lib/utils";
import {
  EmptyState,
  ErrorNote,
  LoadingRows,
  PageHeader,
  Panel,
} from "@/components/layout/page";
import { ActiveDot, RoleBadge, UserAvatar } from "@/components/common";
import { UserActions } from "@/components/users/user-actions";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function UsersView() {
  return (
    <Suspense>
      <UsersContent />
    </Suspense>
  );
}

function UsersContent() {
  const params = useSearchParams();
  const { data: all, loading, error } = useUsers();
  const { scopeDept } = useAdmin();
  // HOD: only their own department.
  const data = scopeDept ? all.filter((u) => u.department === scopeDept) : all;
  const [q, setQ] = useState("");
  const [role, setRole] = useState<string>("All");
  const [status, setStatus] = useState<"all" | "active" | "disabled">("all");
  const dept = params.get("department");

  const rows = useMemo(() => {
    const s = q.trim().toLowerCase();
    return data.filter(
      (u) =>
        (role === "All" || u.role === role) &&
        (status === "all" || (u.status ?? "active") === status) &&
        (!dept || u.department === dept) &&
        (!s ||
          u.name?.toLowerCase().includes(s) ||
          u.email?.toLowerCase().includes(s) ||
          (u.username ?? "").includes(s) ||
          (u.staffId ?? "").toLowerCase().includes(s)),
    );
  }, [data, q, role, status, dept]);

  return (
    <>
      <PageHeader
        title="Users"
        description={
          scopeDept
            ? `People in your department (${scopeDept}). You can manage professors, assistants and students.`
            : dept
            ? `Everyone in ${dept}.`
            : "Everyone who signed up in the CampusBell app."
        }
      />

      {/* Filters: stack on mobile, one row on desktop */}
      <div className="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="relative lg:w-80">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search name, email or ID"
            className="h-9 pl-9"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        <div className="flex gap-1.5 overflow-x-auto pb-1 lg:pb-0">
          {["All", ...ROLES].map((r) => (
            <button
              key={r}
              onClick={() => setRole(r)}
              className={cn(
                "shrink-0 rounded-full px-3 py-1.5 text-xs font-medium transition-colors",
                role === r
                  ? "bg-primary text-primary-foreground"
                  : "bg-primary/10 text-primary hover:bg-primary/15",
              )}
            >
              {r}
            </button>
          ))}
        </div>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as typeof status)}
          className="h-9 rounded-md border bg-background px-3 text-sm lg:ml-auto"
          aria-label="Status"
        >
          <option value="all">All statuses</option>
          <option value="active">Active</option>
          <option value="disabled">Disabled</option>
        </select>
      </div>

      <Panel>
        {error && <ErrorNote message={error} />}
        {loading ? (
          <LoadingRows />
        ) : rows.length === 0 ? (
          <EmptyState title="No users found" text="Try a different search or filter." />
        ) : (
          <>
            {/* Desktop / laptop: table */}
            <div className="hidden md:block">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="pl-5">User</TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead className="hidden lg:table-cell">Department</TableHead>
                    <TableHead className="hidden xl:table-cell">ID</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="w-12" />
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((u) => (
                    <TableRow key={u.uid}>
                      <TableCell className="pl-5">
                        <div className="flex items-center gap-3">
                          <UserAvatar name={u.name} />
                          <div className="min-w-0">
                            <p className="truncate font-medium">{u.name}</p>
                            <p className="truncate text-xs text-muted-foreground">
                              {u.email}
                            </p>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <RoleBadge role={u.role} />
                      </TableCell>
                      <TableCell className="hidden lg:table-cell">
                        {deptShort(u.department)}
                      </TableCell>
                      <TableCell className="hidden text-muted-foreground xl:table-cell">
                        {u.staffId || "—"}
                      </TableCell>
                      <TableCell>
                        <ActiveDot disabled={u.status === "disabled"} />
                      </TableCell>
                      <TableCell>
                        <UserActions user={u} />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            {/* Mobile: cards */}
            <ul className="divide-y md:hidden">
              {rows.map((u) => (
                <li key={u.uid} className="flex items-center gap-3 p-4">
                  <UserAvatar name={u.name} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-medium">{u.name}</p>
                    <div className="mt-1 flex flex-wrap items-center gap-2">
                      <RoleBadge role={u.role} />
                      <span className="text-xs text-muted-foreground">
                        {deptShort(u.department)}
                      </span>
                      <ActiveDot disabled={u.status === "disabled"} />
                    </div>
                  </div>
                  <UserActions user={u} />
                </li>
              ))}
            </ul>
          </>
        )}
      </Panel>
      <p className="mt-3 text-xs text-muted-foreground">
        {rows.length} of {data.length} users
      </p>
    </>
  );
}
