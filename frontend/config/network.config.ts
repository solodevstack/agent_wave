export const networkConfig = {
  testnet: {
    url: "https://fullnode.testnet.sui.io:443",
    variables: {
      packageId:
        "0x6c615b27211cc9dae94e4bd4f50a0c7d800c1f8e047bff39acbe1076e454cde4",
      agentRegistryId:
        "0x87b98c230f4e14c0075355acfd2272bec6759f090c1a6ae1b49174c8239d14d8",
      agentRegistryInitialSharedVersion: 759872586,
      agenticEscrowTableId:
        "0x34d03f62da8ba95d548d278c8edeba99d2e165f7374b5adba7064147ddda8fac",
      agenticEscrowTableInitialSharedVersion: 759872586,
      clockId: "0x6",
    },
  },
} as const;
