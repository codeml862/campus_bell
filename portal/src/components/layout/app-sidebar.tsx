"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { signOut } from "firebase/auth";
import {
  Bell,
  BellRing,
  Building2,
  ChevronsUpDown,
  LayoutDashboard,
  LogOut,
  Settings,
  ShieldCheck,
  UserRound,
  Users,
} from "lucide-react";

import { auth } from "@/lib/firebase";
import { useAdmin } from "@/hooks/use-admin";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";

type NavItem = { title: string; href: string; icon: typeof Bell };

const groups: { label: string; items: NavItem[] }[] = [
  {
    label: "Overview",
    items: [{ title: "Dashboard", href: "/dashboard", icon: LayoutDashboard }],
  },
  {
    label: "Management",
    items: [
      { title: "Users", href: "/users", icon: Users },
      { title: "Admins", href: "/admins", icon: ShieldCheck },
      { title: "Departments", href: "/departments", icon: Building2 },
    ],
  },
  {
    label: "Activity",
    items: [{ title: "Bells", href: "/bells", icon: BellRing }],
  },
];

function initials(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() ?? "")
    .join("");
}

/** Production sidebar: brand, grouped nav, account menu. */
export function AppSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { user, profile, isAdmin } = useAdmin();
  // HODs don't manage admins.
  const visibleGroups = groups.map((g) => ({
    ...g,
    items: g.items.filter((i) => isAdmin || i.href !== "/admins"),
  }));

  // The shell only renders for a signed-in admin, so these are real values.
  const name =
    profile?.name || user?.displayName || user?.email?.split("@")[0] || "";
  const email = user?.email ?? "";
  const role =
    profile?.role === "Administrator"
      ? "Main administrator"
      : profile?.role === "HOD"
        ? `HOD · ${profile.department}`
        : (profile?.role ?? "");

  return (
    <Sidebar collapsible="icon" variant="sidebar">
      <SidebarHeader className="px-3 pt-4 group-data-[collapsible=icon]:px-2">
        <Link
          href="/dashboard"
          className="flex items-center gap-2.5 rounded-lg px-1 py-1 group-data-[collapsible=icon]:justify-center group-data-[collapsible=icon]:px-0"
        >
          <div className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-sm group-data-[collapsible=icon]:size-8 group-data-[collapsible=icon]:rounded-lg">
            <Bell className="size-[18px]" strokeWidth={2.25} />
          </div>
          <div className="min-w-0 leading-tight group-data-[collapsible=icon]:hidden">
            <p className="truncate text-[15px] font-semibold tracking-tight text-foreground">
              CampusBell
            </p>
            <p className="truncate text-xs text-muted-foreground">
              Admin portal
            </p>
          </div>
        </Link>

      </SidebarHeader>

      <SidebarContent className="px-1">
        {visibleGroups.map((g) => (
          <SidebarGroup key={g.label}>
            <SidebarGroupLabel className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground/80">
              {g.label}
            </SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu className="gap-0.5">
                {g.items.map((item) => {
                  const active = pathname.startsWith(item.href);
                  return (
                    <SidebarMenuItem key={item.href}>
                      <SidebarMenuButton
                        render={<Link href={item.href} />}
                        tooltip={item.title}
                        isActive={active}
                        className="h-9 rounded-lg font-medium data-active:bg-sidebar-accent data-active:font-semibold data-active:text-sidebar-accent-foreground"
                      >
                        <item.icon
                          className={active ? "text-primary" : undefined}
                        />
                        <span>{item.title}</span>
                      </SidebarMenuButton>
                    </SidebarMenuItem>
                  );
                })}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        ))}
      </SidebarContent>

      <SidebarFooter className="border-t border-sidebar-border p-2">
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              render={<Link href="/settings" />}
              tooltip="Settings"
              isActive={pathname.startsWith("/settings")}
              className="h-9 rounded-lg font-medium"
            >
              <Settings />
              <span>Settings</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
          <SidebarMenuItem>
            <DropdownMenu>
              <DropdownMenuTrigger
                render={
                  <SidebarMenuButton
                    size="lg"
                    className="rounded-lg data-popup-open:bg-sidebar-accent"
                  />
                }
              >
                <Avatar className="size-8 rounded-lg">
                  <AvatarFallback className="rounded-lg bg-sidebar-accent text-xs font-semibold text-primary">
                    {initials(name)}
                  </AvatarFallback>
                </Avatar>
                <div className="grid flex-1 text-left leading-tight">
                  <span className="truncate text-sm font-semibold">{name}</span>
                  <span className="truncate text-xs text-muted-foreground">
                    {email}
                  </span>
                </div>
                <ChevronsUpDown className="ml-auto size-4 text-muted-foreground" />
              </DropdownMenuTrigger>
              <DropdownMenuContent side="top" align="start" className="w-56">
                <DropdownMenuGroup>
                  <DropdownMenuLabel className="space-y-0.5">
                    <p className="truncate text-sm font-semibold text-foreground">
                      {name}
                    </p>
                    <p className="truncate text-xs font-normal text-muted-foreground">
                      {email}
                    </p>
                    <span className="mt-1 inline-flex rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
                      {role}
                    </span>
                  </DropdownMenuLabel>
                </DropdownMenuGroup>
                <DropdownMenuSeparator />
                <DropdownMenuItem onClick={() => router.push("/settings")}>
                  <UserRound className="size-4" /> My account
                </DropdownMenuItem>
                {isAdmin && (
                  <DropdownMenuItem onClick={() => router.push("/admins")}>
                    <ShieldCheck className="size-4" /> Manage admins
                  </DropdownMenuItem>
                )}
                <DropdownMenuSeparator />
                <DropdownMenuItem
                  className="text-destructive"
                  onClick={async () => {
                    if (auth) await signOut(auth);
                    router.push("/login");
                  }}
                >
                  <LogOut className="size-4" /> Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarFooter>
    </Sidebar>
  );
}
