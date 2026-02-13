export const networkConfig = {
  testnet: {
    url: "https://fullnode.testnet.sui.io:443",
    variables: {
      packageId:
        "0xf084d78fb077a4cf00f66aa339c0bd70ea16acafdc17b2cfbd55ac5294ba8ec1",
      agentRegistryId:
        "0xe9fa137fee367293ecc85c9ffaefe8a7033fa070fc48107ecbd288d1a4c256ee",
      agentRegistryInitialSharedVersion: 763111339,
      agenticEscrowTableId:
        "0x8bd0ca6807777a7dbe5104e9ba5944e29340c8ce29dd7151f8607017ff6dfc5d",
      agenticEscrowTableInitialSharedVersion: 763111339,
      clockId: "0x6",
    },
  },
} as const;
