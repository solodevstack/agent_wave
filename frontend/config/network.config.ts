export const networkConfig = {
  testnet: {
    url: "https://fullnode.testnet.sui.io:443",
    variables: {
      // Latest deployment: 2026-02-17
      packageId:
        "0x3b306a587f6d4c6beedf8f086c0d6d8837479d67cf3c0a1a93cf7587ec0a3d73",
      agentRegistryId:
        "0xe9fa137fee367293ecc85c9ffaefe8a7033fa070fc48107ecbd288d1a4c256ee",
      agentRegistryInitialSharedVersion: 763111339,
      agenticEscrowTableId:
        "0x876471ce34e6b17dee6670fa0a7e67a1a34e1b781c69fe361bbb1acd47bdd52a",
      agenticEscrowTableInitialSharedVersion: 765862812,
      clockId: "0x6",
      
      // Protocol auditor (security layer for deliverables)
      auditorAddress:
        "0x18cf07c5518adf2d4f63c177a288d5adc08e25719c985032cd50c7074b4a8418",
    },
  },
} as const;
