"use client";

import Link from "next/link";
import { ArrowRight, Building2 } from "lucide-react";

import { useUsers } from "@/hooks/use-data";
import { useAdmin } from "@/hooks/use-admin";
import { DEPARTMENTS, deptShort } from "@/lib/format";
import { ErrorNote, LoadingRows, PageHeader, Panel } from "@/components/layout/page";

const ROLE_ORDER = ["HOD", "Professor", "Assistant", "Student", "Administrator"];

export default function DepartmentsView() {
  const { data, loading, error } = useUsers();
  const { scopeDept } = useAdmin();

  // Known departments plus any extra ones people picked.
  const names = scopeDept
    ? [scopeDept]
    : [...new Set([...DEPARTMENTS, ...data.map((u) => u.department).filter(Boolean)])];
  const depts = names
    .map((name) => {
      const people = data.filter((u) => u.department === name);
      const byRole = ROLE_ORDER.map((r) => ({
        role: r,
        n: people.filter((u) => u.role === r).length,
      })).filter((x) => x.n > 0);
      return { name, total: people.length, byRole };
    })
    .sort((a, b) => b.total - a.total);

  return (
    <>
      <PageHeader
        title="Departments"
        description="How many people are in each department. Click one to see them."
      />
      {error && <ErrorNote message={error} />}
      {loading ? (
        <Panel>
          <LoadingRows />
        </Panel>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {depts.map((d) => (
            <Link key={d.name} href={`/users?department=${encodeURIComponent(d.name)}`}>
              <Panel className="h-full p-5 transition-colors hover:border-primary/40">
                <div className="flex items-start gap-3">
                  <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-primary">
                    <Building2 className="size-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{deptShort(d.name)}</p>
                    <p className="truncate text-xs text-muted-foreground">{d.name}</p>
                  </div>
                  <span className="text-2xl font-semibold tracking-tight">{d.total}</span>
                </div>
                <div className="mt-4 flex flex-wrap gap-1.5">
                  {d.byRole.length === 0 ? (
                    <span className="text-xs text-muted-foreground">No one yet</span>
                  ) : (
                    d.byRole.map((r) => (
                      <span
                        key={r.role}
                        className="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-medium text-primary"
                      >
                        {r.n} {r.role}
                      </span>
                    ))
                  )}
                </div>
                <p className="mt-4 flex items-center gap-1 text-xs font-medium text-primary">
                  View people <ArrowRight className="size-3.5" />
                </p>
              </Panel>
            </Link>
          ))}
        </div>
      )}
    </>
  );
}
