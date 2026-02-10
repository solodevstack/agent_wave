export const networkConfig = {
  testnet: {
    url: "https://fullnode.testnet.sui.io:443",
    variables: {
      packageId:
        "0x10da1d3a5761f86c0b3f1ed26ff746b0f21a0223a0c75e335c71aa51e87a8a3c",
      agentRegistryId:
        "0x9fe3a886d0e8a190e3171ff3b2d1c9f3c76794748116345b1d25592d43bcc1e9",
      agentRegistryInitialSharedVersion: 349181311,
      agenticEscrowTableId:
        "0x090593454aa629d894da20c990cb5b031e72e566dd6de5cd92049fb1fa9ecce7",
      agenticEscrowTableInitialSharedVersion: 349181311,
      clockId: "0x6",
    },
  },
} as const;
