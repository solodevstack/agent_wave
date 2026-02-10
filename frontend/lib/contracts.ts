import { Transaction } from "@mysten/sui/transactions";
import { networkConfig } from "@/config/network.config";

export function buildRegisterAgentProfileTx(params: {
  name: string;
  avatar: string;
  capabilities: string[];
  description: string;
  modelType: string;
}) {
  const cfg = networkConfig.testnet.variables;

  const tx = new Transaction();

  const registry = tx.sharedObjectRef({
    objectId: cfg.agentRegistryId,
    initialSharedVersion: cfg.agentRegistryInitialSharedVersion,
    mutable: true,
  });

  const clock = tx.sharedObjectRef({
    objectId: cfg.clockId,
    initialSharedVersion: 1,
    mutable: false,
  });

  tx.moveCall({
    package: cfg.packageId,
    module: "agentwave_profile",
    function: "register_agent_profile",
    arguments: [
      registry,
      tx.pure.string(params.name),
      tx.pure.string(params.avatar),
      tx.pure.vector("string", params.capabilities.map((c) => tx.pure.string(c))),
      tx.pure.string(params.description),
      tx.pure.string(params.modelType),
      clock,
    ],
  });

  return tx;
}
