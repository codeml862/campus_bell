"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { QRCodeSVG } from "qrcode.react";
import {
  Bell,
  Download,
  QrCode,
  Copy,
  Check,
  Smartphone,
  ShieldCheck,
  Zap,
  Lock,
  X,
  ArrowRight,
  Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

const APP_URL = "https://campus-bell-seven.vercel.app";

export default function LandingPage() {
  const router = useRouter();
  const [copied, setCopied] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [password, setPassword] = useState("");
  const [error, setError] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(APP_URL);
      setCopied(true);
      toast.success("Link copied to clipboard!");
      setTimeout(() => setCopied(false), 2000);
    } catch {
      toast.error("Could not copy link");
    }
  };

  const openBailiffModal = () => {
    setPassword("");
    setError(false);
    setShowModal(true);
  };

  const closeBailiffModal = () => {
    setShowModal(false);
    setPassword("");
    setError(false);
  };

  const handlePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!password.trim() || submitting) return;

    setSubmitting(true);
    setError(false);
    try {
      const res = await fetch("/api/bailiff-verify", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ password }),
      });
      if (res.ok) {
        toast.success("Access granted!");
        setShowModal(false);
        router.push("/login");
      } else {
        setError(true);
        toast.error("Incorrect password. Please try again.");
      }
    } catch {
      toast.error("Verification failed. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-gradient-to-b from-slate-50 via-white to-slate-100 px-4 py-12 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950">
      {/* Background soft ambient blur effects */}
      <div className="pointer-events-none absolute -top-40 left-1/2 -z-10 h-96 w-96 -translate-x-1/2 rounded-full bg-blue-500/15 blur-3xl" />
      <div className="pointer-events-none absolute -bottom-40 left-1/2 -z-10 h-96 w-96 -translate-x-1/2 rounded-full bg-indigo-500/10 blur-3xl" />

      {/* Top Navbar / Header with Bailiff quick button */}
      <header className="absolute top-0 left-0 right-0 flex items-center justify-between px-6 py-4 max-w-6xl mx-auto w-full">
        <div className="flex items-center gap-2.5">
          <div className="flex size-9 items-center justify-center rounded-xl bg-blue-600 text-white shadow-sm">
            <Bell className="size-5" />
          </div>
          <span className="font-bold text-lg tracking-tight text-slate-900 dark:text-white">
            CampusBell
          </span>
        </div>

        <Button
          type="button"
          onClick={openBailiffModal}
          variant="outline"
          size="sm"
          className="font-medium border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
        >
          Bailiff
        </Button>
      </header>

      {/* Middle Hero Section Container */}
      <section className="mx-auto flex w-full max-w-2xl flex-col items-center text-center">
        {/* Release Tag Pill */}
        <div className="inline-flex items-center gap-2 rounded-full border border-blue-200 bg-blue-50/80 px-3.5 py-1 text-xs font-semibold text-blue-700 shadow-xs backdrop-blur-xs dark:border-blue-900/60 dark:bg-blue-950/40 dark:text-blue-300">
          <span className="flex size-2 rounded-full bg-blue-600 animate-pulse" />
          CampusBell v1.0.0 · Android Official Release
        </div>

        {/* App Icon */}
        <div className="mt-6 flex size-20 items-center justify-center rounded-3xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-blue-500 text-white shadow-xl shadow-blue-500/25 ring-8 ring-blue-500/10 transition-transform hover:scale-105">
          <Bell className="size-10" />
        </div>

        {/* Heading */}
        <h1 className="mt-5 text-3xl font-extrabold tracking-tight text-slate-900 sm:text-5xl dark:text-white">
          CampusBell
        </h1>

        <p className="mt-3 text-base font-medium text-slate-600 sm:text-lg dark:text-slate-300 max-w-xl">
          Real-time smart bell alerts, notices, and staff notifications for
          colleges and campus departments.
        </p>

        {/* Hero Action Buttons */}
        <div className="mt-7 flex flex-wrap items-center justify-center gap-3 w-full max-w-md">
          {/* Download APK Button */}
          <a
            href="/CampusBell.apk"
            download="CampusBell.apk"
            className="flex-1 min-w-[200px]"
          >
            <Button
              size="lg"
              className="w-full gap-2 bg-blue-600 hover:bg-blue-700 text-white shadow-md shadow-blue-600/25 font-semibold text-base h-12 rounded-xl cursor-pointer"
            >
              <Download className="size-5" />
              Download APK <span className="text-xs opacity-80">(10.2 MB)</span>
            </Button>
          </a>

          {/* Bailiff Button */}
          <div className="flex-1 min-w-[150px]">
            <Button
              type="button"
              onClick={openBailiffModal}
              variant="outline"
              size="lg"
              className="w-full border-slate-300 dark:border-slate-700 font-semibold text-base h-12 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
            >
              Bailiff
            </Button>
          </div>
        </div>

        {/* QR Code Section Card */}
        <div className="mt-8 w-full max-w-sm rounded-2xl border border-slate-200/90 bg-white/90 p-6 shadow-xl shadow-slate-200/50 backdrop-blur-md dark:border-slate-800 dark:bg-slate-900/90 dark:shadow-none">
          <div className="flex items-center justify-center gap-2 text-xs font-semibold uppercase tracking-wider text-slate-500 dark:text-slate-400">
            <QrCode className="size-4 text-blue-600" />
            Scan to Install on Phone
          </div>

          {/* QR Code Canvas/SVG */}
          <div className="mt-4 flex justify-center">
            <div className="rounded-xl border border-slate-200 bg-white p-3 shadow-inner dark:border-slate-700">
              <QRCodeSVG
                value={APP_URL}
                size={180}
                level="M"
                includeMargin={false}
                imageSettings={{
                  src: "/icon.png",
                  x: undefined,
                  y: undefined,
                  height: 32,
                  width: 32,
                  excavate: true,
                }}
              />
            </div>
          </div>

          <p className="mt-3.5 text-xs text-slate-500 dark:text-slate-400">
            Scan with your phone to open{" "}
            <span className="font-semibold text-blue-600 dark:text-blue-400">
              campus-bell-seven.vercel.app
            </span>
          </p>

          {/* Copy Direct Link Button */}
          <button
            onClick={copyLink}
            type="button"
            className="mt-3.5 inline-flex items-center gap-1.5 text-xs font-semibold text-blue-600 hover:text-blue-700 dark:text-blue-400 dark:hover:text-blue-300 transition-colors cursor-pointer"
          >
            {copied ? (
              <>
                <Check className="size-3.5 text-emerald-600" />
                Copied to clipboard!
              </>
            ) : (
              <>
                <Copy className="size-3.5" />
                Copy website link to share on WhatsApp
              </>
            )}
          </button>
        </div>

        {/* Feature Badges */}
        <div className="mt-8 flex flex-wrap items-center justify-center gap-6 text-xs text-slate-500 dark:text-slate-400">
          <div className="flex items-center gap-1.5">
            <Zap className="size-4 text-amber-500" />
            <span>Instant Ring Notifications</span>
          </div>
          <div className="flex items-center gap-1.5">
            <ShieldCheck className="size-4 text-emerald-500" />
            <span>Verified Release Build</span>
          </div>
          <div className="flex items-center gap-1.5">
            <Smartphone className="size-4 text-blue-500" />
            <span>Android 8.0+ Compatible</span>
          </div>
        </div>
      </section>

      {/* Bailiff Password Dialog Modal */}
      {showModal && (
        <div
          role="dialog"
          aria-modal="true"
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs animate-in fade-in-0 duration-150"
          onClick={closeBailiffModal}
        >
          <div
            className="relative w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-6 shadow-2xl dark:border-slate-800 dark:bg-slate-900 animate-in zoom-in-95 duration-150"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Close button */}
            <button
              type="button"
              onClick={closeBailiffModal}
              className="absolute top-4 right-4 rounded-lg p-1 text-slate-400 hover:bg-slate-100 hover:text-slate-700 dark:hover:bg-slate-800 dark:hover:text-slate-200 transition-colors cursor-pointer"
            >
              <X className="size-4" />
            </button>

            {/* Header */}
            <div className="flex items-center gap-3">
              <div className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-blue-100 text-blue-600 dark:bg-blue-950 dark:text-blue-400">
                <Lock className="size-5" />
              </div>
              <div>
                <h3 className="text-base font-bold text-slate-900 dark:text-white">
                  Bailiff Access
                </h3>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  Enter password to access login portal
                </p>
              </div>
            </div>

            {/* Password Form */}
            <form onSubmit={handlePasswordSubmit} className="mt-5 space-y-4">
              <div>
                <label
                  htmlFor="bailiff-pass"
                  className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5"
                >
                  Password
                </label>
                <input
                  id="bailiff-pass"
                  type="password"
                  autoFocus
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value);
                    if (error) setError(false);
                  }}
                  placeholder="Enter the password"
                  className={`w-full rounded-xl border px-3.5 py-2.5 text-sm outline-none transition-all dark:bg-slate-800/80 dark:text-white ${
                    error
                      ? "border-rose-500 ring-2 ring-rose-500/20"
                      : "border-slate-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 dark:border-slate-700"
                  }`}
                />
                {error && (
                  <p className="mt-1.5 text-xs font-medium text-rose-500">
                    Incorrect password. Please try again.
                  </p>
                )}
              </div>

              {/* Action buttons */}
              <div className="flex items-center gap-2 pt-1">
                <Button
                  type="button"
                  variant="outline"
                  onClick={closeBailiffModal}
                  className="flex-1 rounded-xl h-10 border-slate-300 dark:border-slate-700 cursor-pointer"
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  disabled={submitting}
                  className="flex-1 gap-1.5 rounded-xl h-10 bg-blue-600 hover:bg-blue-700 text-white font-semibold cursor-pointer shadow-sm shadow-blue-600/20 disabled:opacity-60"
                >
                  {submitting ? (
                    <>
                      <Loader2 className="size-4 animate-spin" />
                      Checking...
                    </>
                  ) : (
                    <>
                      Proceed
                      <ArrowRight className="size-4" />
                    </>
                  )}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Footer */}
      <footer className="mt-12 text-center text-xs text-slate-400 dark:text-slate-600">
        CampusBell &copy; 2026 · All rights reserved
      </footer>
    </main>
  );
}
