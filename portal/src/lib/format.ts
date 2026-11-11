import type { BellStatus, Role } from "@/types";

/** Same lists as the app (lib/core/theme.dart, lib/models/models.dart). */
export const ROLES: Role[] = [
  "Administrator",
  "HOD",
  "Professor",
  "Assistant",
  "Student",
];

export const DEPARTMENTS = [
  "Computer Science & Engineering",
  "Information Technology",
  "Electronics & Communication",
  "Electrical & Electronics",
  "Mechanical Engineering",
  "Civil Engineering",
  "MBA",
  "Administration",
  "Other",
];

export function deptShort(d: string) {
  const map: Record<string, string> = {
    "Computer Science & Engineering": "CSE",
    "Information Technology": "IT",
    "Electronics & Communication": "ECE",
    "Electrical & Electronics": "EEE",
    "Mechanical Engineering": "MECH",
    "Civil Engineering": "CIVIL",
  };
  return map[d] ?? d;
}

export function initials(name: string) {
  return (
    name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((p) => p[0]?.toUpperCase() ?? "")
      .join("") || "?"
  );
}

export function timeAgo(d?: Date) {
  if (!d) return "—";
  const s = Math.round((Date.now() - d.getTime()) / 1000);
  if (s < 60) return "just now";
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} h ago`;
  const days = Math.round(h / 24);
  if (days < 7) return `${days} d ago`;
  return fmtDate(d);
}

export function fmtDate(d?: Date) {
  if (!d) return "—";
  return d.toLocaleString("en-IN", {
    day: "numeric",
    month: "short",
    hour: "numeric",
    minute: "2-digit",
  });
}

export function isToday(d?: Date) {
  if (!d) return false;
  const n = new Date();
  return (
    d.getFullYear() === n.getFullYear() &&
    d.getMonth() === n.getMonth() &&
    d.getDate() === n.getDate()
  );
}

/** Label + Tailwind classes for a bell status badge. */
export const STATUS: Record<BellStatus, { label: string; cls: string }> = {
  pending: { label: "Sending", cls: "bg-amber-50 text-amber-700" },
  delivered: { label: "Delivered", cls: "bg-blue-50 text-blue-700" },
  accepted: { label: "Accepted", cls: "bg-emerald-50 text-emerald-700" },
  declined: { label: "Declined", cls: "bg-rose-50 text-rose-700" },
  failed: { label: "Not delivered", cls: "bg-rose-50 text-rose-700" },
  rejected: { label: "Rejected", cls: "bg-rose-50 text-rose-700" },
};
