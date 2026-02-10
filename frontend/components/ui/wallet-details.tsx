// @ts-nocheck
"use client";

import { useCurrentAccount } from "@mysten/dapp-kit";
import { useSuiBalance } from "@/hooks/useSuiBalance";
import { useWalBalance } from "@/hooks/useWalBalance";
import { useGetWalTokens } from "@/hooks/useGetWalTokens";

export default function WalletDetails() {
  const account = useCurrentAccount();

  const { data: amountSui = "0" } = useSuiBalance();
  const { data: amountWal = "0" } = useWalBalance();
  const getWalTokensMutation = useGetWalTokens();

  const getSui = () => {
    if (!account) return;

    const faucetUrl = `https://faucet.sui.io/?address=${account.address}`;
    window.open(faucetUrl, "_blank");
  };

  const getWal = async () => {
    await getWalTokensMutation.mutateAsync();
  };

  const hasWal = parseFloat(amountWal) > 0;
  const hasLowSui = parseFloat(amountSui) < 0.5;
  const hasInsufficientSui = parseFloat(amountSui) < 0.5;
  const isGettingWal = getWalTokensMutation.isPending;

  if (!account) {
    return null;
  }

  return (
    <div className="flex flex-row gap-6 items-center justify-center w-full">
      <span className="text-sm font-medium ">Testnet Balance</span>

      {/* SUI Display */}
      <div className="flex flex-row gap-3 items-center">
        <div className={`flex flex-row gap-2 items-center ${hasLowSui ? "opacity-50" : ""}`}>
          <img
            src="/icons/sui-token-icon.png"
            alt="SUI"
            className="h-6 w-6 rounded-full"
          />
          <span className="text-sm font-medium">{amountSui}</span>
          <span className="text-sm opacity-60">SUI</span>
        </div>
        {hasLowSui && (
          <button
            className="text-xs text-primary hover:underline transition-colors"
            onClick={getSui}
          >
            Get testnet SUI
          </button>
        )}
      </div>

      {/* WAL Display */}
      {hasWal ? (
        <div className="flex flex-row gap-3 items-center">
          <div className="flex flex-row gap-2 items-center">
            <img
              src="https://walrus-logos.wal.app/Icon%20Token/Icon_token_RGB.svg"
              alt="WAL"
              className="w-6 h-6 rounded-full"
            />
            <span className="text-sm font-medium">{amountWal}</span>
            <span className="text-sm opacity-60">WAL</span>
          </div>
          <button
            className={`text-xs transition-colors ${
              isGettingWal || hasInsufficientSui
                ? "opacity-50 cursor-not-allowed"
                : "hover:underline cursor-pointer"
            }`}
            onClick={getWal}
            disabled={isGettingWal || hasInsufficientSui}
          >
            {isGettingWal
              ? "Getting..."
              : hasInsufficientSui
                ? "Need SUI"
                : "Get More"}
          </button>
        </div>
      ) : (
        <div className="flex flex-row gap-3 items-center">
          <div className="flex flex-row gap-2 items-center opacity-50">
            <img
              src="https://walrus-logos.wal.app/Icon%20Token/Icon_token_RGB.svg"
              alt="WAL"
              className="w-6 h-6 rounded-full"
            />
            <span className="text-sm font-medium">0</span>
            <span className="text-sm opacity-60">WAL</span>
          </div>
          <button
            className={`px-4 py-2 rounded-full text-xs font-medium transition-all ${
              isGettingWal || !account || hasInsufficientSui
                ? "bg-white/10 opacity-50 cursor-not-allowed border border-white/15"
                : "bg-white/5 hover:bg-white/10 cursor-pointer border border-white/20"
            }`}
            onClick={getWal}
            disabled={isGettingWal || !account || hasInsufficientSui}
          >
            {isGettingWal
              ? "Getting..."
              : hasInsufficientSui
                ? "Need SUI"
                : "Get WAL"}
          </button>
        </div>
      )}
    </div>
  );
}