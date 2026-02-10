"use client";

import * as React from "react";
import Link from "next/link";
import { ConnectButton, useCurrentAccount, useSuiClient } from "@mysten/dapp-kit";
import { toast } from "sonner";
import { Copy, Waves, Wallet } from "lucide-react";

function formatSui(mist: bigint): string {
  const sui = Number(mist) / 1_000_000_000;
  if (sui >= 1000) return sui.toFixed(0);
  if (sui >= 1) return sui.toFixed(2);
  return sui.toFixed(4);
}

export function Navbar() {
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const [balance, setBalance] = React.useState<bigint | null>(null);

  const shortAddress = account?.address
    ? `${account.address.slice(0, 6)}...${account.address.slice(-4)}`
    : null;

  React.useEffect(() => {
    if (!account?.address) {
      setBalance(null);
      return;
    }

    let cancelled = false;

    async function fetchBalance() {
      try {
        const res = await suiClient.getBalance({ owner: account!.address });
        if (!cancelled) setBalance(BigInt(res.totalBalance));
      } catch {
        if (!cancelled) setBalance(null);
      }
    }

    void fetchBalance();
    const interval = setInterval(fetchBalance, 10_000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, [account?.address, suiClient]);

  async function copyAddress() {
    if (!account?.address) return;
    try {
      await navigator.clipboard.writeText(account.address);
      toast.success("Address copied");
    } catch {
      toast.error("Failed to copy address");
    }
  }

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 border-b border-(--border-subtle) bg-(--bg-primary)/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link href="/" className="flex items-center gap-3 group">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 shadow-lg shadow-indigo-500/20 transition-shadow group-hover:shadow-indigo-500/40">
            <Waves className="h-5 w-5 text-white" />
          </div>
          <span className="text-lg font-bold tracking-tight">
            Agent<span className="gradient-text">Wave</span>
          </span>
        </Link>

        <div className="flex items-center gap-3">
          {account?.address && balance !== null && (
            <div className="flex items-center gap-2 rounded-xl border border-(--border-subtle) bg-(--bg-card) px-3 py-2 text-sm">
              <Wallet className="h-3.5 w-3.5 text-(--accent-light)" />
              <span className="font-semibold">{formatSui(balance)}</span>
              <span className="text-(--text-muted)">SUI</span>
            </div>
          )}
          {shortAddress && (
            <button
              onClick={copyAddress}
              className="flex items-center gap-2 rounded-xl border border-(--border-subtle) bg-(--bg-card) px-3 py-2 text-sm font-mono text-(--text-secondary) transition-all hover:border-(--border-hover) hover:text-(--text-primary)"
              title={account?.address}
            >
              {shortAddress}
              <Copy className="h-3.5 w-3.5" />
            </button>
          )}
          <ConnectButton />
        </div>
      </div>
    </nav>
  );
}
