#!/usr/bin/env bash
# rung-new-client.sh — scaffold a new Rung client site + server

set -e

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

echo ""
echo "═══════════════════════════════════════════════"
echo "  Rung — New Client Setup"
echo "═══════════════════════════════════════════════"
echo ""

# ── Identity ─────────────────────────────────────
read -rp "Client slug (no spaces, e.g. metro-plumbing): " SLUG
read -rp "Business name (e.g. Metro Plumbing): " BIZ_NAME
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
read -rp "Notion database ID: " NOTION_DB_ID
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

  // ── Services — EDIT THESE ─────────────────────
  services: [
    { icon: "🚨", name: "Emergency Repair",  desc: "Same-day response, any time." },
    { icon: "🔧", name: "Service 2",         desc: "Edit this description." },
    { icon: "⚙️",  name: "Service 3",         desc: "Edit this description." },
  ],

  // ── About ─────────────────────────────────────
  about: {
    ownerName: "${OWNER_NAME}",
    story:     "${STORY}",
    photo:     "photos/owner.jpg",
    badges:    ["Licensed", "Insured", "BBB Accredited"],
  },

  // ── Testimonials — EDIT THESE ─────────────────
  testimonials: {
    enabled: true,
    items: [
      { quote: "Paste a real customer review here.", name: "Customer Name", location: "${CITY}" },
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
NOTION_DATABASE_ID=${NOTION_DB_ID}
TWILIO_ACCOUNT_SID=${TWILIO_SID}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH}
TWILIO_FROM_NUMBER=${TWILIO_FROM}
CLAUDE_API_KEY=${CLAUDE_KEY}
GMAIL_USER=${GMAIL_USER}
GMAIL_APP_PASSWORD=${GMAIL_PASS}
ENVFILE

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
