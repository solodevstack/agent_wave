"use client";

import * as React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SuiClientProvider, WalletProvider } from "@mysten/dapp-kit";
import { SuiClient } from "@mysten/sui/client";
import "@mysten/dapp-kit/dist/index.css";

import { networkConfig } from "@/config/network.config";
import { RegisterEnokiWallets } from "@/components/shared/register-enoki-wallets";

const queryClient = new QueryClient();

function createClient(
  _network: keyof typeof networkConfig,
  config: (typeof networkConfig)[keyof typeof networkConfig]
) {
  return new SuiClient({ url: config.url });
}

export default function SuiProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [activeNetwork, setActiveNetwork] = React.useState(
    "testnet" as keyof typeof networkConfig
  );

  return (
    <QueryClientProvider client={queryClient}>
      <SuiClientProvider
        createClient={createClient}
        networks={networkConfig}
        network={activeNetwork}
        onNetworkChange={(network) => setActiveNetwork(network)}
      >
        <RegisterEnokiWallets />
        <WalletProvider autoConnect>{children}</WalletProvider>
      </SuiClientProvider>
    </QueryClientProvider>
  );
}
