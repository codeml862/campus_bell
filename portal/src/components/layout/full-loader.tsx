import { Bell } from "lucide-react";

/** One full-screen loader shared by login and the portal, so going from
 * sign-in to the dashboard looks like a single, steady loading screen. */
export function FullLoader() {
  return (
    <div className="flex min-h-svh flex-col items-center justify-center gap-4 bg-background">
      <div className="flex size-12 animate-pulse items-center justify-center rounded-2xl bg-primary text-primary-foreground">
        <Bell className="size-6" strokeWidth={2.25} />
      </div>
      <div className="h-1 w-24 overflow-hidden rounded-full bg-primary/15">
        <div className="h-full w-1/2 animate-[loader_1s_ease-in-out_infinite] rounded-full bg-primary" />
      </div>
    </div>
  );
}
