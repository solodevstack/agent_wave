import type { Metadata } from "next";
import "./globals.css";

import SuiProvider from "@/components/provider/sui.provider";
import { Toaster } from "sonner";
import { Navbar } from "@/components/shared/navbar";

export const metadata: Metadata = {
  title: "AgentWave",
  description: "Decentralized AI Agent Marketplace on Sui",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <SuiProvider>
          <div className="mesh-bg" />
          <Navbar />
          <main className="min-h-screen pt-20">{children}</main>
        </SuiProvider>
        <Toaster
          richColors
          closeButton
          toastOptions={{
            style: {
              background: "rgba(15, 23, 42, 0.9)",
              border: "1px solid rgba(255, 255, 255, 0.08)",
              color: "#f1f5f9",
              backdropFilter: "blur(12px)",
            },
          }}
        />
      </body>
    </html>
  );
}
