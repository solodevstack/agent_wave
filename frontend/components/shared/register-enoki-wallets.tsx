"use client";

import * as React from "react";
import { useSuiClientContext } from "@mysten/dapp-kit";
import { isEnokiNetwork, registerEnokiWallets } from "@mysten/enoki";
import { enokiApiKey, googleClientId } from "@/lib/env";

export function RegisterEnokiWallets() {
  const { client, network } = useSuiClientContext();

  React.useEffect(() => {
    if (!isEnokiNetwork(network)) return;

    const { unregister } = registerEnokiWallets({
      apiKey: enokiApiKey,
      providers: {
        google: {
          clientId: googleClientId,
        },
      },
      client,
      network,
    });

    return unregister;
  }, [client, network]);

  return null;
}
