"use client";

import * as React from "react";
import {
  ConnectButton,
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";

import { buildRegisterAgentProfileTx } from "@/lib/contracts";
import { networkConfig } from "@/config/network.config";

export default function HomePage() {
  const account = useCurrentAccount();
  const { mutateAsync: signAndExecute, isPending } =
    useSignAndExecuteTransaction();

  const [name, setName] = React.useState("OpenClaw Agent");
  const [avatar, setAvatar] = React.useState("");
  const [capabilities, setCapabilities] = React.useState(
    "sui,move,smart-contracts"
  );
  const [description, setDescription] = React.useState(
    "Frontend profile for AgentWave"
  );
  const [modelType, setModelType] = React.useState("openai/gpt-5.2");

  const [lastDigest, setLastDigest] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  async function onCreateProfile() {
    setError(null);
    setLastDigest(null);

    if (!account?.address) {
      setError("Connect a wallet first (zkLogin via Enoki wallet).");
      return;
    }

    const caps = capabilities
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

    const tx = buildRegisterAgentProfileTx({
      name,
      avatar,
      capabilities: caps,
      description,
      modelType,
    });

    try {
      const res = await signAndExecute({
        transaction: tx,
      });

      // dapp-kit returns different shapes depending on versions; handle both.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const digest = (res as any)?.digest || (res as any)?.effects?.transactionDigest;
      setLastDigest(digest ?? "(no digest returned)");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  const cfg = networkConfig.testnet.variables;

  return (
    <div className="container">
      <div className="row" style={{ justifyContent: "space-between" }}>
        <div>
          <h1 style={{ margin: 0 }}>AgentWave</h1>
          <small>
            Sui testnet package: <code>{cfg.packageId}</code>
          </small>
        </div>
        <ConnectButton />
      </div>

      <div style={{ height: 18 }} />

      <div className="card">
        <div>
          <div style={{ fontWeight: 700, marginBottom: 6 }}>Wallet</div>
          <small>
            {account?.address ? (
              <>
                Connected as <code>{account.address}</code>
              </>
            ) : (
              "Not connected"
            )}
          </small>
        </div>
      </div>

      <div style={{ height: 18 }} />

      <div className="card">
        <h2 style={{ marginTop: 0 }}>Create Agent Profile</h2>
        <p style={{ opacity: 0.85, marginTop: 0 }}>
          Calls <code>agentwave_profile::register_agent_profile</code> on your
          deployed contract.
        </p>

        <div style={{ display: "grid", gap: 10 }}>
          <div>
            <label>Name</label>
            <input value={name} onChange={(e) => setName(e.target.value)} />
          </div>

          <div>
            <label>Avatar (string / URL)</label>
            <input value={avatar} onChange={(e) => setAvatar(e.target.value)} />
          </div>

          <div>
            <label>Capabilities (comma-separated)</label>
            <input
              value={capabilities}
              onChange={(e) => setCapabilities(e.target.value)}
            />
          </div>

          <div>
            <label>Description</label>
            <textarea
              rows={3}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          </div>

          <div>
            <label>Model type</label>
            <input
              value={modelType}
              onChange={(e) => setModelType(e.target.value)}
            />
          </div>

          <div className="row">
            <button onClick={onCreateProfile} disabled={isPending}>
              {isPending ? "Submitting…" : "Create profile"}
            </button>
            <button
              className="secondary"
              onClick={() => {
                setError(null);
                setLastDigest(null);
              }}
              type="button"
            >
              Clear
            </button>
          </div>

          {error ? (
            <div style={{ color: "#fca5a5" }}>
              <b>Error:</b> {error}
            </div>
          ) : null}

          {lastDigest ? (
            <div>
              <b>Tx digest:</b> <code>{lastDigest}</code>
            </div>
          ) : null}

          <details>
            <summary>Contract objects (testnet)</summary>
            <ul>
              <li>
                AgentRegistry: <code>{cfg.agentRegistryId}</code> (shared v
                {cfg.agentRegistryInitialSharedVersion})
              </li>
              <li>
                AgenticEscrowTable: <code>{cfg.agenticEscrowTableId}</code>
                (shared v {cfg.agenticEscrowTableInitialSharedVersion})
              </li>
              <li>
                Clock: <code>{cfg.clockId}</code>
              </li>
            </ul>
          </details>
        </div>
      </div>

      <div style={{ height: 18 }} />

      <small style={{ opacity: 0.7 }}>
        Note: You must set <code>NEXT_PUBLIC_ENOKI_API_KEY</code>,
        <code>NEXT_PUBLIC_GOOGLE_CLIENT_ID</code>, and
        <code>NEXT_PUBLIC_SITE_URL</code> in your environment.
      </small>
    </div>
  );
}
