#!/usr/bin/env bash
# rung-new-client.sh — scaffold a new Rung client site + server

set -e

# ── One-time config (set this once) ──────────────
NOTION_PARENT_PAGE_ID="PASTE_YOUR_NOTION_PAGE_ID_HERE"

if [[ "$NOTION_PARENT_PAGE_ID" == "PASTE_YOUR_NOTION_PAGE_ID_HERE" ]]; then
  echo "✗ NOTION_PARENT_PAGE_ID has not been set."
  echo "  Open rung-new-client.sh and replace PASTE_YOUR_NOTION_PAGE_ID_HERE"
  echo "  with your actual Notion parent page ID."
  exit 1
fi

TEMPLATE=~/Desktop/rung-website-template
SERVER_TEMPLATE=~/Desktop/rung-automation-server

# ── CLI prerequisite check ────────────────────────
MISSING_CLIS=()
command -v gh      >/dev/null 2>&1 || MISSING_CLIS+=("gh")
command -v railway >/dev/null 2>&1 || MISSING_CLIS+=("railway")
command -v netlify >/dev/null 2>&1 || MISSING_CLIS+=("netlify")

if [[ ${#MISSING_CLIS[@]} -gt 0 ]]; then
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

echo ""
echo "═══════════════════════════════════════════════"
echo "  Rung — New Client Setup"
echo "═══════════════════════════════════════════════"
echo ""

# ── Identity ─────────────────────────────────────
read -rp "Client slug (no spaces, e.g. metro-plumbing): " SLUG
read -rp "Business name (e.g. Metro Plumbing): " BIZ_NAME
BIZ_NAME="${BIZ_NAME//\"/}"
read -rp "Tagline (e.g. Fast. Reliable. Licensed.): " TAGLINE
read -rp "City, State (e.g. Chicago, IL): " CITY
read -rp "Phone (e.g. 312-555-0100): " PHONE
read -rp "Business email: " EMAIL
read -rp "Owner first name: " OWNER_NAME
read -rp "Owner phone E.164 (e.g. +13125550100): " OWNER_PHONE_E164

# ── Theme ────────────────────────────────────────
echo ""
echo "Themes:"
echo "  gold   — warm ink + amber  (plumbing, HVAC, contractors)"
echo "  navy   — deep navy + blue  (electrical, cleaning, medical)"
echo "  forest — dark green        (landscaping, roofing, painting)"
echo "  ember  — charcoal + orange (roofing, restoration, movers)"
read -rp "Theme [gold]: " THEME
THEME="${THEME:-gold}"

# ── Stats ────────────────────────────────────────
echo ""
echo "Hero stats (3 numbers shown below the tagline)"
read -rp "Stat 1 value (e.g. 15yr): " STAT1_VAL
read -rp "Stat 1 label (e.g. Experience): " STAT1_LBL
read -rp "Stat 2 value (e.g. 500+): " STAT2_VAL
read -rp "Stat 2 label (e.g. Jobs Done): " STAT2_LBL
read -rp "Stat 3 value (e.g. 24/7): " STAT3_VAL
read -rp "Stat 3 label (e.g. Available): " STAT3_LBL

# ── Services ─────────────────────────────────────
echo ""
echo "Services (3 services shown on the website)"
for i in 1 2 3; do
  echo "Service $i:"
  read -rp "  Name (e.g. Emergency Repair): " _svc_name
  read -rp "  Description (e.g. Same-day response, any time.): " _svc_desc
  _svc_name="${_svc_name//\"/}"
  _svc_desc="${_svc_desc//\"/}"
  printf -v "SVC${i}_NAME" '%s' "$_svc_name"
  printf -v "SVC${i}_DESC" '%s' "$_svc_desc"
done

# ── Testimonials ─────────────────────────────────
echo ""
echo "Testimonials"
read -rp "How many testimonials? [1]: " NUM_TESTIMONIALS
NUM_TESTIMONIALS="${NUM_TESTIMONIALS:-1}"
# Ensure numeric, then clamp to 1-3
[[ "$NUM_TESTIMONIALS" =~ ^[0-9]+$ ]] || NUM_TESTIMONIALS=1
[[ "$NUM_TESTIMONIALS" -lt 1 ]] && NUM_TESTIMONIALS=1
[[ "$NUM_TESTIMONIALS" -gt 3 ]] && NUM_TESTIMONIALS=3

TESTIMONIALS_JSON=""
for i in $(seq 1 "$NUM_TESTIMONIALS"); do
  echo "Testimonial $i:"
  read -rp "  Quote: " _t_quote
  read -rp "  Customer name: " _t_name
  read -rp "  Location [${CITY}]: " _t_loc
  _t_loc="${_t_loc:-$CITY}"
  # Strip double quotes to prevent breaking JS string literals
  _t_quote="${_t_quote//\"/}"
  _t_name="${_t_name//\"/}"
  _t_loc="${_t_loc//\"/}"
  if [[ -n "$TESTIMONIALS_JSON" ]]; then
    TESTIMONIALS_JSON="${TESTIMONIALS_JSON},"$'\n      '
  fi
  TESTIMONIALS_JSON="${TESTIMONIALS_JSON}{ quote: \"${_t_quote}\", name: \"${_t_name}\", location: \"${_t_loc}\" }"
done

# ── About ────────────────────────────────────────
echo ""
echo "About section"
read -rp "Owner story (1-2 sentences — you can edit client.js for more): " STORY

# ── SEO ──────────────────────────────────────────
echo ""
echo "SEO"
read -rp "Page title (e.g. Metro Plumbing | Emergency Plumber in Chicago, IL): " META_TITLE
read -rp "Meta description (1-2 sentences): " META_DESC

# ── Automation credentials ───────────────────────
echo ""
echo "═══════════════════════════════════════════════"
echo "  Automation Server Credentials"
echo "  (skip any you don't have yet — edit .env later)"
echo "═══════════════════════════════════════════════"
echo ""
read -rp "Notion token (secret_xxx): " NOTION_TOKEN
read -rp "Twilio Account SID (ACxxx): " TWILIO_SID
read -rp "Twilio Auth Token: " TWILIO_AUTH
read -rp "Twilio from number (E.164): " TWILIO_FROM
read -rp "Anthropic API key (sk-ant-xxx): " CLAUDE_KEY
read -rp "Gmail address: " GMAIL_USER
read -rp "Gmail App Password (xxxx xxxx xxxx xxxx): " GMAIL_PASS

# ── Copy site ────────────────────────────────────
SITE_DIR=~/Desktop/$SLUG
if [ -d "$SITE_DIR" ]; then
  echo ""
  echo "⚠  ~/Desktop/$SLUG already exists. Overwrite? [y/N] "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  rm -rf "$SITE_DIR"
fi
cp -r "$TEMPLATE" "$SITE_DIR"

# ── Write client.js ──────────────────────────────
cat > "$SITE_DIR/client.js" << CLIENTJS
const CLIENT = {
  // ── Identity ──────────────────────────────────
  name:        "${BIZ_NAME}",
  tagline:     "${TAGLINE}",
  city:        "${CITY}",
  phone:       "${PHONE}",
  email:       "${EMAIL}",
  webhookUrl:  "https://YOUR-PROJECT.railway.app/webhook", // ← update after Railway deploy

  // ── Theme ─────────────────────────────────────
  theme: "${THEME}", // gold | navy | forest | ember

  // ── Hero stats ────────────────────────────────
  stats: [
    { value: "${STAT1_VAL}", label: "${STAT1_LBL}" },
    { value: "${STAT2_VAL}", label: "${STAT2_LBL}" },
    { value: "${STAT3_VAL}", label: "${STAT3_LBL}" },
  ],

  // ── Services ──────────────────────────────────
  services: [
    { icon: "🔧", name: "${SVC1_NAME}", desc: "${SVC1_DESC}" },
    { icon: "⚙️",  name: "${SVC2_NAME}", desc: "${SVC2_DESC}" },
    { icon: "🛠️", name: "${SVC3_NAME}", desc: "${SVC3_DESC}" },
  ],

  // ── About ─────────────────────────────────────
  about: {
    ownerName: "${OWNER_NAME}",
    story:     "${STORY}",
    photo:     "photos/owner.jpg",
    badges:    ["Licensed", "Insured", "BBB Accredited"],
  },

  // ── Testimonials ──────────────────────────────
  testimonials: {
    enabled: true,
    items: [
      ${TESTIMONIALS_JSON}
    ],
  },

  // ── Gallery ───────────────────────────────────
  gallery: {
    enabled: false,
    photos:  [],
  },

  // ── Contact ───────────────────────────────────
  mapEmbedUrl: "", // ← Google Maps → Share → Embed a map → copy the src URL

  // ── SEO ───────────────────────────────────────
  meta: {
    title:       "${META_TITLE}",
    description: "${META_DESC}",
  },
};
CLIENTJS

# ── Copy server ──────────────────────────────────
SERVER_DIR=~/Desktop/${SLUG}-server
if [ -d "$SERVER_DIR" ]; then
  rm -rf "$SERVER_DIR"
fi
cp -r "$SERVER_TEMPLATE" "$SERVER_DIR"

# ── Write .env ───────────────────────────────────
cat > "$SERVER_DIR/.env" << ENVFILE
CLIENT_NAME=${BIZ_NAME}
OWNER_NAME=${OWNER_NAME}
OWNER_PHONE=${OWNER_PHONE_E164}
NOTION_TOKEN=${NOTION_TOKEN}
TWILIO_ACCOUNT_SID=${TWILIO_SID}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH}
TWILIO_FROM_NUMBER=${TWILIO_FROM}
CLAUDE_API_KEY=${CLAUDE_KEY}
GMAIL_USER=${GMAIL_USER}
GMAIL_APP_PASSWORD=${GMAIL_PASS}
ENVFILE

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

if [[ -z "$NOTION_DATABASE_ID" ]]; then
  echo "✗ Notion DB creation failed. Check NOTION_TOKEN and NOTION_PARENT_PAGE_ID."
  echo "  Response: $NOTION_RESPONSE"
  exit 1
fi

echo "NOTION_DATABASE_ID=${NOTION_DATABASE_ID}" >> "$SERVER_DIR/.env"
echo "✓ Notion database created"

# ── GitHub ───────────────────────────────────────
echo "Creating GitHub repo..."
cd "$SERVER_DIR"

# Ensure node_modules and .env are gitignored
grep -q "node_modules" .gitignore 2>/dev/null || echo "node_modules" >> .gitignore
grep -q "^\.env$"      .gitignore 2>/dev/null || echo ".env"         >> .gitignore

rm -rf .git
git init -b main
git add .
git commit -m "Initial commit — ${BIZ_NAME} automation server"
gh repo create "${SLUG}-server" --private --source=. --remote=origin --push
echo "✓ GitHub repo created: ${SLUG}-server"

cd - > /dev/null

# ── Railway ──────────────────────────────────────
echo "Deploying to Railway..."
cd "$SERVER_DIR"

railway init --name "${SLUG}-server"

# Set all env vars from .env file
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  railway variables set "${key}=${value}" || { echo "✗ Failed to set Railway variable: ${key}"; exit 1; }
done < .env

railway up

RAILWAY_OUTPUT=$(railway domain 2>&1)
RAILWAY_DOMAIN=$(echo "$RAILWAY_OUTPUT" | grep -oE '[a-zA-Z0-9-]+\.up\.railway\.app' | head -1)
RAILWAY_URL="https://${RAILWAY_DOMAIN}"

if [[ -z "$RAILWAY_DOMAIN" ]]; then
  echo "⚠  Could not capture Railway URL automatically."
  echo "   Check your Railway dashboard and update client.js webhookUrl manually."
  RAILWAY_URL="https://YOUR-PROJECT.up.railway.app"
fi

echo "✓ Deployed to Railway: ${RAILWAY_URL}"
cd - > /dev/null

# ── Patch webhookUrl ─────────────────────────────
if [[ -n "$RAILWAY_DOMAIN" ]]; then
  sed -i '' "s|https://YOUR-PROJECT.railway.app/webhook|${RAILWAY_URL}/webhook|" "$SITE_DIR/client.js"
  sed -i '' "s| // ← update after Railway deploy||" "$SITE_DIR/client.js"
  echo "✓ webhookUrl patched in client.js"
else
  echo "⚠  webhookUrl not patched — update client.js webhookUrl manually after Railway deploy"
fi

# ── Netlify ──────────────────────────────────────
echo "Deploying site to Netlify..."
NETLIFY_OUTPUT=$(netlify deploy --prod --dir="$SITE_DIR" 2>&1)
NETLIFY_URL=$(echo "$NETLIFY_OUTPUT" | grep -oE 'https://[a-z0-9-]+\.netlify\.app' | tail -1)

if [[ -z "$NETLIFY_URL" ]]; then
  echo "⚠  Could not capture Netlify URL. Check netlify.com for the live URL."
  NETLIFY_URL="(check netlify.com)"
fi

echo "✓ Site deployed: ${NETLIFY_URL}"

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
