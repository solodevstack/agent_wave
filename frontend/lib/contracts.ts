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

export function buildCreateAgenticEscrowTx(params: {
  mainAgent: string; // address
  jobTitle: string;
  jobDescription: string;
  jobCategory: string;
  duration: number; // u8
  budgetMist: bigint; // u64 (MIST)
  mainAgentPriceMist: bigint; // u64 (MIST)
}) {
  const cfg = networkConfig.testnet.variables;

  const tx = new Transaction();

  const escrowTable = tx.sharedObjectRef({
    objectId: cfg.agenticEscrowTableId,
    initialSharedVersion: cfg.agenticEscrowTableInitialSharedVersion,
    mutable: true,
  });

  const clock = tx.sharedObjectRef({
    objectId: cfg.clockId,
    initialSharedVersion: 1,
    mutable: false,
  });

  // Payment coin must cover budget. Split from gas coin.
  const [paymentCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(params.budgetMist)]);

  tx.moveCall({
    package: cfg.packageId,
    module: "agentwave_contract",
    function: "create_agentic_escrow",
    arguments: [
      escrowTable,
      tx.pure.address(params.mainAgent),
      tx.pure.string(params.jobTitle),
      tx.pure.string(params.jobDescription),
      tx.pure.string(params.jobCategory),
      tx.pure.u8(params.duration),
      tx.pure.u64(params.budgetMist),
      tx.pure.u64(params.mainAgentPriceMist),
      paymentCoin,
      clock,
    ],
  });

  return tx;
}
