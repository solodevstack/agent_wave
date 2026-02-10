"use client";

import * as React from "react";
import {
  ConnectButton,
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { toast } from "sonner";

import { buildCreateAgenticEscrowTx } from "@/lib/contracts";
import { networkConfig } from "@/config/network.config";

type AgentProfileCreatedEvent = {
  name?: string;
  owner?: string;
  timestamp?: string | number;
};

type AgentListItem = {
  owner: string;
  name: string;
  timestamp?: number;
};

function mistToSui(mist: bigint) {
  return Number(mist) / 1_000_000_000;
}

function parseMist(input: string): bigint {
  // Accept either a plain integer mist value, or a decimal SUI amount.
  const trimmed = input.trim();
  if (!trimmed) return 0n;

  if (/^\d+$/.test(trimmed)) {
    // treat as mist
    return BigInt(trimmed);
  }

  // treat as SUI decimal
  const [whole, frac = ""] = trimmed.split(".");
  const fracPadded = (frac + "000000000").slice(0, 9);
  const w = whole ? BigInt(whole) : 0n;
  const f = BigInt(fracPadded || "0");
  return w * 1_000_000_000n + f;
}

export default function HomePage() {
  const cfg = networkConfig.testnet.variables;
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const { mutateAsync: signAndExecute, isPending } =
    useSignAndExecuteTransaction();

  const [agents, setAgents] = React.useState<AgentListItem[]>([]);
  const [loadingAgents, setLoadingAgents] = React.useState(false);
  const [agentsError, setAgentsError] = React.useState<string | null>(null);

  const [selectedAgent, setSelectedAgent] = React.useState<AgentListItem | null>(
    null
  );

  // Escrow form
  const [jobTitle, setJobTitle] = React.useState("");
  const [jobDescription, setJobDescription] = React.useState("");
  const [jobCategory, setJobCategory] = React.useState("");
  const [duration, setDuration] = React.useState(7); // u8
  const [budgetInput, setBudgetInput] = React.useState("0.1"); // SUI by default
  const [mainAgentPriceInput, setMainAgentPriceInput] = React.useState("0.05");

  const [lastDigest, setLastDigest] = React.useState<string | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  const profileCreatedEventType = `${cfg.packageId}::agentwave_profile::AgentProfileCreated`;

  const refreshAgents = React.useCallback(async () => {
    setLoadingAgents(true);
    setAgentsError(null);

    try {
      const res = await suiClient.queryEvents({
        query: { MoveEventType: profileCreatedEventType },
        limit: 50,
        order: "descending",
      });

      const items: AgentListItem[] = [];
      const seen = new Set<string>();

      for (const ev of res.data) {
        // Most fullnodes return parsedJson for Move events.
        const pj = (ev as unknown as { parsedJson?: AgentProfileCreatedEvent })
          .parsedJson;
        const owner = pj?.owner;
        const name = pj?.name;
        const tsRaw = pj?.timestamp;

        if (!owner) continue;
        if (seen.has(owner)) continue;
        seen.add(owner);

        items.push({
          owner,
          name: name || owner.slice(0, 10) + "…",
          timestamp:
            typeof tsRaw === "string" ? Number(tsRaw) : typeof tsRaw === "number" ? tsRaw :
            undefined,
        });
      }

      setAgents(items);
    } catch (e) {
      setAgentsError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoadingAgents(false);
    }
  }, [profileCreatedEventType, suiClient]);

  React.useEffect(() => {
    void refreshAgents();
  }, [refreshAgents]);

  async function onCreateEscrow() {
    setError(null);
    setLastDigest(null);

    if (!account?.address) {
      setError("Connect a wallet first (zkLogin via Enoki wallet).");
      return;
    }

    if (!selectedAgent) {
      setError("Select an agent first.");
      return;
    }

    const budgetMist = parseMist(budgetInput);
    const mainAgentPriceMist = parseMist(mainAgentPriceInput);

    if (budgetMist <= 0n) {
      setError("Budget must be > 0.");
      return;
    }

    if (mainAgentPriceMist <= 0n) {
      setError("Main agent price must be > 0.");
      return;
    }

    const tx = buildCreateAgenticEscrowTx({
      mainAgent: selectedAgent.owner,
      jobTitle: jobTitle || "Untitled job",
      jobDescription: jobDescription || "",
      jobCategory: jobCategory || "general",
      duration,
      budgetMist,
      mainAgentPriceMist,
    });

    try {
      const res = await signAndExecute({
        transaction: tx,
      });
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const digest = (res as any)?.digest || (res as any)?.effects?.transactionDigest;
      setLastDigest(digest ?? "(no digest returned)");
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    }
  }

  const shortAddress = account?.address
    ? `${account.address.slice(0, 6)}…${account.address.slice(-4)}`
    : null;

  async function copyAddress() {
    if (!account?.address) return;

    const text = account.address;

    try {
      if (navigator?.clipboard?.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        // Fallback for older browsers / restricted contexts
        const el = document.createElement("textarea");
        el.value = text;
        el.setAttribute("readonly", "");
        el.style.position = "fixed";
        el.style.left = "-9999px";
        document.body.appendChild(el);
        el.select();
        document.execCommand("copy");
        document.body.removeChild(el);
      }
      toast.success("Address copied");
    } catch (e) {
      toast.error(
        `Copy failed${e instanceof Error && e.message ? `: ${e.message}` : ""}`
      );
    }
  }

  return (
    <div className="container">
      <div className="row" style={{ justifyContent: "space-between" }}>
        <div>
          <h1 style={{ margin: 0 }}>AgentWave</h1>
          <small>
            Deployed on Sui testnet • package <code>{cfg.packageId}</code>
          </small>
        </div>
        <ConnectButton />
      </div>

      <div style={{ height: 18 }} />

      <div className="card">
        <div style={{ fontWeight: 700, marginBottom: 6 }}>Wallet</div>
        {account?.address ? (
          <div className="row" style={{ justifyContent: "space-between" }}>
            <div style={{ minWidth: 0 }}>
              <small style={{ display: "block" }}>Connected address</small>
              <div
                style={{
                  fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
                  wordBreak: "break-all",
                }}
                aria-label={`Wallet address ${account.address}`}
                title={account.address}
              >
                <button
                  onClick={copyAddress}
                  aria-label="Copy wallet address"
                  title="Copy address"
                  type="button"
                  style={{
                    all: "unset",
                    cursor: "pointer",
                    display: "inline",
                  }}
                >
                  {shortAddress}
                </button>
              </div>
              <small style={{ opacity: 0.7 }}>Click the address or Copy</small>
            </div>
            <button
              className="secondary"
              onClick={copyAddress}
              aria-label="Copy wallet address"
              title="Copy address"
              type="button"
            >
              Copy
            </button>
          </div>
        ) : (
          <small style={{ opacity: 0.85 }}>Not connected</small>
        )}
      </div>

      <div style={{ height: 18 }} />

      <div className="card">
        <div style={{ fontWeight: 700, marginBottom: 6 }}>Marketplace</div>
        <small style={{ opacity: 0.85 }}>
          Pick an agent profile, then create an escrow by calling
          <code> agentwave_contract::create_agentic_escrow</code>.
        </small>

        <div style={{ height: 12 }} />

        <div className="row">
          <button className="secondary" onClick={() => void refreshAgents()}>
            {loadingAgents ? "Refreshing…" : "Refresh agents"}
          </button>
          <small style={{ opacity: 0.75 }}>
            Loaded {agents.length} agents (from on-chain AgentProfileCreated
            events)
          </small>
        </div>

        {agentsError ? (
          <div style={{ marginTop: 10, color: "#fca5a5" }}>
            <b>Error loading agents:</b> {agentsError}
          </div>
        ) : null}
      </div>

      <div style={{ height: 18 }} />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))",
          gap: 12,
        }}
      >
        {agents.map((a) => {
          const selected = selectedAgent?.owner === a.owner;
          return (
            <div key={a.owner} className="card">
              <div style={{ display: "flex", justifyContent: "space-between" }}>
                <div>
                  <div style={{ fontWeight: 800 }}>{a.name}</div>
                  <small>
                    <code>{a.owner}</code>
                  </small>
                </div>
              </div>

              <div style={{ height: 10 }} />

              <button
                onClick={() => {
                  setSelectedAgent(a);
                  setError(null);
                  setLastDigest(null);
                }}
                className={selected ? undefined : "secondary"}
              >
                {selected ? "Selected" : "Select agent"}
              </button>
            </div>
          );
        })}
      </div>

      <div style={{ height: 18 }} />

      <div className="card">
        <h2 style={{ marginTop: 0 }}>Create agentic escrow</h2>

        <small style={{ opacity: 0.85 }}>
          Selected agent: {selectedAgent ? (
            <>
              <b>{selectedAgent.name}</b> (<code>{selectedAgent.owner}</code>)
            </>
          ) : (
            <b>none</b>
          )}
        </small>

        <div style={{ height: 12 }} />

        <div style={{ display: "grid", gap: 10 }}>
          <div>
            <label>Job title</label>
            <input value={jobTitle} onChange={(e) => setJobTitle(e.target.value)} />
          </div>

          <div>
            <label>Job description</label>
            <textarea
              rows={4}
              value={jobDescription}
              onChange={(e) => setJobDescription(e.target.value)}
            />
          </div>

          <div>
            <label>Job category</label>
            <input
              value={jobCategory}
              onChange={(e) => setJobCategory(e.target.value)}
              placeholder="e.g. dev, design, writing"
            />
          </div>

          <div className="row">
            <div style={{ flex: 1, minWidth: 220 }}>
              <label>Duration (u8)</label>
              <input
                value={String(duration)}
                onChange={(e) => setDuration(Number(e.target.value || 0))}
                placeholder="7"
              />
            </div>
            <div style={{ flex: 1, minWidth: 220 }}>
              <label>Budget (SUI or MIST)</label>
              <input
                value={budgetInput}
                onChange={(e) => setBudgetInput(e.target.value)}
                placeholder="0.1"
              />
              <small style={{ opacity: 0.75 }}>
                Parsed: {mistToSui(parseMist(budgetInput)).toFixed(9)} SUI
              </small>
            </div>
          </div>

          <div>
            <label>Main agent price (SUI or MIST)</label>
            <input
              value={mainAgentPriceInput}
              onChange={(e) => setMainAgentPriceInput(e.target.value)}
              placeholder="0.05"
            />
            <small style={{ opacity: 0.75 }}>
              Parsed: {mistToSui(parseMist(mainAgentPriceInput)).toFixed(9)} SUI
            </small>
          </div>

          <div className="row">
            <button onClick={onCreateEscrow} disabled={isPending}>
              {isPending ? "Submitting…" : "Create escrow"}
            </button>
            <button
              className="secondary"
              onClick={() => {
                setError(null);
                setLastDigest(null);
              }}
              type="button"
            >
              Clear status
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
        Next steps: add Walrus upload for job files / proofs.
        <br />
        Env required: <code>NEXT_PUBLIC_ENOKI_API_KEY</code>,
        <code>NEXT_PUBLIC_GOOGLE_CLIENT_ID</code>, <code>NEXT_PUBLIC_SITE_URL</code>.
      </small>
    </div>
  );
}
