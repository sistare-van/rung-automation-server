# Rung Client Setup — Full Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `rung-new-client.sh` so one script takes a new client from zero to fully deployed — live website on Netlify, live automation server on Railway, Notion database created, webhook wired up.

**Architecture:** Single shell script (`~/Desktop/rung-new-client.sh`) extended with new prompt sections, a Notion API call via `curl`, and CLI calls to `gh`, `railway`, and `netlify` after files are scaffolded.

**Tech Stack:** bash, Notion REST API, GitHub CLI (`gh`), Railway CLI (`railway`), Netlify CLI (`netlify`), `python3` (for JSON parsing — pre-installed on macOS)

---

## Files

- **Modify:** `~/Desktop/rung-new-client.sh` — the only file changed in this plan

---

## Task 1: Add CLI prerequisite check

Add a check at the very top of the script (after `set -e`) that verifies `gh`, `railway`, and `netlify` are installed. Exit with a clear message if any are missing.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add NOTION_PARENT_PAGE_ID constant and CLI check**

Open `~/Desktop/rung-new-client.sh`. After line 4 (`set -e`), replace:

```bash
TEMPLATE=~/Desktop/rung-website-template
SERVER_TEMPLATE=~/Desktop/rung-automation-server
```

with:

```bash
# ── One-time config (set this once) ──────────────
NOTION_PARENT_PAGE_ID="PASTE_YOUR_NOTION_PAGE_ID_HERE"

TEMPLATE=~/Desktop/rung-website-template
SERVER_TEMPLATE=~/Desktop/rung-automation-server

# ── CLI prerequisite check ────────────────────────
MISSING_CLIS=()
command -v gh      >/dev/null 2>&1 || MISSING_CLIS+=("gh")
command -v railway >/dev/null 2>&1 || MISSING_CLIS+=("railway")
command -v netlify >/dev/null 2>&1 || MISSING_CLIS+=("netlify")

if [ ${#MISSING_CLIS[@]} -gt 0 ]; then
  echo ""
  echo "✗ Missing CLIs: ${MISSING_CLIS[*]}"
  echo ""
  echo "  Install with:"
  echo "    brew install gh"
  echo "    brew install railway"
  echo "    brew install netlify-cli"
  echo ""
  echo "  Then authenticate:"
  echo "    gh auth login"
  echo "    railway login"
  echo "    netlify login"
  echo ""
  exit 1
fi
```

- [ ] **Step 2: Verify the check works**

Temporarily rename `gh` to test: run the script and confirm it exits with the missing CLI message. Then ctrl-C and undo — no need to actually rename, just confirm the block is syntactically correct:

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output (syntax OK).

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: add CLI prerequisite check and NOTION_PARENT_PAGE_ID constant"
```

---

## Task 2: Add service prompts

Add a prompt loop for 3 services after the Stats section, and update the `client.js` heredoc to use those variables.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add service prompts after the Stats block**

After the Stats section (after line `read -rp "Stat 3 label..."`), add:

```bash
# ── Services ─────────────────────────────────────
echo ""
echo "Services (3 services shown on the website)"
for i in 1 2 3; do
  echo "Service $i:"
  read -rp "  Name (e.g. Emergency Repair): " "SVC${i}_NAME"
  read -rp "  Description (e.g. Same-day response, any time.): " "SVC${i}_DESC"
done
```

- [ ] **Step 2: Update the client.js heredoc to use service variables**

In the `cat > "$SITE_DIR/client.js"` heredoc, replace the hardcoded services block:

```js
  // ── Services — EDIT THESE ─────────────────────
  services: [
    { icon: "🚨", name: "Emergency Repair",  desc: "Same-day response, any time." },
    { icon: "🔧", name: "Service 2",         desc: "Edit this description." },
    { icon: "⚙️",  name: "Service 3",         desc: "Edit this description." },
  ],
```

with:

```js
  // ── Services ──────────────────────────────────
  services: [
    { icon: "🔧", name: "${SVC1_NAME}", desc: "${SVC1_DESC}" },
    { icon: "⚙️",  name: "${SVC2_NAME}", desc: "${SVC2_DESC}" },
    { icon: "🛠️", name: "${SVC3_NAME}", desc: "${SVC3_DESC}" },
  ],
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: add service prompts to setup script"
```

---

## Task 3: Add testimonial prompts

Add a loop that prompts for 1-3 testimonials and builds the `items` array for `client.js`.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add testimonial prompts after the Services block**

After the service prompt loop, add:

```bash
# ── Testimonials ─────────────────────────────────
echo ""
echo "Testimonials"
read -rp "How many testimonials? [1]: " NUM_TESTIMONIALS
NUM_TESTIMONIALS="${NUM_TESTIMONIALS:-1}"
# Clamp to 1-3
[ "$NUM_TESTIMONIALS" -lt 1 ] && NUM_TESTIMONIALS=1
[ "$NUM_TESTIMONIALS" -gt 3 ] && NUM_TESTIMONIALS=3

TESTIMONIALS_JSON=""
for i in $(seq 1 "$NUM_TESTIMONIALS"); do
  echo "Testimonial $i:"
  read -rp "  Quote: " T_QUOTE
  read -rp "  Customer name: " T_NAME
  read -rp "  Location [${CITY}]: " T_LOC
  T_LOC="${T_LOC:-$CITY}"
  if [ -n "$TESTIMONIALS_JSON" ]; then
    TESTIMONIALS_JSON="${TESTIMONIALS_JSON},"$'\n      '
  fi
  TESTIMONIALS_JSON="${TESTIMONIALS_JSON}{ quote: \"${T_QUOTE}\", name: \"${T_NAME}\", location: \"${T_LOC}\" }"
done
```

- [ ] **Step 2: Update the client.js heredoc to use testimonials variable**

Replace the hardcoded testimonials block:

```js
  // ── Testimonials — EDIT THESE ─────────────────
  testimonials: {
    enabled: true,
    items: [
      { quote: "Paste a real customer review here.", name: "Customer Name", location: "${CITY}" },
    ],
  },
```

with:

```js
  // ── Testimonials ──────────────────────────────
  testimonials: {
    enabled: true,
    items: [
      ${TESTIMONIALS_JSON}
    ],
  },
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: add testimonial prompts to setup script"
```

---

## Task 4: Auto-create Notion database

Remove the `NOTION_DATABASE_ID` prompt. After `.env` is written, use `curl` to create the Notion DB and append the ID to `.env`.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Remove the Notion database ID prompt**

In the Automation credentials section, remove this line:

```bash
read -rp "Notion database ID: " NOTION_DB_ID
```

- [ ] **Step 2: Remove NOTION_DATABASE_ID from the .env heredoc**

In the `cat > "$SERVER_DIR/.env"` heredoc, remove:

```
NOTION_DATABASE_ID=${NOTION_DB_ID}
```

- [ ] **Step 3: Add Notion DB creation after the .env heredoc**

After the closing `ENVFILE` of the `.env` heredoc, add:

```bash
# ── Create Notion database ───────────────────────
echo ""
echo "Creating Notion database..."
NOTION_RESPONSE=$(curl -s -X POST https://api.notion.com/v1/databases \
  -H "Authorization: Bearer ${NOTION_TOKEN}" \
  -H "Notion-Version: 2022-06-28" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent\": { \"type\": \"page_id\", \"page_id\": \"${NOTION_PARENT_PAGE_ID}\" },
    \"title\": [{ \"type\": \"text\", \"text\": { \"content\": \"${BIZ_NAME} Leads\" } }],
    \"properties\": {
      \"Name\": { \"title\": {} },
      \"Email\": { \"email\": {} },
      \"Phone\": { \"phone_number\": {} },
      \"Message\": { \"rich_text\": {} },
      \"Lead Score\": { \"number\": {} },
      \"Date\": { \"date\": {} }
    }
  }")

NOTION_DATABASE_ID=$(echo "$NOTION_RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['id'].replace('-', ''))
" 2>/dev/null)

if [ -z "$NOTION_DATABASE_ID" ]; then
  echo "✗ Notion DB creation failed. Check NOTION_TOKEN and NOTION_PARENT_PAGE_ID."
  echo "  Response: $NOTION_RESPONSE"
  exit 1
fi

echo "NOTION_DATABASE_ID=${NOTION_DATABASE_ID}" >> "$SERVER_DIR/.env"
echo "✓ Notion database created"
```

- [ ] **Step 4: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 5: Set NOTION_PARENT_PAGE_ID in the script**

Open `~/Desktop/rung-new-client.sh`. At the top, replace `PASTE_YOUR_NOTION_PAGE_ID_HERE` with your actual Notion parent page ID.

To find it: open the Notion page in your browser, copy the 32-character ID from the URL (everything after the last `-` and before the `?`).

- [ ] **Step 6: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: auto-create Notion database via API"
```

---

## Task 5: Add GitHub repo creation

After server files are written, initialize a git repo and push to a new private GitHub repo.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add GitHub push block after the Notion creation block**

After the `echo "✓ Notion database created"` line, add:

```bash
# ── GitHub ───────────────────────────────────────
echo "Creating GitHub repo..."
cd "$SERVER_DIR"

# Ensure node_modules is gitignored
if ! grep -q "node_modules" .gitignore 2>/dev/null; then
  echo "node_modules" >> .gitignore
  echo ".env" >> .gitignore
fi

rm -rf .git
git init -b main
git add .
git commit -m "Initial commit — ${BIZ_NAME} automation server"
gh repo create "${SLUG}-server" --private --source=. --remote=origin --push
echo "✓ GitHub repo created: ${SLUG}-server"

cd - > /dev/null
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: auto-create GitHub repo and push server code"
```

---

## Task 6: Add Railway deploy and capture URL

Deploy the server to Railway, set env vars, and capture the live URL.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add Railway deploy block after GitHub push**

After `echo "✓ GitHub repo created: ${SLUG}-server"`, add:

```bash
# ── Railway ──────────────────────────────────────
echo "Deploying to Railway..."
cd "$SERVER_DIR"

railway init --name "${SLUG}-server"

# Set all env vars from .env file
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  railway variables set "${key}=${value}"
done < .env

railway up

RAILWAY_OUTPUT=$(railway domain 2>&1)
RAILWAY_DOMAIN=$(echo "$RAILWAY_OUTPUT" | grep -oE '[a-zA-Z0-9-]+\.up\.railway\.app' | head -1)
RAILWAY_URL="https://${RAILWAY_DOMAIN}"

if [ -z "$RAILWAY_DOMAIN" ]; then
  echo "✗ Could not capture Railway URL. Check Railway dashboard manually."
  echo "  Output: $RAILWAY_OUTPUT"
  RAILWAY_URL="https://YOUR-PROJECT.up.railway.app"
fi

echo "✓ Deployed to Railway: ${RAILWAY_URL}"
cd - > /dev/null
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: auto-deploy server to Railway and capture URL"
```

---

## Task 7: Patch webhookUrl in client.js

Update the `webhookUrl` in the generated `client.js` with the live Railway URL.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add webhookUrl patch after Railway deploy block**

After `echo "✓ Deployed to Railway: ${RAILWAY_URL}"`, add:

```bash
# ── Patch webhookUrl ─────────────────────────────
sed -i '' "s|https://YOUR-PROJECT.railway.app/webhook|${RAILWAY_URL}/webhook|" "$SITE_DIR/client.js"
sed -i '' "s| // ← update after Railway deploy||" "$SITE_DIR/client.js"
echo "✓ webhookUrl patched in client.js"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: auto-patch webhookUrl in client.js after Railway deploy"
```

---

## Task 8: Add Netlify deploy

Deploy the site folder to Netlify production and capture the live URL.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Add Netlify deploy block after webhookUrl patch**

After `echo "✓ webhookUrl patched in client.js"`, add:

```bash
# ── Netlify ──────────────────────────────────────
echo "Deploying site to Netlify..."
NETLIFY_OUTPUT=$(netlify deploy --prod --dir="$SITE_DIR" 2>&1)
NETLIFY_URL=$(echo "$NETLIFY_OUTPUT" | grep -oE 'https://[a-z0-9-]+\.netlify\.app' | tail -1)

if [ -z "$NETLIFY_URL" ]; then
  echo "✗ Could not capture Netlify URL. Check Netlify dashboard manually."
  echo "  Output: $NETLIFY_OUTPUT"
  NETLIFY_URL="(check netlify.com)"
fi

echo "✓ Site deployed: ${NETLIFY_URL}"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: auto-deploy site to Netlify"
```

---

## Task 9: Update final output

Replace the old "next steps" summary with live URLs and remaining manual TODOs.

**Files:**
- Modify: `~/Desktop/rung-new-client.sh`

- [ ] **Step 1: Replace the Done block**

Replace the entire `# ── Done` section at the bottom of the script:

```bash
# ── Done ─────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Done! Files created:"
echo ""
echo "  Site:   ~/Desktop/${SLUG}/"
echo "  Server: ~/Desktop/${SLUG}-server/"
echo ""
echo "  Next steps:"
echo "  1. Edit client.js — fill in services, testimonials, mapEmbedUrl"
echo "  2. Drop owner.jpg into photos/"
echo "  3. Preview: open ~/Desktop/${SLUG}/index.html"
echo "  4. Deploy site: drag ~/Desktop/${SLUG}/ to netlify.com"
echo "  5. Push ${SLUG}-server/ to GitHub → deploy on railway.app"
echo "  6. Copy Railway URL → paste into client.js webhookUrl → re-deploy to Netlify"
echo "  7. Submit the contact form on the live site to test end-to-end"
echo "═══════════════════════════════════════════════"
echo ""
```

with:

```bash
# ── Done ─────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ ${BIZ_NAME} is live!"
echo ""
echo "  Site:    ${NETLIFY_URL}"
echo "  Server:  ${RAILWAY_URL}"
echo "  Notion:  ${NOTION_DATABASE_ID}"
echo ""
echo "  Still to do (manual):"
echo "  1. Drop owner.jpg into ~/Desktop/${SLUG}/photos/"
echo "  2. Add Google Maps embed → client.js mapEmbedUrl"
echo "  3. Connect Notion integration to the new DB:"
echo "     Open ${BIZ_NAME} Leads in Notion → ··· → Connections → add your integration"
echo "  4. Test: submit the contact form at ${NETLIFY_URL}"
echo "═══════════════════════════════════════════════"
echo ""
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/Desktop/rung-new-client.sh
```

Expected: no output.

- [ ] **Step 3: Final commit**

```bash
cd ~/Desktop/rung-automation-server
git add ~/Desktop/rung-new-client.sh
git commit -m "feat: update final output with live URLs and remaining manual TODOs"
```

---

## Post-implementation: One-time CLI setup

Before running the updated script for the first time, install and authenticate the three CLIs:

```bash
brew install gh railway netlify-cli
gh auth login
railway login
netlify login
```

These are one-time steps — the script will skip the check once they're installed.
