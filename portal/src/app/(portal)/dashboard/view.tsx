"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ArrowRight, BellRing, CheckCircle2, ShieldCheck, Users } from "lucide-react";

import { useBells, useUsers } from "@/hooks/use-data";
import { useAdmin } from "@/hooks/use-admin";
import { isToday, ROLES, timeAgo } from "@/lib/format";
import {
  EmptyState,
  ErrorNote,
  LoadingRows,
  PageHeader,
  Panel,
} from "@/components/layout/page";
import { StatusBadge, UserAvatar } from "@/components/common";

export default function DashboardView() {
  const { profile, scopeDept, isHod, user } = useAdmin();
  const users = useUsers();
  const bells = useBells(500, isHod ? user?.uid : undefined);

  // "Today" is read on the client after mount (not during prerender).
  const [now, setNow] = useState<Date | null>(null);
  useEffect(() => setNow(new Date()), []);

  // HOD: their department only.
  const u = scopeDept
    ? users.data.filter((x) => x.department === scopeDept)
    : users.data;
  const b = bells.data;
  const today = b.filter((x) => isToday(x.createdAt));
  const answered = b.filter((x) => x.status === "accepted" || x.status === "declined");
  const acceptRate = answered.length
    ? Math.round((answered.filter((x) => x.status === "accepted").length / answered.length) * 100)
    : null;

  // Last 7 days, oldest first.
  const days = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now ?? 0);
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - (6 - i));
    return d;
  });
  const perDay = days.map(
    (d) =>
      b.filter((x) => {
        const t = x.createdAt;
        return (
          t &&
          t.getFullYear() === d.getFullYear() &&
          t.getMonth() === d.getMonth() &&
          t.getDate() === d.getDate()
        );
      }).length,
  );
  const maxDay = Math.max(1, ...perDay);

  const stats = [
    { label: "Total users", value: u.length, icon: Users, href: "/users" },
    {
      label: "Admins",
      value: u.filter((x) => x.role === "Administrator").length,
      icon: ShieldCheck,
      href: "/admins",
    },
    { label: "Bells today", value: today.length, icon: BellRing, href: "/bells" },
    {
      label: "Accept rate",
      value: acceptRate === null ? "—" : `${acceptRate}%`,
      icon: CheckCircle2,
      href: "/bells",
    },
  ];

  const loading = users.loading || bells.loading;
  const error = users.error || bells.error;

  return (
    <>
      <PageHeader
        title={`Welcome${profile?.name ? `, ${profile.name.split(" ")[0]}` : ""}`}
        description={
          scopeDept
            ? `HOD · ${scopeDept}`
            : "Main administrator · live overview of the whole campus."
        }
      />

      {error && <ErrorNote message={error} />}

      {/* Stat cards: 1 col mobile, 2 tablet, 4 desktop */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((s) => (
          <Link key={s.label} href={s.href}>
            <Panel className="flex items-center gap-4 p-4 transition-colors hover:border-primary/40">
              <div className="flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary">
                <s.icon className="size-5" />
              </div>
              <div>
                <p className="text-sm text-muted-foreground">{s.label}</p>
                <p className="text-2xl font-semibold tracking-tight">
                  {loading ? "…" : s.value}
                </p>
              </div>
            </Panel>
          </Link>
        ))}
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* 7-day chart */}
        <Panel className="p-5 lg:col-span-2">
          <div className="mb-5 flex items-baseline justify-between">
            <h2 className="font-semibold">Bells, last 7 days</h2>
            <span className="text-sm text-muted-foreground">
              {perDay.reduce((a, c) => a + c, 0)} total
            </span>
          </div>
          <div className="flex h-44 items-end gap-2 sm:gap-4">
            {perDay.map((n, i) => (
              <div key={i} className="flex flex-1 flex-col items-center gap-2">
                <span className="text-xs font-medium text-muted-foreground">
                  {n || ""}
                </span>
                <div
                  className={`w-full max-w-10 rounded-md ${i === 6 ? "bg-primary" : "bg-primary/20"}`}
                  style={{ height: `${Math.max(4, (n / maxDay) * 120)}px` }}
                />
                <span className="text-xs text-muted-foreground">
                  {now ? days[i].toLocaleDateString("en-IN", { weekday: "short" }) : ""}
                </span>
              </div>
            ))}
          </div>
        </Panel>

        {/* Users by role */}
        <Panel className="p-5">
          <h2 className="mb-4 font-semibold">Users by role</h2>
          <ul className="space-y-3">
            {ROLES.map((r) => {
              const n = u.filter((x) => x.role === r).length;
              const pct = u.length ? (n / u.length) * 100 : 0;
              return (
                <li key={r} className="space-y-1">
                  <div className="flex justify-between text-sm">
                    <span>{r}</span>
                    <span className="font-medium">{n}</span>
                  </div>
                  <div className="h-1.5 rounded-full bg-muted">
                    <div
                      className="h-1.5 rounded-full bg-primary"
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </li>
              );
            })}
          </ul>
        </Panel>
      </div>

      {/* Recent bells */}
      <Panel className="mt-6">
        <div className="flex items-center justify-between border-b px-5 py-4">
          <h2 className="font-semibold">Recent bells</h2>
          <Link
            href="/bells"
            className="flex items-center gap-1 text-sm font-medium text-primary hover:underline"
          >
            View all <ArrowRight className="size-4" />
          </Link>
        </div>
        {bells.loading ? (
          <LoadingRows rows={4} />
        ) : b.length === 0 ? (
          <EmptyState title="No bells yet" text="Bells sent in the app will show up here." />
        ) : (
          <ul className="divide-y">
            {b.slice(0, 6).map((x) => (
              <li key={x.id} className="flex items-center gap-3 px-5 py-3">
                <UserAvatar name={x.senderName} />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm">
                    <span className="font-medium">{x.senderName}</span>
                    <span className="text-muted-foreground"> → </span>
                    <span className="font-medium">{x.recipientName}</span>
                  </p>
                  <p className="truncate text-xs text-muted-foreground">
                    {x.message || "Please come"}
                  </p>
                </div>
                <div className="hidden text-right sm:block">
                  <StatusBadge status={x.status} />
                  <p className="mt-1 text-xs text-muted-foreground">
                    {timeAgo(x.createdAt)}
                  </p>
                </div>
              </li>
            ))}
          </ul>
        )}
      </Panel>
    </>
  );
}
