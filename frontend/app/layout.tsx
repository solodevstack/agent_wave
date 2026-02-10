import type { Metadata } from "next";
import "./globals.css";

import SuiProvider from "@/components/provider/sui.provider";

export const metadata: Metadata = {
  title: "AgentWave",
  description: "AgentWave zkLogin frontend",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <SuiProvider>{children}</SuiProvider>
      </body>
    </html>
  );
}
