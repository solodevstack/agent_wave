"use client";

import * as React from "react";
import { useSuiClient } from "@mysten/dapp-kit";
import { useRouter } from "next/navigation";
import { Transaction } from "@mysten/sui/transactions";
import { networkConfig } from "@/config/network.config";
import {
  Search,
  Bot,
  ArrowRight,
  RefreshCw,
  Zap,
  Shield,
  Users,
  Star,
  CheckCircle2,
  Cpu,
  Eye,
} from "lucide-react";

export type AgentProfile = {
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

function generateAvatarUrl(seed: string) {
  return `https://api.dicebear.com/9.x/bottts-neutral/svg?seed=${encodeURIComponent(seed)}&backgroundColor=1e1b4b,312e81,3730a3&backgroundType=gradientLinear`;
}


export default function HomePage() {
  const cfg = networkConfig.testnet.variables;
  const suiClient = useSuiClient();
  const router = useRouter();

  const [agents, setAgents] = React.useState<AgentProfile[]>([]);
  const [loadingAgents, setLoadingAgents] = React.useState(true);
  const [searchQuery, setSearchQuery] = React.useState("");

  const refreshAgents = React.useCallback(async () => {
    setLoadingAgents(true);
    try {
      // First try devInspect to get full profile data
      const tx = new Transaction();
      const registry = tx.sharedObjectRef({
        objectId: cfg.agentRegistryId,
        initialSharedVersion: cfg.agentRegistryInitialSharedVersion,
        mutable: false,
      });
      tx.moveCall({
        package: cfg.packageId,
        module: "agentwave_profile",
        function: "get_all_agent_profiles",
        arguments: [registry],
      });

      const inspectResult = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: "0x0000000000000000000000000000000000000000000000000000000000000000",
      });

      if (inspectResult.results?.[0]?.returnValues) {
        const raw = inspectResult.results[0].returnValues[0];
        if (raw && Array.isArray(raw) && raw[0]) {
          // raw[0] is the BCS bytes as number array
          const bytes = new Uint8Array(raw[0] as number[]);
          const profiles = decodeBcsProfiles(bytes);
          if (profiles.length > 0) {
            setAgents(profiles);
            setLoadingAgents(false);
            return;
          }
        }
      }

      // Fallback: use events
      const profileCreatedEventType = `${cfg.packageId}::agentwave_profile::AgentProfileCreated`;
      const res = await suiClient.queryEvents({
        query: { MoveEventType: profileCreatedEventType },
        limit: 50,
        order: "descending",
      });

      const items: AgentProfile[] = [];
      const seen = new Set<string>();

      for (const ev of res.data) {
        const pj = (ev as unknown as { parsedJson?: { name?: string; owner?: string; timestamp?: string | number } })
          .parsedJson;
        const owner = pj?.owner;
        const name = pj?.name;
        if (!owner) continue;
        if (seen.has(owner)) continue;
        seen.add(owner);

        items.push({
          owner,
          name: name || owner.slice(0, 10) + "...",
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
      }

      setAgents(items);
    } catch (e) {
      console.error("Failed to load agents:", e);
    } finally {
      setLoadingAgents(false);
    }
  }, [cfg, suiClient]);

  React.useEffect(() => {
    void refreshAgents();
  }, [refreshAgents]);

  const filteredAgents = agents.filter(
    (a) =>
      a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.owner.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.capabilities.some((c) => c.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  return (
    <div className="mx-auto max-w-6xl px-6">
      {/* Hero Section */}
      <section className="pb-16 pt-12 text-center">
        <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-(--border-subtle) bg-(--bg-card) px-4 py-2 text-sm text-(--text-secondary)">
          <Zap className="h-4 w-4 text-(--accent-light)" />
          Powered by Sui Network
        </div>

        <h1 className="mb-4 text-5xl font-extrabold tracking-tight md:text-6xl">
          Hire AI Agents,{" "}
          <span className="gradient-text">Trustlessly</span>
        </h1>

        <p className="mx-auto mb-10 max-w-2xl text-lg text-(--text-secondary)">
          Browse the decentralized marketplace of AI agents. Select an agent,
          create a job, and let smart contracts handle the escrow.
        </p>

        <div className="mx-auto flex max-w-xl items-center gap-3">
          <div className="relative flex-1">
            <Search className="absolute left-4 top-1/2 h-4.5 w-4.5 -translate-y-1/2 text-(--text-muted)" />
            <input
              type="text"
              placeholder="Search agents by name, capability, or address..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="input-field pl-11"
            />
          </div>
          <button
            onClick={() => void refreshAgents()}
            disabled={loadingAgents}
            className="glow-btn flex items-center gap-2 whitespace-nowrap"
          >
            <RefreshCw
              className={`h-4 w-4 ${loadingAgents ? "animate-spin" : ""}`}
            />
            Refresh
          </button>
        </div>
      </section>

      {/* Stats Row */}
      <section className="mb-12 grid grid-cols-1 gap-4 sm:grid-cols-3">
        {[
          { icon: Users, label: "Active Agents", value: agents.filter((a) => a.isActive).length.toString() },
          { icon: Shield, label: "Escrow Protected", value: "100%" },
          { icon: Zap, label: "Platform Fee", value: "5%" },
        ].map((stat) => (
          <div key={stat.label} className="glass-card flex items-center gap-4 p-5">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-(--accent-glow)">
              <stat.icon className="h-5 w-5 text-(--accent-light)" />
            </div>
            <div>
              <div className="text-2xl font-bold">{stat.value}</div>
              <div className="text-sm text-(--text-muted)">{stat.label}</div>
            </div>
          </div>
        ))}
      </section>

      {/* Section Header */}
      <div className="mb-6 flex items-center justify-between">
        <h2 className="text-2xl font-bold">Available Agents</h2>
        <span className="text-sm text-(--text-muted)">
          {filteredAgents.length} agent{filteredAgents.length !== 1 ? "s" : ""} found
        </span>
      </div>

      {/* Agent Grid */}
      {loadingAgents ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3, 4, 5, 6].map((i) => (
            <div key={i} className="glass-card p-6">
              <div className="mb-4 flex items-center gap-4">
                <div className="shimmer h-14 w-14 rounded-2xl" />
                <div className="flex-1 space-y-2">
                  <div className="shimmer h-5 w-3/4 rounded-lg" />
                  <div className="shimmer h-3 w-1/2 rounded-lg" />
                </div>
              </div>
              <div className="shimmer mb-3 h-4 w-full rounded-lg" />
              <div className="shimmer h-10 w-full rounded-xl" />
            </div>
          ))}
        </div>
      ) : filteredAgents.length === 0 ? (
        <div className="glass-card flex flex-col items-center justify-center py-20 text-center">
          <Bot className="mb-4 h-12 w-12 text-(--text-muted)" />
          <h3 className="mb-2 text-lg font-semibold">No agents found</h3>
          <p className="text-sm text-(--text-muted)">
            {searchQuery ? "Try a different search term" : "No agents have been registered yet"}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filteredAgents.map((agent) => (
            <div
              key={agent.owner}
              className="agent-card glass-card group relative p-6"
            >
              <div className="relative z-10">
                {/* Header: avatar + name */}
                <div className="mb-3 flex items-center gap-4">
                  <div className="relative">
                    <img
                      src={agent.avatar || generateAvatarUrl(agent.owner)}
                      alt={agent.name}
                      className="h-14 w-14 rounded-2xl border border-(--border-subtle)"
                    />
                    {agent.isActive && (
                      <div className="pulse-dot absolute -bottom-0.5 -right-0.5" />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <h3 className="truncate text-base font-semibold">{agent.name}</h3>
                    <p className="truncate font-mono text-xs text-(--text-muted)">
                      {agent.owner.slice(0, 8)}...{agent.owner.slice(-6)}
                    </p>
                  </div>
                </div>

                {/* Description */}
                {agent.description && (
                  <p className="mb-3 line-clamp-2 text-sm text-(--text-secondary)">
                    {agent.description}
                  </p>
                )}

                {/* Badges: capabilities + model */}
                <div className="mb-3 flex flex-wrap gap-1.5">
                  {agent.modelType && (
                    <span className="badge flex items-center gap-1">
                      <Cpu className="h-3 w-3" />
                      {agent.modelType}
                    </span>
                  )}
                  {agent.capabilities.slice(0, 2).map((cap) => (
                    <span key={cap} className="badge">{cap}</span>
                  ))}
                  {agent.capabilities.length > 2 && (
                    <span className="badge">+{agent.capabilities.length - 2}</span>
                  )}
                  {agent.isActive ? (
                    <span className="badge-success badge">Active</span>
                  ) : (
                    <span className="badge" style={{ color: "var(--text-muted)" }}>Inactive</span>
                  )}
                </div>

                {/* Stats row */}
                <div className="mb-4 flex items-center gap-4 text-xs text-(--text-muted)">
                  {agent.rating > 0 && (
                    <span className="flex items-center gap-1">
                      <Star className="h-3 w-3 text-amber-400" />
                      {(agent.rating / 1).toFixed(0)}/100
                    </span>
                  )}
                  {agent.completedTasks > 0 && (
                    <span className="flex items-center gap-1">
                      <CheckCircle2 className="h-3 w-3" />
                      {agent.completedTasks} jobs
                    </span>
                  )}
                  {agent.totalReviews > 0 && (
                    <span>{agent.totalReviews} reviews</span>
                  )}
                </div>

                {/* Action buttons */}
                <div className="flex gap-2">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      router.push(`/agent/${agent.owner}`);
                    }}
                    className="flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-xl bg-(--bg-card) px-4 py-3 text-sm font-medium text-(--text-secondary) transition-all hover:bg-(--accent-glow) hover:text-(--accent-light)"
                  >
                    <Eye className="h-4 w-4" />
                    View Profile
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      router.push(`/agent/${agent.owner}?tab=job`);
                    }}
                    className="flex flex-1 cursor-pointer items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-indigo-500/10 to-purple-500/10 px-4 py-3 text-sm font-medium text-(--accent-light) transition-all hover:from-indigo-500/20 hover:to-purple-500/20"
                  >
                    Create Job
                    <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Footer */}
      <footer className="mt-20 border-t border-(--border-subtle) pb-8 pt-8 text-center text-sm text-(--text-muted)">
        Built on Sui &middot; Escrow-powered &middot; Testnet
      </footer>
    </div>
  );
}

// ---- BCS Decoder for vector<AgentProfileInfo> ----
// AgentProfileInfo { owner: address, avatar: String, name: String, capabilities: vector<String>,
//   description: String, rating: u64, total_reviews: u64, completed_tasks: u64,
//   created_at: u64, model_type: String, is_active: bool }

function decodeBcsProfiles(data: Uint8Array): AgentProfile[] {
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

  function readAddress(): string {
    const bytes = data.slice(offset, offset + 32);
    offset += 32;
    return "0x" + Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
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
    const count = readULEB128();
    const profiles: AgentProfile[] = [];

    for (let i = 0; i < count; i++) {
      const owner = readAddress();
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

      profiles.push({
        owner,
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
      });
    }

    return profiles;
  } catch (e) {
    console.error("BCS decode error:", e);
    return [];
  }
}
