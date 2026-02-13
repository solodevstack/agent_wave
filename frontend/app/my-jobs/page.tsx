"use client";

import * as React from "react";
import {
  useCurrentAccount,
  useSuiClient,
} from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { networkConfig } from "@/config/network.config";
import {
  Briefcase,
  Download,
  Clock,
  Coins,
  RefreshCw,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  Loader2,
  ExternalLink,
  FileText,
  User,
  Wallet,
} from "lucide-react";
import { toast } from "sonner";

const WALRUS_AGGREGATOR = "https://aggregator.walrus-testnet.walrus.space";

type EscrowInfo = {
  escrowId: string;
  jobTitle: string;
  client: string;
  custodian: string;
  jobDescription: string;
  jobCategory: string;
  duration: number;
  budget: number;
  currentBalance: number;
  status: number;
  mainAgent: string;
  mainAgentPrice: number;
  mainAgentPaid: boolean;
  totalHiredAgents: number;
  blobId: string | null;
  createdAt: number;
};

const STATUS_LABELS: Record<number, { label: string; color: string }> = {
  0: { label: "Pending", color: "text-amber-400" },
  1: { label: "Accepted", color: "text-blue-400" },
  2: { label: "In Progress", color: "text-indigo-400" },
  3: { label: "Completed", color: "text-emerald-400" },
  4: { label: "Disputed", color: "text-red-400" },
  5: { label: "Refunded (Client)", color: "text-orange-400" },
  6: { label: "Refunded (Agent)", color: "text-orange-400" },
  7: { label: "Released", color: "text-emerald-300" },
  8: { label: "Cancelled", color: "text-gray-400" },
};

function StatusIcon({ status }: { status: number }) {
  if (status === 3 || status === 7) return <CheckCircle2 className="h-4 w-4 text-emerald-400" />;
  if (status === 4) return <AlertTriangle className="h-4 w-4 text-red-400" />;
  if (status === 8 || status === 5 || status === 6) return <XCircle className="h-4 w-4 text-gray-400" />;
  if (status === 2) return <Loader2 className="h-4 w-4 animate-spin text-indigo-400" />;
  return <Clock className="h-4 w-4 text-amber-400" />;
}

function mistToSui(mist: number): string {
  const sui = mist / 1_000_000_000;
  if (sui >= 1) return sui.toFixed(2);
  return sui.toFixed(4);
}

function formatDate(ms: number): string {
  if (!ms) return "";
  return new Date(ms).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

// BCS schema matching Move struct AgenticEscrowInfo
const AgenticEscrowInfoBcs = bcs.struct("AgenticEscrowInfo", {
  escrow_id: bcs.Address,
  job_title: bcs.String,
  client: bcs.Address,
  custodian: bcs.Address,
  job_description: bcs.String,
  job_category: bcs.String,
  duration: bcs.u8(),
  budget: bcs.u64(),
  current_balance: bcs.u64(),
  status: bcs.u8(),
  main_agent: bcs.Address,
  main_agent_price: bcs.u64(),
  main_agent_paid: bcs.Bool,
  total_hired_agents: bcs.u64(),
  blob_id: bcs.option(bcs.String),
  created_at: bcs.u64(),
});

function decodeBcsEscrows(data: Uint8Array): EscrowInfo[] {
  try {
    const parsed = bcs.vector(AgenticEscrowInfoBcs).parse(data);
    return parsed.map((info) => ({
      escrowId: info.escrow_id,
      jobTitle: info.job_title,
      client: info.client,
      custodian: info.custodian,
      jobDescription: info.job_description,
      jobCategory: info.job_category,
      duration: info.duration,
      budget: Number(info.budget),
      currentBalance: Number(info.current_balance),
      status: info.status,
      mainAgent: info.main_agent,
      mainAgentPrice: Number(info.main_agent_price),
      mainAgentPaid: info.main_agent_paid,
      totalHiredAgents: Number(info.total_hired_agents),
      blobId: info.blob_id ?? null,
      createdAt: Number(info.created_at),
    }));
  } catch (e) {
    console.error("BCS escrow decode error:", e);
    return [];
  }
}

async function downloadBlob(blobId: string) {
  const url = `${WALRUS_AGGREGATOR}/v1/blobs/${blobId}`;
  try {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const blob = await res.blob();
    const contentType = res.headers.get("content-type") || "application/octet-stream";

    // Determine extension from content type
    const extMap: Record<string, string> = {
      "image/png": "png", "image/jpeg": "jpg", "image/gif": "gif",
      "image/webp": "webp", "application/pdf": "pdf", "text/plain": "txt",
      "application/json": "json", "application/zip": "zip",
    };
    const ext = extMap[contentType] || "bin";
    const filename = `agentwave-${blobId.slice(0, 8)}.${ext}`;

    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(a.href);
    toast.success("Download started");
  } catch (e) {
    toast.error(`Download failed: ${e instanceof Error ? e.message : String(e)}`);
  }
}

export default function MyJobsPage() {
  const cfg = networkConfig.testnet.variables;
  const account = useCurrentAccount();
  const suiClient = useSuiClient();

  const [escrows, setEscrows] = React.useState<EscrowInfo[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [downloading, setDownloading] = React.useState<string | null>(null);

  const fetchEscrows = React.useCallback(async () => {
    if (!account?.address) {
      setEscrows([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    try {
      const tx = new Transaction();
      const escrowTable = tx.sharedObjectRef({
        objectId: cfg.agenticEscrowTableId,
        initialSharedVersion: cfg.agenticEscrowTableInitialSharedVersion,
        mutable: false,
      });
      tx.moveCall({
        package: cfg.packageId,
        module: "agentwave_contract",
        function: "get_escrows_as_client",
        arguments: [escrowTable, tx.pure.address(account.address)],
      });

      const result = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: account.address,
      });

      if (result.results?.[0]?.returnValues?.[0]) {
        const raw = result.results[0].returnValues[0];
        if (raw && Array.isArray(raw) && raw[0]) {
          const bytes = new Uint8Array(raw[0] as number[]);
          const decoded = decodeBcsEscrows(bytes);
          setEscrows(decoded);
          setLoading(false);
          return;
        }
      }

      setEscrows([]);
    } catch (e) {
      console.error("Failed to fetch escrows:", e);
      setEscrows([]);
    } finally {
      setLoading(false);
    }
  }, [account?.address, cfg, suiClient]);

  React.useEffect(() => {
    void fetchEscrows();
  }, [fetchEscrows]);

  async function handleDownload(blobId: string) {
    setDownloading(blobId);
    await downloadBlob(blobId);
    setDownloading(null);
  }

  if (!account?.address) {
    return (
      <div className="mx-auto max-w-4xl px-6 py-20 text-center">
        <div className="glass-card mx-auto max-w-md p-10">
          <Wallet className="mx-auto mb-4 h-12 w-12 text-(--text-muted)" />
          <h2 className="mb-2 text-xl font-bold">Connect Your Wallet</h2>
          <p className="text-sm text-(--text-muted)">
            Connect your wallet to view your jobs and download deliverables.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-6 pb-20">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">My Jobs</h1>
          <p className="mt-1 text-sm text-(--text-muted)">
            Jobs you&apos;ve created as a client
          </p>
        </div>
        <button
          onClick={() => void fetchEscrows()}
          disabled={loading}
          className="glow-btn flex items-center gap-2"
        >
          <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          Refresh
        </button>
      </div>

      {/* Loading */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="glass-card p-6">
              <div className="mb-4 flex items-center gap-4">
                <div className="shimmer h-10 w-10 rounded-xl" />
                <div className="flex-1 space-y-2">
                  <div className="shimmer h-5 w-1/2 rounded-lg" />
                  <div className="shimmer h-3 w-1/3 rounded-lg" />
                </div>
              </div>
              <div className="shimmer h-16 w-full rounded-xl" />
            </div>
          ))}
        </div>
      ) : escrows.length === 0 ? (
        <div className="glass-card flex flex-col items-center justify-center py-20 text-center">
          <Briefcase className="mb-4 h-12 w-12 text-(--text-muted)" />
          <h3 className="mb-2 text-lg font-semibold">No jobs yet</h3>
          <p className="mb-4 text-sm text-(--text-muted)">
            You haven&apos;t created any jobs. Browse agents and create your first escrow.
          </p>
          <a href="/" className="glow-btn">Browse Agents</a>
        </div>
      ) : (
        <div className="space-y-4">
          {escrows.map((esc) => {
            const st = STATUS_LABELS[esc.status] || { label: `Status ${esc.status}`, color: "text-(--text-muted)" };
            const isDone = esc.status === 3 || esc.status === 7;
            const hasBlobId = esc.blobId !== null;
            const isDownloading = downloading === esc.blobId;

            return (
              <div key={esc.escrowId} className="glass-card p-6">
                {/* Top row: title + status */}
                <div className="mb-4 flex items-start justify-between gap-4">
                  <div className="min-w-0 flex-1">
                    <div className="mb-1 flex items-center gap-3">
                      <h3 className="truncate text-lg font-semibold">{esc.jobTitle}</h3>
                      <div className={`flex items-center gap-1.5 text-sm font-medium ${st.color}`}>
                        <StatusIcon status={esc.status} />
                        {st.label}
                      </div>
                    </div>
                    {esc.jobCategory && (
                      <span className="badge">{esc.jobCategory}</span>
                    )}
                  </div>
                  <a
                    href={`https://testnet.suivision.xyz/object/${esc.escrowId}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-1 text-xs text-(--text-muted) hover:text-(--text-secondary)"
                  >
                    Explorer <ExternalLink className="h-3 w-3" />
                  </a>
                </div>

                {/* Description */}
                {esc.jobDescription && (
                  <p className="mb-4 line-clamp-2 text-sm text-(--text-secondary)">
                    {esc.jobDescription}
                  </p>
                )}

                {/* Stats grid */}
                <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                  <div className="rounded-xl bg-(--bg-card) p-3">
                    <div className="flex items-center gap-1.5 text-xs text-(--text-muted)">
                      <Coins className="h-3 w-3" /> Budget
                    </div>
                    <div className="mt-1 font-semibold">{mistToSui(esc.budget)} SUI</div>
                  </div>
                  <div className="rounded-xl bg-(--bg-card) p-3">
                    <div className="flex items-center gap-1.5 text-xs text-(--text-muted)">
                      <Coins className="h-3 w-3" /> Balance
                    </div>
                    <div className="mt-1 font-semibold">{mistToSui(esc.currentBalance)} SUI</div>
                  </div>
                  <div className="rounded-xl bg-(--bg-card) p-3">
                    <div className="flex items-center gap-1.5 text-xs text-(--text-muted)">
                      <User className="h-3 w-3" /> Agent Price
                    </div>
                    <div className="mt-1 font-semibold">{mistToSui(esc.mainAgentPrice)} SUI</div>
                  </div>
                  <div className="rounded-xl bg-(--bg-card) p-3">
                    <div className="flex items-center gap-1.5 text-xs text-(--text-muted)">
                      <Clock className="h-3 w-3" /> Duration
                    </div>
                    <div className="mt-1 font-semibold">{esc.duration} days</div>
                  </div>
                </div>

                {/* Agent + date row */}
                <div className="mb-4 flex flex-wrap items-center gap-4 text-xs text-(--text-muted)">
                  <span className="flex items-center gap-1.5">
                    <User className="h-3 w-3" />
                    Agent: <span className="font-mono">{esc.mainAgent.slice(0, 8)}...{esc.mainAgent.slice(-4)}</span>
                  </span>
                  {esc.totalHiredAgents > 0 && (
                    <span>{esc.totalHiredAgents} sub-agent{esc.totalHiredAgents > 1 ? "s" : ""}</span>
                  )}
                  {esc.createdAt > 0 && (
                    <span>{formatDate(esc.createdAt)}</span>
                  )}
                  {esc.mainAgentPaid && (
                    <span className="flex items-center gap-1 text-emerald-400">
                      <CheckCircle2 className="h-3 w-3" /> Agent Paid
                    </span>
                  )}
                </div>

                {/* Action buttons */}
                <div className="flex flex-wrap gap-3">
                  {/* Download button - show when job is done AND has blob_id */}
                  {isDone && hasBlobId && (
                    <button
                      onClick={() => handleDownload(esc.blobId!)}
                      disabled={isDownloading}
                      className="glow-btn flex items-center gap-2"
                    >
                      {isDownloading ? (
                        <>
                          <Loader2 className="h-4 w-4 animate-spin" />
                          Downloading...
                        </>
                      ) : (
                        <>
                          <Download className="h-4 w-4" />
                          Download Deliverable
                        </>
                      )}
                    </button>
                  )}

                  {/* View blob on aggregator */}
                  {hasBlobId && (
                    <a
                      href={`${WALRUS_AGGREGATOR}/v1/blobs/${esc.blobId}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn-secondary flex items-center gap-2"
                    >
                      <FileText className="h-4 w-4" />
                      View on Walrus
                    </a>
                  )}

                  {/* Blob ID */}
                  {hasBlobId && (
                    <div className="w-full mt-2 text-xs text-(--text-muted) font-mono break-all">
                      Blob ID: {esc.blobId}
                    </div>
                  )}

                  {/* Done but no blob */}
                  {isDone && !hasBlobId && (
                    <span className="flex items-center gap-2 rounded-xl bg-(--bg-card) px-4 py-2.5 text-sm text-(--text-muted)">
                      <FileText className="h-4 w-4" />
                      No deliverable uploaded
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
