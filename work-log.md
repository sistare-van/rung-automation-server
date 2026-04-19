# Work Log

Append a dated section at the end of each Claude Code session.
The daily briefing (GitHub Actions, 9:05am ET) reads the most recent 2 entries.

Format: `## YYYY-MM-DD` header, then bullet points of what you did / decided / left open.

## 2026-04-18

### What got done today, in plain language

**Fixed the daily briefing email.** The old setup was a remote Claude agent that tried to send me a summary every morning at 9am. It broke because the system it runs on is now more locked down and won't let it send emails. Solution: moved the whole thing to GitHub Actions (a free automated task runner that lives with my code). It now runs at 9:05am ET every morning regardless of whether my Mac is on. It reads my code changes, notes I've written, and website leads from the last 24 hours, then emails me a tidy summary.

**Set up a reminder system to keep notes fresh.** Added a hook so when I close Claude Code, it reminds me to write down what I did. Also set up a recurring check-in that nudges me every hour during a work session to jot things down. All notes go into `work-log.md`, which the morning email reads.

**Got rungproductions.com fully live.**
- Wrote a Privacy Policy and a Terms & Conditions page, both using the language Twilio reviewers want to see (e.g., "we don't share SMS opt-in data with third parties").
- Hooked up the domain with the registrar (Porkbun) so rungproductions.com points at my website host (Netlify), including HTTPS and the www → non-www redirect.
- Both pages load correctly at rungproductions.com/privacy and /terms.

**Deployed Rung Productions' own lead-capture server.**
- Cloned my standard server template into its own folder.
- Pushed it to a new private GitHub repo and deployed it to Railway (the server host).
- Hooked it up to the existing "Rung Leads" Notion database so new submissions land there.
- Kept SMS in "dry-run" mode (it logs but doesn't actually send) until Twilio approves real SMS for Rung.
- Updated the website's form so it now talks to Rung's own server instead of the placeholder one it was using.

**Tidied the site.** Removed the leftover "variant previews" folder. Added a simple favicon (the little icon in the browser tab — three horizontal bars in amber/cream that read as "rungs"). Removed two nav links ("Work" and "About") that weren't pointing anywhere yet.

**Twilio A2P campaign (legal SMS approval) — figured out why it was rejected.** I'd originally described the campaign as if the business replies to the customer by text. But my actual code only texts the business owner when a new lead comes in, not the customer. Twilio saw the mismatch and rejected it. I drafted the corrected resubmission (description, sample messages, opt-in explanation) to match what the code actually does. I've already resent it.

**Hardened the server against abuse and accidents.** All these apply both to Rung Productions' server and to the template, so every future client I onboard gets them automatically:
- Rejects submissions that look suspiciously long (a bot stuffing data to burn my API budget).
- Only accepts form submissions from my own websites — a foreign website can't use my endpoint.
- Hidden "trap" field on every form that real users can't see but bots fill in — those get silently thrown out.
- Built-in defense against attackers putting malicious instructions inside the contact form hoping my AI reads them as commands. The AI now treats form contents as data only.
- Set up the hook for Cloudflare's free bot-challenge system ("Turnstile") so I can turn it on later with one env-var flip.
- Budget caps now set at Anthropic ($20/mo hard cap), Twilio ($10 and $25 alerts), Resend (free tier already caps at 3k/mo).

**End-to-end test passed.** Submitted the real contact form at rungproductions.com with my own info — email reply arrived, Notion entry created, SMS logged (dry-run). The whole chain works.

**Onboarding script upgrades for future clients.** I run `rung-new-client.sh` each time I sign a new client. Made it significantly better today:
- It now pulls my shared API keys from a single local file (`~/.rung/shared-credentials`) instead of asking me to paste each key every time.
- New clients automatically get the CORS allowlist and SMS dry-run defaults baked in.
- Validates the info I type (slug, phone, email, domain) so a typo doesn't crash the run 5 minutes in.
- Asks before overwriting an existing server folder.
- Optionally takes a custom domain and auto-wires it into Netlify.
- Runs a smoke test at the end — submits a fake lead and confirms Notion/email/SMS all fired correctly before declaring done.
- Pulls the latest site template from GitHub each run, so any improvements I make to the template always flow through.

### Still open
- Waiting on Twilio's review of the resubmitted A2P campaign. Once approved, I flip `SMS_DRY_RUN` to `false` on Railway and real lead-alert texts start sending.
- Optional: turn on Cloudflare Turnstile (extra bot defense) once I sign up for it.
- Rung Productions site still needs a proper "Work" (portfolio) section once I have 1-2 case studies and an "About" section with my story.
