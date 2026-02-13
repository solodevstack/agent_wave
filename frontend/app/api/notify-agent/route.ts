import { NextRequest, NextResponse } from "next/server";

/**
 * POST /api/notify-agent
 *
 * Called by the frontend after a new escrow is created.
 * Forwards a notification to the OpenClaw webhook (main session wake)
 * so the agent sees it directly and auto-processes the job.
 *
 * Body: { escrowDigest, jobTitle, mainAgent, budget, mainAgentPrice }
 *
 * The OPENCLAW_HOOKS_TOKEN and OPENCLAW_HOOKS_URL are kept server-side
 * so the webhook secret is never exposed to the browser.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { escrowDigest, jobTitle, mainAgent, budget, mainAgentPrice } = body;

    const hooksToken = process.env.OPENCLAW_HOOKS_TOKEN;
    // Use /hooks/wake to inject into the main session (not isolated /hooks/agent)
    const hooksUrl =
      process.env.OPENCLAW_HOOKS_URL ||
      `http://127.0.0.1:${process.env.OPENCLAW_GATEWAY_PORT || "63362"}/hooks/wake`;

    if (!hooksToken) {
      // Webhook not configured — silently succeed (don't block the user)
      return NextResponse.json({ ok: true, notified: false, reason: "no token" });
    }

    const text = [
      `🚨 New AgentWave escrow created!`,
      ``,
      `Job Title: ${jobTitle || "Unknown"}`,
      `Agent: ${mainAgent || "Unknown"}`,
      `Budget: ${budget ? (Number(budget) / 1e9).toFixed(4) + " SUI" : "Unknown"}`,
      `Agent Price: ${mainAgentPrice ? (Number(mainAgentPrice) / 1e9).toFixed(4) + " SUI" : "Unknown"}`,
      `Tx Digest: ${escrowDigest || "Unknown"}`,
      ``,
      `Proceed with the full AgentWave workflow: accept → start → research (Baselight) → generate PDF → upload Walrus → complete → attach blob ID.`,
    ].join("\n");

    const res = await fetch(hooksUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${hooksToken}`,
      },
      body: JSON.stringify({
        text,
        mode: "now",
      }),
    });

    if (!res.ok) {
      console.error(`[notify-agent] Webhook failed: ${res.status}`);
      return NextResponse.json({ ok: true, notified: false, reason: "webhook error" });
    }

    return NextResponse.json({ ok: true, notified: true });
  } catch (err) {
    console.error("[notify-agent] Error:", err);
    // Don't fail the user's request — notification is best-effort
    return NextResponse.json({ ok: true, notified: false, reason: "error" });
  }
}
