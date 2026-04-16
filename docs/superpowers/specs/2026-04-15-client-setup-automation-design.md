# Rung New Client Setup — Full Automation Design

**Date:** 2026-04-15
**Status:** Approved

## Goal

Extend `rung-new-client.sh` so that running one script takes a client from zero to fully deployed — live website on Netlify, live automation server on Railway, Notion database created, webhook wired up. No manual steps after the script finishes.

---

## Section 1: New Prompts

Add two new prompt blocks to the script after the existing prompts.

### Services (3 services, prompted in a loop)
For each of 3 services:
- Service name (e.g. "Emergency Repair")
- Service description (e.g. "Same-day response, any time.")

These replace the hardcoded placeholder services in `client.js`.

### Testimonials
- Ask: "How many testimonials? [1-3]"
- For each testimonial: quote, customer name, location

These replace the single hardcoded placeholder testimonial in `client.js`.

---

## Section 2: Notion Database Auto-Creation

**What changes:** Remove the `NOTION_DATABASE_ID` prompt. Instead, auto-create a new Notion database for each client using the Notion API.

**Parent page:** A single Notion page ID where all client databases live. Hardcoded as `NOTION_PARENT_PAGE_ID` at the top of the script — set once, never prompted.

**Database schema** (matches existing server expectations):
- Name (title)
- Email (email)
- Phone (phone_number)
- Message (rich_text)
- Lead Score (number)
- Date (date)

**Output:** The created database ID is captured and written to `.env` automatically.

---

## Section 3: GitHub, Railway, and Netlify Deploy

Runs after all files are scaffolded. Steps execute in order:

### Prerequisites (one-time setup, not part of the script)
- `gh auth login` — GitHub CLI auth
- `railway login` — Railway CLI auth
- `netlify login` — Netlify CLI auth
- Install all three CLIs: `brew install gh railway netlify-cli`

### Automated steps (run every time)

1. **GitHub** — `gh repo create {slug}-server --private --source={server-dir} --push`
   - Creates a private GitHub repo and pushes the server code

2. **Railway** — inside the server directory:
   - `railway init` — creates a new Railway project linked to the repo
   - `railway variables set KEY=VALUE ...` — sets all `.env` vars in Railway
   - `railway up` — deploys (synchronous, waits for completion)
   - `railway domain` — generates and returns the `.up.railway.app` URL; captured for the next step

3. **Patch `client.js`** — replace `webhookUrl: "https://YOUR-PROJECT.railway.app/webhook"` with the real Railway URL

4. **Netlify** — `netlify deploy --prod --dir={site-dir}`
   - Deploys the site to production
   - Capture the Netlify live URL from CLI output

### Script output
At the end, print:
- Live site URL (Netlify)
- Live server URL (Railway)
- Notion database ID

---

## What Remains Manual

- Dropping `photos/owner.jpg` into the site folder (can't automate — requires the client's photo)
- Google Maps embed URL (can't automate — requires a Google Maps link from the client)
- Both are noted in the end-of-script output as remaining TODOs

---

## CLI Installation

The script will check for `gh`, `railway`, and `netlify` at startup and print a clear error with install instructions if any are missing, rather than failing mid-run.
