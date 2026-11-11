"use client";

import { useMemo, useState } from "react";
import { ArrowRight, Search } from "lucide-react";

import { useBells } from "@/hooks/use-data";
import { useAdmin } from "@/hooks/use-admin";
import { fmtDate, STATUS, timeAgo } from "@/lib/format";
import { cn } from "@/lib/utils";
import {
  EmptyState,
  ErrorNote,
  LoadingRows,
  PageHeader,
  Panel,
} from "@/components/layout/page";
import { StatusBadge, UserAvatar } from "@/components/common";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { BellRequest, BellStatus } from "@/types";

const FILTERS: { key: "all" | BellStatus; label: string }[] = [
  { key: "all", label: "All" },
  { key: "accepted", label: "Accepted" },
  { key: "declined", label: "Declined" },
  { key: "delivered", label: "Waiting" },
  { key: "failed", label: "Not delivered" },
];

const PRIORITY_CLS: Record<string, string> = {
  urgent: "bg-rose-50 text-rose-700",
  high: "bg-amber-50 text-amber-700",
  normal: "bg-muted text-muted-foreground",
};

export default function BellsView() {
  const { isHod, user } = useAdmin();
  // HOD: bells they sent or received. Main administrator: all bells.
  const { data, loading, error } = useBells(500, isHod ? user?.uid : undefined);
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<"all" | BellStatus>("all");
  const [open, setOpen] = useState<BellRequest | null>(null);

  const rows = useMemo(() => {
    const s = q.trim().toLowerCase();
    return data.filter(
      (b) =>
        (filter === "all" ||
          b.status === filter ||
          (filter === "failed" && b.status === "rejected")) &&
        (!s ||
          b.senderName?.toLowerCase().includes(s) ||
          b.recipientName?.toLowerCase().includes(s) ||
          b.message?.toLowerCase().includes(s)),
    );
  }, [data, q, filter]);

  return (
    <>
      <PageHeader
        title="Bells"
        description="Every bell sent in the app, with answers and reasons."
      />

      <div className="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center">
        <div className="relative lg:w-80">
          <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search people or message"
            className="h-9 pl-9"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
        </div>
        <div className="flex gap-1.5 overflow-x-auto pb-1 lg:pb-0">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={cn(
                "shrink-0 rounded-full px-3 py-1.5 text-xs font-medium transition-colors",
                filter === f.key
                  ? "bg-primary text-primary-foreground"
                  : "bg-primary/10 text-primary hover:bg-primary/15",
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      <Panel>
        {error && <ErrorNote message={error} />}
        {loading ? (
          <LoadingRows />
        ) : rows.length === 0 ? (
          <EmptyState title="No bells found" text="Try a different search or filter." />
        ) : (
          <>
            <div className="hidden md:block">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="pl-5">From → To</TableHead>
                    <TableHead className="hidden lg:table-cell">Message</TableHead>
                    <TableHead>Priority</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="pr-5 text-right">Sent</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map((b) => (
                    <TableRow
                      key={b.id}
                      className="cursor-pointer"
                      onClick={() => setOpen(b)}
                    >
                      <TableCell className="pl-5">
                        <div className="flex items-center gap-2 font-medium">
                          <span className="truncate">{b.senderName}</span>
                          <ArrowRight className="size-3.5 shrink-0 text-muted-foreground" />
                          <span className="truncate">{b.recipientName}</span>
                        </div>
                      </TableCell>
                      <TableCell className="hidden max-w-xs truncate text-muted-foreground lg:table-cell">
                        {b.message || "Please come"}
                      </TableCell>
                      <TableCell>
                        <span
                          className={cn(
                            "rounded-full px-2 py-0.5 text-xs font-medium capitalize",
                            PRIORITY_CLS[b.priority] ?? PRIORITY_CLS.normal,
                          )}
                        >
                          {b.priority}
                        </span>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={b.status} />
                      </TableCell>
                      <TableCell className="pr-5 text-right text-muted-foreground">
                        {timeAgo(b.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>

            <ul className="divide-y md:hidden">
              {rows.map((b) => (
                <li key={b.id}>
                  <button
                    onClick={() => setOpen(b)}
                    className="flex w-full items-start gap-3 p-4 text-left"
                  >
                    <UserAvatar name={b.senderName} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">
                        {b.senderName} → {b.recipientName}
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {b.message || "Please come"}
                      </p>
                      <div className="mt-1.5 flex items-center gap-2">
                        <StatusBadge status={b.status} />
                        <span className="text-xs text-muted-foreground">
                          {timeAgo(b.createdAt)}
                        </span>
                      </div>
                    </div>
                  </button>
                </li>
              ))}
            </ul>
          </>
        )}
      </Panel>
      <p className="mt-3 text-xs text-muted-foreground">
        Showing {rows.length} of the latest {data.length} bells
      </p>

      <BellDialog bell={open} onClose={() => setOpen(null)} />
    </>
  );
}

function BellDialog({
  bell,
  onClose,
}: {
  bell: BellRequest | null;
  onClose: () => void;
}) {
  const b = bell;
  return (
    <Dialog open={!!b} onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="sm:max-w-md">
        {b && (
          <>
            <DialogHeader>
              <DialogTitle>Bell details</DialogTitle>
              <DialogDescription>{fmtDate(b.createdAt)}</DialogDescription>
            </DialogHeader>
            <div className="space-y-4 text-sm">
              <div className="grid grid-cols-2 gap-3">
                <Person label="From" name={b.senderName} role={b.senderRole} />
                <Person label="To" name={b.recipientName} role={b.recipientRole} />
              </div>
              <div className="rounded-lg bg-muted/60 p-3">
                <p className="mb-1 text-xs font-medium text-muted-foreground">Message</p>
                <p>{b.message || "Please come"}</p>
              </div>
              <dl className="divide-y rounded-lg border">
                <Row label="Status">
                  <StatusBadge status={b.status} />
                </Row>
                <Row label="Priority">
                  <span className="capitalize">{b.priority}</span>
                </Row>
                {b.status === "declined" && (
                  <Row label="Reason">{b.reason || "No reason given"}</Row>
                )}
                {(b.status === "failed" || b.status === "rejected") && (
                  <Row label="Problem">{STATUS[b.status].label}</Row>
                )}
              </dl>
            </div>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}

function Person({ label, name, role }: { label: string; name: string; role: string }) {
  return (
    <div className="flex items-center gap-2 rounded-lg border p-2.5">
      <UserAvatar name={name} className="size-8" />
      <div className="min-w-0">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="truncate font-medium">{name}</p>
        <p className="truncate text-xs text-muted-foreground">{role}</p>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-3 px-3 py-2.5">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="text-right">{children}</dd>
    </div>
  );
}
