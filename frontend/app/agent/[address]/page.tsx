"use client";

import * as React from "react";
import { use } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/transactions";
import { useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";
import {
  ArrowLeft,
  Briefcase,
  Clock,
  Coins,
  FileText,
  Layers,
  Send,
  User,
  CheckCircle2,
  ExternalLink,
  Star,
  Cpu,
  Activity,
  Eye,
  PenLine,
} from "lucide-react";

import { buildCreateAgenticEscrowTx } from "@/lib/contracts";
import { networkConfig } from "@/config/network.config";

type AgentProfile = {
  owner: string;
  avatar: string;
  name: string;
  capabilities: string[];
  description: string;
  rating: number;
  totalReviews: number;
  completedTasks: number;
  createdAt: number;
  modelType: string;
  isActive: boolean;
};

function mistToSui(mist: bigint) {
  return Number(mist) / 1_000_000_000;
}

function parseMist(input: string): bigint {
  const trimmed = input.trim();
  if (!trimmed) return 0n;
  if (/^\d+$/.test(trimmed)) return BigInt(trimmed);
  const [whole, frac = ""] = trimmed.split(".");
  const fracPadded = (frac + "000000000").slice(0, 9);
  return (whole ? BigInt(whole) : 0n) * 1_000_000_000n + BigInt(fracPadded || "0");
}

function generateAvatarUrl(seed: string) {
  return `https://api.dicebear.com/9.x/bottts-neutral/svg?seed=${encodeURIComponent(seed)}&backgroundColor=1e1b4b,312e81,3730a3&backgroundType=gradientLinear`;
}

function formatDate(timestampMs: number): string {
  if (!timestampMs) return "Unknown";
  return new Date(timestampMs).toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// BCS decoder for a single profile tuple from get_agent_profile
// Returns: (avatar, name, capabilities, description, rating, total_reviews, completed_tasks, created_at, model_type, is_active)
function decodeBcsProfile(data: Uint8Array, ownerAddr: string): AgentProfile | null {
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  let offset = 0;

  function readULEB128(): number {
    let result = 0;
    let shift = 0;
    while (offset < data.length) {
      const byte = data[offset++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) === 0) break;
      shift += 7;
    }
    return result;
  }

  function readString(): string {
    const len = readULEB128();
    const bytes = data.slice(offset, offset + len);
    offset += len;
    return new TextDecoder().decode(bytes);
  }

  function readU64(): number {
    const lo = view.getUint32(offset, true);
    const hi = view.getUint32(offset + 4, true);
    offset += 8;
    return lo + hi * 0x100000000;
  }

  function readBool(): boolean {
    return data[offset++] !== 0;
  }

  function readVectorString(): string[] {
    const len = readULEB128();
    const result: string[] = [];
    for (let i = 0; i < len; i++) {
      result.push(readString());
    }
    return result;
  }

  try {
    // get_agent_profile returns a tuple, which in BCS is serialized as multiple return values
    // But devInspect returns each value separately... Let's handle both cases.
    const avatar = readString();
    const name = readString();
    const capabilities = readVectorString();
    const description = readString();
    const rating = readU64();
    const totalReviews = readU64();
    const completedTasks = readU64();
    const createdAt = readU64();
    const modelType = readString();
    const isActive = readBool();

    return {
      owner: ownerAddr,
      avatar,
      name,
      capabilities,
      description,
      rating,
      totalReviews,
      completedTasks,
      createdAt,
      modelType,
      isActive,
    };
  } catch (e) {
    console.error("BCS profile decode error:", e);
    return null;
  }
}

export default function AgentPage({
  params,
}: {
  params: Promise<{ address: string }>;
}) {
  const { address: agentAddress } = use(params);
  const searchParams = useSearchParams();
  const initialTab = searchParams.get("tab") === "job" ? "job" : "profile";
  const router = useRouter();
  const cfg = networkConfig.testnet.variables;
  const suiClient = useSuiClient();

  const account = useCurrentAccount();
  const { mutateAsync: signAndExecute, isPending } =
    useSignAndExecuteTransaction();

  const [activeTab, setActiveTab] = React.useState<"profile" | "job">(initialTab);
  const [profile, setProfile] = React.useState<AgentProfile | null>(null);
  const [loadingProfile, setLoadingProfile] = React.useState(true);

  // Form state
  const [jobTitle, setJobTitle] = React.useState("");
  const [jobDescription, setJobDescription] = React.useState("");
  const [jobCategory, setJobCategory] = React.useState("");
  const [duration, setDuration] = React.useState("7");
  const [budgetInput, setBudgetInput] = React.useState("0.1");
  const [mainAgentPriceInput, setMainAgentPriceInput] = React.useState("0.05");
  const [lastDigest, setLastDigest] = React.useState<string | null>(null);

  const budgetMist = parseMist(budgetInput);
  const mainAgentPriceMist = parseMist(mainAgentPriceInput);

  // Fetch agent profile from chain
  React.useEffect(() => {
    async function fetchProfile() {
      setLoadingProfile(true);
      try {
        const tx = new Transaction();
        const registry = tx.sharedObjectRef({
          objectId: cfg.agentRegistryId,
          initialSharedVersion: cfg.agentRegistryInitialSharedVersion,
          mutable: false,
        });
        tx.moveCall({
          package: cfg.packageId,
          module: "agentwave_profile",
          function: "get_agent_profile",
          arguments: [registry, tx.pure.address(agentAddress)],
        });

        const result = await suiClient.devInspectTransactionBlock({
          transactionBlock: tx,
          sender: "0x0000000000000000000000000000000000000000000000000000000000000000",
        });

        if (result.results?.[0]?.returnValues) {
          const returnValues = result.results[0].returnValues;
          // get_agent_profile returns 10 values as a tuple — each is a separate returnValue
          // But if devInspect returns them separately, we need to handle that
          // Let's try: if there's one returnValue, it's all packed; if 10, they're separate

          if (returnValues.length === 1) {
            // All packed in one BCS blob
            const raw = returnValues[0];
            if (raw && Array.isArray(raw) && raw[0]) {
              const bytes = new Uint8Array(raw[0] as number[]);
              const p = decodeBcsProfile(bytes, agentAddress);
              if (p) {
                setProfile(p);
                setLoadingProfile(false);
                return;
              }
            }
          } else if (returnValues.length >= 10) {
            // Each return value is separate BCS-encoded
            const decodeStr = (rv: unknown[]): string => {
              const bytes = new Uint8Array(rv[0] as number[]);
              let offset = 0;
              let len = 0;
              let shift = 0;
              while (offset < bytes.length) {
                const byte = bytes[offset++];
                len |= (byte & 0x7f) << shift;
                if ((byte & 0x80) === 0) break;
                shift += 7;
              }
              return new TextDecoder().decode(bytes.slice(offset, offset + len));
            };
            const decodeVecStr = (rv: unknown[]): string[] => {
              const bytes = new Uint8Array(rv[0] as number[]);
              let offset = 0;
              const readULEB = () => {
                let result = 0, shift = 0;
                while (offset < bytes.length) {
                  const byte = bytes[offset++];
                  result |= (byte & 0x7f) << shift;
                  if ((byte & 0x80) === 0) break;
                  shift += 7;
                }
                return result;
              };
              const count = readULEB();
              const strs: string[] = [];
              for (let i = 0; i < count; i++) {
                const len = readULEB();
                strs.push(new TextDecoder().decode(bytes.slice(offset, offset + len)));
                offset += len;
              }
              return strs;
            };
            const decodeU64 = (rv: unknown[]): number => {
              const bytes = new Uint8Array(rv[0] as number[]);
              const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
              return dv.getUint32(0, true) + dv.getUint32(4, true) * 0x100000000;
            };
            const decodeBool = (rv: unknown[]): boolean => {
              const bytes = new Uint8Array(rv[0] as number[]);
              return bytes[0] !== 0;
            };

            try {
              const p: AgentProfile = {
                owner: agentAddress,
                avatar: decodeStr(returnValues[0] as unknown[]),
                name: decodeStr(returnValues[1] as unknown[]),
                capabilities: decodeVecStr(returnValues[2] as unknown[]),
                description: decodeStr(returnValues[3] as unknown[]),
                rating: decodeU64(returnValues[4] as unknown[]),
                totalReviews: decodeU64(returnValues[5] as unknown[]),
                completedTasks: decodeU64(returnValues[6] as unknown[]),
                createdAt: decodeU64(returnValues[7] as unknown[]),
                modelType: decodeStr(returnValues[8] as unknown[]),
                isActive: decodeBool(returnValues[9] as unknown[]),
              };
              setProfile(p);
              setLoadingProfile(false);
              return;
            } catch (decErr) {
              console.error("Failed to decode separate return values:", decErr);
            }
          }
        }

        // Fallback: just use address as minimal profile
        setProfile({
          owner: agentAddress,
          name: agentAddress.slice(0, 10) + "...",
          avatar: "",
          capabilities: [],
          description: "",
          rating: 0,
          totalReviews: 0,
          completedTasks: 0,
          createdAt: 0,
          modelType: "",
          isActive: true,
        });
      } catch (e) {
        console.error("Failed to fetch profile:", e);
        setProfile({
          owner: agentAddress,
          name: agentAddress.slice(0, 10) + "...",
          avatar: "",
          capabilities: [],
          description: "",
          rating: 0,
          totalReviews: 0,
          completedTasks: 0,
          createdAt: 0,
          modelType: "",
          isActive: true,
        });
      } finally {
        setLoadingProfile(false);
      }
    }

    void fetchProfile();
  }, [agentAddress, cfg, suiClient]);

  async function onCreateEscrow(e: React.FormEvent) {
    e.preventDefault();

    if (!account?.address) {
      toast.error("Connect a wallet first");
      return;
    }
    if (!jobTitle.trim()) {
      toast.error("Job title is required");
      return;
    }
    if (budgetMist <= 0n) {
      toast.error("Budget must be greater than 0");
      return;
    }
    if (mainAgentPriceMist <= 0n) {
      toast.error("Agent price must be greater than 0");
      return;
    }
    if (mainAgentPriceMist > budgetMist) {
      toast.error("Agent price cannot exceed budget");
      return;
    }
    const durationNum = Number(duration) || 7;
    if (durationNum < 1 || durationNum > 255) {
      toast.error("Duration must be between 1 and 255");
      return;
    }

    const tx = buildCreateAgenticEscrowTx({
      mainAgent: agentAddress,
      jobTitle: jobTitle.trim(),
      jobDescription: jobDescription.trim(),
      jobCategory: jobCategory.trim() || "general",
      duration: durationNum,
      budgetMist,
      mainAgentPriceMist,
    });

    try {
      const res = await signAndExecute({ transaction: tx });
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const digest = (res as any)?.digest || (res as any)?.effects?.transactionDigest;
      setLastDigest(digest ?? null);
      toast.success("Escrow created successfully!");

      // Notify the AI agent via webhook (best-effort, non-blocking)
      fetch("/api/notify-agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          escrowDigest: digest,
          jobTitle: jobTitle.trim(),
          mainAgent: agentAddress,
          budget: budgetMist.toString(),
          mainAgentPrice: mainAgentPriceMist.toString(),
        }),
      }).catch(() => {/* silent — notification is best-effort */});
    } catch (e) {
      toast.error(e instanceof Error ? e.message : String(e));
    }
  }

  const shortAgent = `${agentAddress.slice(0, 8)}...${agentAddress.slice(-6)}`;
  const displayName = profile?.name || shortAgent;
  const avatarUrl = profile?.avatar || generateAvatarUrl(agentAddress);

  return (
    <div className="mx-auto max-w-3xl px-6 pb-20">
      {/* Back button */}
      <button
        onClick={() => router.push("/")}
        className="btn-secondary mb-8 flex items-center gap-2"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Marketplace
      </button>

      {/* Agent Header Card */}
      <div className="glass-card mb-6 p-8">
        {loadingProfile ? (
          <div className="flex items-start gap-6">
            <div className="shimmer h-20 w-20 rounded-2xl" />
            <div className="flex-1 space-y-3">
              <div className="shimmer h-7 w-48 rounded-lg" />
              <div className="shimmer h-4 w-32 rounded-lg" />
              <div className="flex gap-2">
                <div className="shimmer h-6 w-16 rounded-full" />
                <div className="shimmer h-6 w-20 rounded-full" />
              </div>
            </div>
          </div>
        ) : (
          <div className="flex items-start gap-6">
            <div className="relative">
              <img
                src={avatarUrl}
                alt={displayName}
                className="h-20 w-20 rounded-2xl border border-(--border-subtle)"
              />
              {profile?.isActive && (
                <div className="pulse-dot absolute -bottom-0.5 -right-0.5" />
              )}
            </div>
            <div className="min-w-0 flex-1">
              <div className="mb-1 flex items-center gap-3">
                <h1 className="text-2xl font-bold">{displayName}</h1>
                {profile?.isActive ? (
                  <span className="badge-success badge">Active</span>
                ) : (
                  <span className="badge">Inactive</span>
                )}
              </div>
              <p className="mb-3 font-mono text-sm text-(--text-muted)">{shortAgent}</p>

              {/* Description */}
              {profile?.description && (
                <p className="mb-3 text-sm text-(--text-secondary)">{profile.description}</p>
              )}

              <div className="flex flex-wrap gap-2">
                {profile?.modelType && (
                  <span className="badge flex items-center gap-1">
                    <Cpu className="h-3 w-3" />
                    {profile.modelType}
                  </span>
                )}
                {profile?.capabilities.map((cap) => (
                  <span key={cap} className="badge">{cap}</span>
                ))}
              </div>

              {/* Stats */}
              {profile && (profile.rating > 0 || profile.completedTasks > 0 || profile.createdAt > 0) && (
                <div className="mt-4 flex flex-wrap gap-5 text-sm text-(--text-muted)">
                  {profile.rating > 0 && (
                    <span className="flex items-center gap-1.5">
                      <Star className="h-4 w-4 text-amber-400" />
                      {profile.rating}/100
                      {profile.totalReviews > 0 && (
                        <span className="text-xs">({profile.totalReviews} reviews)</span>
                      )}
                    </span>
                  )}
                  {profile.completedTasks > 0 && (
                    <span className="flex items-center gap-1.5">
                      <Activity className="h-4 w-4" />
                      {profile.completedTasks} completed
                    </span>
                  )}
                  {profile.createdAt > 0 && (
                    <span className="flex items-center gap-1.5">
                      <Clock className="h-4 w-4" />
                      Joined {formatDate(profile.createdAt)}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="mb-6 flex gap-1 rounded-xl bg-(--bg-card) p-1">
        <button
          onClick={() => setActiveTab("profile")}
          className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-all ${
            activeTab === "profile"
              ? "bg-(--accent-glow) text-(--accent-light)"
              : "text-(--text-muted) hover:text-(--text-secondary)"
          }`}
        >
          <Eye className="h-4 w-4" />
          Profile
        </button>
        <button
          onClick={() => setActiveTab("job")}
          className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-all ${
            activeTab === "job"
              ? "bg-(--accent-glow) text-(--accent-light)"
              : "text-(--text-muted) hover:text-(--text-secondary)"
          }`}
        >
          <PenLine className="h-4 w-4" />
          Create Job
        </button>
      </div>

      {/* Profile Tab */}
      {activeTab === "profile" && (
        <div className="space-y-4">
          {/* Overview */}
          <div className="glass-card p-6">
            <h3 className="mb-4 text-lg font-semibold">Agent Overview</h3>
            <div className="grid gap-4 sm:grid-cols-3">
              <div className="rounded-xl bg-(--bg-card) p-4 text-center">
                <div className="text-2xl font-bold text-(--accent-light)">
                  {profile?.rating || 0}
                </div>
                <div className="text-xs text-(--text-muted)">Rating / 100</div>
              </div>
              <div className="rounded-xl bg-(--bg-card) p-4 text-center">
                <div className="text-2xl font-bold text-(--accent-light)">
                  {profile?.completedTasks || 0}
                </div>
                <div className="text-xs text-(--text-muted)">Completed Tasks</div>
              </div>
              <div className="rounded-xl bg-(--bg-card) p-4 text-center">
                <div className="text-2xl font-bold text-(--accent-light)">
                  {profile?.totalReviews || 0}
                </div>
                <div className="text-xs text-(--text-muted)">Total Reviews</div>
              </div>
            </div>
          </div>

          {/* Capabilities */}
          {profile?.capabilities && profile.capabilities.length > 0 && (
            <div className="glass-card p-6">
              <h3 className="mb-3 text-lg font-semibold">Capabilities</h3>
              <div className="flex flex-wrap gap-2">
                {profile.capabilities.map((cap) => (
                  <span key={cap} className="badge">{cap}</span>
                ))}
              </div>
            </div>
          )}

          {/* Details */}
          <div className="glass-card p-6">
            <h3 className="mb-3 text-lg font-semibold">Details</h3>
            <div className="space-y-3 text-sm">
              <div className="flex justify-between">
                <span className="text-(--text-muted)">Address</span>
                <span className="font-mono text-xs">{agentAddress}</span>
              </div>
              {profile?.modelType && (
                <div className="flex justify-between">
                  <span className="text-(--text-muted)">Model</span>
                  <span>{profile.modelType}</span>
                </div>
              )}
              {profile?.createdAt ? (
                <div className="flex justify-between">
                  <span className="text-(--text-muted)">Registered</span>
                  <span>{formatDate(profile.createdAt)}</span>
                </div>
              ) : null}
              <div className="flex justify-between">
                <span className="text-(--text-muted)">Status</span>
                <span>{profile?.isActive ? "Active" : "Inactive"}</span>
              </div>
            </div>
          </div>

          {/* CTA */}
          <button
            onClick={() => setActiveTab("job")}
            className="glow-btn flex w-full items-center justify-center gap-2 py-3.5"
          >
            <PenLine className="h-4 w-4" />
            Create a Job with this Agent
          </button>
        </div>
      )}

      {/* Job Tab */}
      {activeTab === "job" && (
        <>
          {lastDigest ? (
            <div className="glass-card border-emerald-500/20 p-8 text-center">
              <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
                <CheckCircle2 className="h-8 w-8 text-emerald-400" />
              </div>
              <h2 className="mb-2 text-xl font-bold">Escrow Created!</h2>
              <p className="mb-4 text-sm text-(--text-secondary)">
                Your job has been submitted on-chain. The agent can now review and accept it.
              </p>
              <div className="mb-6 rounded-xl bg-(--bg-card) p-4">
                <p className="mb-1 text-xs text-(--text-muted)">Transaction Digest</p>
                <p className="break-all font-mono text-sm">{lastDigest}</p>
              </div>
              <div className="flex justify-center gap-3">
                <a
                  href={`https://suiscan.xyz/testnet/tx/${lastDigest}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="glow-btn flex items-center gap-2"
                >
                  View on Explorer
                  <ExternalLink className="h-4 w-4" />
                </a>
                <button
                  onClick={() => {
                    setLastDigest(null);
                    setJobTitle("");
                    setJobDescription("");
                    setJobCategory("");
                    setDuration("7");
                    setBudgetInput("0.1");
                    setMainAgentPriceInput("0.05");
                  }}
                  className="btn-secondary"
                >
                  Create Another
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={onCreateEscrow}>
              <div className="glass-card p-8">
                <div className="mb-6">
                  <h2 className="mb-1 text-xl font-bold">Create a Job</h2>
                  <p className="text-sm text-(--text-secondary)">
                    Define your job details. An escrow will be created on-chain to protect both parties.
                  </p>
                </div>

                <hr className="divider mb-6" />

                <div className="space-y-5">
                  <div>
                    <label className="mb-2 flex items-center gap-2 text-sm font-medium text-(--text-secondary)">
                      <Briefcase className="h-4 w-4" />
                      Job Title
                    </label>
                    <input
                      type="text"
                      value={jobTitle}
                      onChange={(e) => setJobTitle(e.target.value)}
                      placeholder="e.g. Build a smart contract for NFT marketplace"
                      className="input-field"
                      required
                    />
                  </div>

                  <div>
                    <label className="mb-2 flex items-center gap-2 text-sm font-medium text-(--text-secondary)">
                      <FileText className="h-4 w-4" />
                      Description
                    </label>
                    <textarea
                      value={jobDescription}
                      onChange={(e) => setJobDescription(e.target.value)}
                      placeholder="Describe the job requirements, deliverables, and any relevant details..."
                      rows={5}
                      className="input-field resize-none"
                    />
                  </div>

                  <div>
                    <label className="mb-2 flex items-center gap-2 text-sm font-medium text-(--text-secondary)">
                      <Layers className="h-4 w-4" />
                      Category
                    </label>
                    <input
                      type="text"
                      value={jobCategory}
                      onChange={(e) => setJobCategory(e.target.value)}
                      placeholder="e.g. development, design, writing, research"
                      className="input-field"
                    />
                  </div>

                  <div>
                    <label className="mb-2 flex items-center gap-2 text-sm font-medium text-(--text-secondary)">
                      <Clock className="h-4 w-4" />
                      Duration (days)
                    </label>
                    <input
                      type="number"
                      min={1}
                      max={255}
                      value={duration}
                      onChange={(e) => setDuration(e.target.value)}
                      placeholder="7"
                      className="input-field"
                    />
                    <p className="mt-1 text-xs text-(--text-muted)">
                      1-255 days (stored as u8 in the smart contract)
                    </p>
                  </div>

                  <hr className="divider" />

                  <div>
                    <h3 className="mb-4 flex items-center gap-2 font-semibold">
                      <Coins className="h-4 w-4 text-(--accent-light)" />
                      Budget & Pricing
                    </h3>

                    <div className="grid gap-5 sm:grid-cols-2">
                      <div>
                        <label className="mb-2 block text-sm font-medium text-(--text-secondary)">
                          Total Budget (SUI)
                        </label>
                        <input
                          type="text"
                          value={budgetInput}
                          onChange={(e) => setBudgetInput(e.target.value)}
                          placeholder="0.1"
                          className="input-field"
                        />
                        <p className="mt-1 text-xs text-(--text-muted)">
                          {mistToSui(budgetMist).toFixed(9)} SUI
                        </p>
                      </div>

                      <div>
                        <label className="mb-2 block text-sm font-medium text-(--text-secondary)">
                          Agent Price (SUI)
                        </label>
                        <input
                          type="text"
                          value={mainAgentPriceInput}
                          onChange={(e) => setMainAgentPriceInput(e.target.value)}
                          placeholder="0.05"
                          className="input-field"
                        />
                        <p className="mt-1 text-xs text-(--text-muted)">
                          {mistToSui(mainAgentPriceMist).toFixed(9)} SUI
                        </p>
                      </div>
                    </div>

                    {budgetMist > 0n && mainAgentPriceMist > 0n && (
                      <div className="mt-4 rounded-xl bg-(--bg-card) p-4">
                        <p className="mb-2 text-xs font-medium uppercase tracking-wider text-(--text-muted)">
                          Cost Breakdown
                        </p>
                        <div className="space-y-1.5 text-sm">
                          <div className="flex justify-between">
                            <span className="text-(--text-secondary)">Agent payment</span>
                            <span>{mistToSui(mainAgentPriceMist).toFixed(4)} SUI</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-(--text-secondary)">Remaining for sub-agents</span>
                            <span>
                              {budgetMist > mainAgentPriceMist
                                ? mistToSui(budgetMist - mainAgentPriceMist).toFixed(4)
                                : "0"}{" "}
                              SUI
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-(--text-secondary)">Platform fee (5%)</span>
                            <span className="text-(--text-muted)">
                              {mistToSui((mainAgentPriceMist * 5n) / 100n).toFixed(4)} SUI
                            </span>
                          </div>
                          <hr className="divider my-2" />
                          <div className="flex justify-between font-semibold">
                            <span>Total escrowed</span>
                            <span className="text-(--accent-light)">
                              {mistToSui(budgetMist).toFixed(4)} SUI
                            </span>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>

                  <hr className="divider" />

                  <div className="flex items-center gap-3 rounded-xl bg-(--bg-card) p-4">
                    <User className="h-5 w-5 text-(--text-muted)" />
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium">Assigned Agent: {displayName}</p>
                      <p className="truncate font-mono text-xs text-(--text-muted)">
                        {agentAddress}
                      </p>
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={isPending || !account?.address}
                    className="glow-btn flex w-full items-center justify-center gap-2 py-3.5 text-base"
                  >
                    {isPending ? (
                      <>
                        <div className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
                        Creating Escrow...
                      </>
                    ) : (
                      <>
                        <Send className="h-4 w-4" />
                        Create Escrow & Fund Job
                      </>
                    )}
                  </button>

                  {!account?.address && (
                    <p className="text-center text-sm text-amber-400">
                      Connect your wallet to create a job
                    </p>
                  )}
                </div>
              </div>
            </form>
          )}
        </>
      )}
    </div>
  );
}
