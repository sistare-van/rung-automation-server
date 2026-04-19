const { Client: NotionClient } = require("@notionhq/client");
const Anthropic = require("@anthropic-ai/sdk");
const { execSync } = require("node:child_process");
const { readFileSync } = require("node:fs");

const {
  RESEND_API_KEY,
  NOTION_TOKEN,
  NOTION_DATABASE_ID,
  CLAUDE_API_KEY,
  GITHUB_TOKEN,
  GITHUB_USER = "sistare-van",
  BRIEFING_TO = "sistareae@gmail.com",
  BRIEFING_FROM = "Rung Daily <onboarding@resend.dev>",
} = process.env;

const requireEnv = (name, v) => {
  if (!v) throw new Error(`missing env: ${name}`);
  return v;
};

requireEnv("RESEND_API_KEY", RESEND_API_KEY);
requireEnv("CLAUDE_API_KEY", CLAUDE_API_KEY);

const today = new Date().toLocaleDateString("en-CA", { timeZone: "America/New_York" });

function safeSync(fn, fallback = "") {
  try { return fn(); } catch { return fallback; }
}
async function safeAsync(fn, fallback) {
  try { return await fn(); } catch (e) { console.warn("safeAsync:", e.message); return fallback; }
}

function esc(s) {
  return String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

async function fetchGithubEvents() {
  if (!GITHUB_TOKEN) return [];
  const cutoff = Date.now() - 24 * 3600 * 1000;
  const interesting = new Set([
    "PushEvent",
    "PullRequestEvent",
    "IssuesEvent",
    "IssueCommentEvent",
    "PullRequestReviewEvent",
    "PullRequestReviewCommentEvent",
    "CreateEvent",
    "ReleaseEvent",
  ]);
  const resp = await fetch(`https://api.github.com/users/${GITHUB_USER}/events?per_page=100`, {
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "rung-daily-brief",
    },
  });
  if (!resp.ok) throw new Error(`GitHub ${resp.status}: ${await resp.text()}`);
  const events = await resp.json();
  return events
    .filter(e => interesting.has(e.type) && new Date(e.created_at).getTime() >= cutoff)
    .map(e => ({
      type: e.type,
      repo: e.repo?.name,
      time: e.created_at,
      summary: summarizeEvent(e),
    }));
}

function summarizeEvent(e) {
  const p = e.payload || {};
  switch (e.type) {
    case "PushEvent":
      return `pushed ${p.size || p.commits?.length || 0} commit(s) to ${p.ref?.replace("refs/heads/", "") || "?"}: ${(p.commits || []).map(c => c.message.split("\n")[0]).join(" | ")}`;
    case "PullRequestEvent":
      return `${p.action} PR #${p.number}: ${p.pull_request?.title}`;
    case "IssuesEvent":
      return `${p.action} issue #${p.issue?.number}: ${p.issue?.title}`;
    case "IssueCommentEvent":
      return `commented on #${p.issue?.number}: ${(p.comment?.body || "").slice(0, 120)}`;
    case "PullRequestReviewEvent":
      return `${p.action} review on PR #${p.pull_request?.number}`;
    case "PullRequestReviewCommentEvent":
      return `review comment on PR #${p.pull_request?.number}`;
    case "CreateEvent":
      return `created ${p.ref_type}${p.ref ? " " + p.ref : ""}`;
    case "ReleaseEvent":
      return `${p.action} release ${p.release?.tag_name}`;
    default:
      return e.type;
  }
}

function extractWorkLog() {
  const raw = safeSync(() => readFileSync("work-log.md", "utf8"));
  if (!raw) return "";
  const sections = raw.split(/^##\s+/m).slice(1);
  return sections.slice(0, 2).map(s => "## " + s).join("\n").trim();
}

async function gather() {
  const gitLog = safeSync(() =>
    execSync("git log --since='2 days ago' --pretty=format:'%h %ai %s' --all", { encoding: "utf8" }).trim()
  );
  const claudeMd = safeSync(() => readFileSync("CLAUDE.md", "utf8"));
  const workLog = extractWorkLog();
  const githubEvents = await safeAsync(fetchGithubEvents, []);

  let leads = [];
  if (NOTION_TOKEN && NOTION_DATABASE_ID) {
    const notion = new NotionClient({ auth: NOTION_TOKEN });
    leads = await safeAsync(async () => {
      const cutoff = new Date(Date.now() - 48 * 3600 * 1000).toISOString();
      const res = await notion.databases.query({
        database_id: NOTION_DATABASE_ID,
        filter: { timestamp: "created_time", created_time: { after: cutoff } },
        sorts: [{ timestamp: "created_time", direction: "descending" }],
        page_size: 20,
      });
      return res.results.map(r => r.properties);
    }, []);
  }

  return { gitLog, claudeMd, workLog, githubEvents, leads };
}

async function composeDynamic({ gitLog, claudeMd, workLog, githubEvents, leads }) {
  const anthropic = new Anthropic({ apiKey: CLAUDE_API_KEY });
  const prompt = `Today's date: ${today}.

You're composing a daily briefing email for Van Sistare, who runs Rung Productions (a web agency selling websites + automation to local service businesses).

## Work log (Van's own session notes, most recent entries — HIGHEST SIGNAL for what he did + what he's thinking)
${workLog || "No work-log.md entries found."}

## GitHub activity across all repos (last 24h, ${githubEvents.length} events)
${githubEvents.length ? JSON.stringify(githubEvents, null, 2).slice(0, 3000) : "No GitHub activity."}

## Recent git activity (rung-automation-server checkout, last 48h)
${gitLog || "No commits."}

## CLAUDE.md context
${(claudeMd || "Not found.").slice(0, 4000)}

## Recent Notion leads (last 48h, ${leads.length} entries)
${JSON.stringify(leads, null, 2).slice(0, 3000)}

Return JSON with exactly these keys (no prose, no markdown fences):
{
  "yesterday_progress": [3-6 short bullet strings synthesizing the work log + GitHub activity + leads + notable state. Prefer specifics over generalities. If the work log is present, weight it heavily — it's Van's own words about what he did.],
  "todo_list": [3-5 concrete prioritized actions for today, focused on first paying client + sales pipeline + finishing blockers. If the work log mentions open threads or next steps, surface them.],
  "claude_tip": "One 2-3 sentence practical Claude Code tip. Rotate topics across days (/init, worktrees, MCP, slash commands, subagents, hooks, keyboard shortcuts)."
}`;

  const msg = await anthropic.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1500,
    messages: [{ role: "user", content: prompt }],
  });
  const text = msg.content.map(b => b.text || "").join("");
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error(`Claude returned no JSON: ${text.slice(0, 200)}`);
  return JSON.parse(match[0]);
}

function buildHtml({ yesterday_progress, todo_list, claude_tip }) {
  const bullets = arr => (arr || []).map(b => `<li>${esc(b)}</li>`).join("");
  return `<div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:640px;line-height:1.5;color:#1a1a1a">
  <h2 style="margin-bottom:0">Rung Daily Briefing</h2>
  <p style="color:#666;margin-top:4px">${esc(today)}</p>

  <h3>Yesterday's Progress</h3>
  <ul>${bullets(yesterday_progress)}</ul>

  <h3>Rung Productions Website — Go-Live Checklist</h3>
  <ul>
    <li>Deploy dedicated Rung webhook server (clone rung-automation-server, set env vars, Railway deploy)</li>
    <li>Update form.js in rung-productions-site/ to the new Railway URL</li>
    <li>Deploy static site to Netlify + connect rungproductions.com (Porkbun DNS)</li>
    <li>Remove dev temp stuff: bg-switcher UI, js/bg-switcher.js + script tag, variants/ folder</li>
    <li>Favicon (create or remove reference in index.html)</li>
    <li>OG image (referenced but file missing)</li>
    <li>End-to-end form test (email to sistareae@gmail.com + SMS to +14074579460)</li>
  </ul>

  <h3>Today's To-Do</h3>
  <ol>${bullets(todo_list)}</ol>

  <h3>Claude Code Tip of the Day</h3>
  <p>${esc(claude_tip)}</p>
</div>`;
}

async function sendViaResend(html) {
  const resp = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: BRIEFING_FROM,
      to: [BRIEFING_TO],
      subject: `Rung Daily Briefing — ${today}`,
      html,
    }),
  });
  const body = await resp.text();
  if (!resp.ok) throw new Error(`Resend ${resp.status}: ${body}`);
  return JSON.parse(body);
}

(async () => {
  const ctx = await gather();
  const brief = await composeDynamic(ctx);
  const html = buildHtml(brief);
  const { id } = await sendViaResend(html);
  console.log(`Sent: ${id}`);
})().catch(err => {
  console.error(err);
  process.exit(1);
});
