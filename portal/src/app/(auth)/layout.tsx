import { Bell, BellRing, ShieldCheck, Users } from "lucide-react";

/**
 * Sign-in / sign-up shell.
 * Desktop/laptop: deep-blue brand panel on the left, form on the right.
 * Tablet/mobile: form only, full width.
 */
export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="grid min-h-svh lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      {/* Brand panel */}
      <aside className="relative hidden overflow-hidden bg-primary text-primary-foreground lg:flex lg:flex-col lg:justify-between lg:p-10 xl:p-14">
        <div
          aria-hidden
          className="pointer-events-none absolute -right-32 -top-32 size-[28rem] rounded-full bg-white/[0.06]"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -bottom-40 -left-24 size-[26rem] rounded-full bg-white/[0.05]"
        />

        <div className="relative flex items-center gap-2.5">
          <div className="flex size-10 items-center justify-center rounded-xl bg-white text-primary">
            <Bell className="size-5" strokeWidth={2.25} />
          </div>
          <span className="text-lg font-semibold tracking-tight">
            CampusBell
          </span>
        </div>

        <div className="relative max-w-md space-y-8">
          <div className="space-y-3">
            <h2 className="text-3xl font-semibold leading-tight tracking-tight xl:text-4xl">
              Run your campus bells from one place.
            </h2>
            <p className="text-base text-white/75">
              Manage people, admins and departments. Every change shows up in
              the CampusBell app instantly.
            </p>
          </div>
          <ul className="space-y-4 text-sm">
            {[
              { icon: Users, text: "Approve and organise staff and students" },
              { icon: ShieldCheck, text: "Choose who gets admin access" },
              { icon: BellRing, text: "See every bell, answer and reason" },
            ].map(({ icon: Icon, text }) => (
              <li key={text} className="flex items-center gap-3">
                <span className="flex size-8 items-center justify-center rounded-lg bg-white/10">
                  <Icon className="size-4" />
                </span>
                <span className="text-white/90">{text}</span>
              </li>
            ))}
          </ul>
        </div>

        <p className="relative text-xs text-white/60">
          CampusBell · Admin portal
        </p>
      </aside>

      {/* Form side */}
      <main className="flex items-center justify-center px-5 py-10 sm:px-8">
        <div className="w-full max-w-sm">{children}</div>
      </main>
    </div>
  );
}
