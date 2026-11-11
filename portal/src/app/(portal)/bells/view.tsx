"use client";

import { useMemo, useState } from "react";
import { ArrowRight, ChevronLeft, ChevronRight, Search } from "lucide-react";

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

const PAGE_SIZES = [10, 25, 50, 100];
const FETCH_STEP = 500;

const PRIORITY_CLS: Record<string, string> = {
  urgent: "bg-rose-50 text-rose-700",
  high: "bg-amber-50 text-amber-700",
  normal: "bg-muted text-muted-foreground",
};

export default function BellsView() {
  const { isHod, user } = useAdmin();
  // HOD: bells they sent or received. Main administrator: all bells.
  // Newest bells first; "Load older" fetches 500 more at a time.
  const [max, setMax] = useState(FETCH_STEP);
  const { data, loading, error } = useBells(max, isHod ? user?.uid : undefined);
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState<"all" | BellStatus>("all");
  const [size, setSize] = useState(25);
  const [page, setPage] = useState(0);
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

  const pages = Math.max(1, Math.ceil(rows.length / size));
  const cur = Math.min(page, pages - 1);
  const shown = rows.slice(cur * size, cur * size + size);
  const from = rows.length === 0 ? 0 : cur * size + 1;
  const to = Math.min(rows.length, cur * size + size);
  const go = (p: number) => {
    setPage(Math.max(0, Math.min(pages - 1, p)));
    document
      .getElementById("bells-scroll")
      ?.scrollTo({ top: 0, behavior: "smooth" });
  };

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
            onChange={(e) => {
              setQ(e.target.value);
              setPage(0);
            }}
          />
        </div>
        <div className="flex gap-1.5 overflow-x-auto pb-1 lg:pb-0">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => {
                setFilter(f.key);
                setPage(0);
              }}
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
            <div
              id="bells-scroll"
              className="max-h-[calc(100vh-17rem)] overflow-y-auto md:max-h-[calc(100vh-15rem)]"
            >
            <div className="hidden md:block">
              <Table>
                <TableHeader className="sticky top-0 z-10 bg-card shadow-[0_1px_0_var(--border)]">
                  <TableRow>
                    <TableHead className="pl-5">From → To</TableHead>
                    <TableHead className="hidden lg:table-cell">Message</TableHead>
                    <TableHead>Priority</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="pr-5 text-right">Sent</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {shown.map((b) => (
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
              {shown.map((b) => (
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
            </div>
          </>
        )}
        {!loading && rows.length > 0 && (
          <div className="flex flex-col gap-3 border-t px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between">
            <div className="flex items-center gap-2 text-muted-foreground">
              <span>
                {from}–{to} of {rows.length}
              </span>
              <span className="hidden sm:inline">·</span>
              <label className="flex items-center gap-1.5">
                Rows
                <select
                  value={size}
                  onChange={(e) => {
                    setSize(Number(e.target.value));
                    setPage(0);
                  }}
                  className="h-8 rounded-md border bg-background px-2 text-foreground"
                >
                  {PAGE_SIZES.map((n) => (
                    <option key={n} value={n}>
                      {n}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <div className="flex items-center gap-1">
              <PageBtn label="Previous page" disabled={cur === 0} onClick={() => go(cur - 1)}>
                <ChevronLeft className="size-4" />
              </PageBtn>
              {pageList(cur, pages).map((p, i) =>
                p < 0 ? (
                  <span key={`gap${i}`} className="px-1 text-muted-foreground">
                    …
                  </span>
                ) : (
                  <PageBtn
                    key={p}
                    label={`Page ${p + 1}`}
                    active={p === cur}
                    onClick={() => go(p)}
                  >
                    {p + 1}
                  </PageBtn>
                ),
              )}
              <PageBtn
                label="Next page"
                disabled={cur >= pages - 1}
                onClick={() => go(cur + 1)}
              >
                <ChevronRight className="size-4" />
              </PageBtn>
            </div>
          </div>
        )}
      </Panel>
      <div className="mt-3 flex items-center justify-between gap-3 text-xs text-muted-foreground">
        <span>
          Loaded the latest {data.length} bells
          {data.length >= max ? " (older ones not loaded yet)" : ""}
        </span>
        {data.length >= max && (
          <button
            onClick={() => setMax((m) => m + FETCH_STEP)}
            className="rounded-full bg-primary/10 px-3 py-1.5 font-medium text-primary hover:bg-primary/15"
          >
            Load older bells
          </button>
        )}
      </div>

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

/** Page numbers to show: first, last, and two around the current one. */
function pageList(cur: number, pages: number): number[] {
  const set = new Set([0, pages - 1, cur - 1, cur, cur + 1]);
  const list = [...set].filter((p) => p >= 0 && p < pages).sort((a, b) => a - b);
  const out: number[] = [];
  list.forEach((p, i) => {
    if (i > 0 && p - list[i - 1] > 1) out.push(-1);
    out.push(p);
  });
  return out;
}

function PageBtn({
  children,
  label,
  onClick,
  disabled,
  active,
}: {
  children: React.ReactNode;
  label: string;
  onClick: () => void;
  disabled?: boolean;
  active?: boolean;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-current={active ? "page" : undefined}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "flex size-8 items-center justify-center rounded-md text-sm font-medium transition-colors",
        active
          ? "bg-primary text-primary-foreground"
          : "text-foreground hover:bg-muted",
        disabled && "pointer-events-none opacity-40",
      )}
    >
      {children}
    </button>
  );
}
