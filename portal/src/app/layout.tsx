import type { Metadata } from "next";
import { Figtree, JetBrains_Mono } from "next/font/google";
import { Toaster } from "@/components/ui/sonner";
import "./globals.css";

// Figtree: clean, professional UI font (not the default template font).
const appSans = Figtree({
  variable: "--font-app-sans",
  subsets: ["latin"],
});

const appMono = JetBrains_Mono({
  variable: "--font-app-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "CampusBell Admin",
  description: "Manage CampusBell users, admins and bells.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${appSans.variable} ${appMono.variable} h-full antialiased`}
    >
      {/* Browser extensions (e.g. Grammarly) add attributes to <body>. */}
      <body className="min-h-full flex flex-col" suppressHydrationWarning>
        {children}
        <Toaster position="top-right" richColors />
      </body>
    </html>
  );
}
