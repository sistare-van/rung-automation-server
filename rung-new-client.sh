#!/usr/bin/env bash
# rung-new-client.sh — scaffold a new Rung client site + server

set -e

TEMPLATE=~/Desktop/rung-website-template
SERVER_TEMPLATE=~/Desktop/rung-automation-server
SHARED_CREDS_FILE="$HOME/.rung/shared-credentials"

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

# ── Validation helpers ───────────────────────────────────────────────────────
# Prompt until input matches the given regex. Usage: VAR=$(prompt_until "label: " "$RE" "error")
prompt_until() {
  local label="$1" regex="$2" errmsg="$3" val
  while true; do
    read -rp "$label" val </dev/tty
    if [[ "$val" =~ $regex ]]; then
      printf '%s' "$val"
      return
    fi
    printf '  ✗ %s\n' "$errmsg" >&2
  done
}

RE_SLUG='^[a-z0-9]+(-[a-z0-9]+)*$'
RE_E164='^\+[1-9][0-9]{9,14}$'
RE_EMAIL='^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
RE_DOMAIN_OPT='^$|^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'

# ── Shared credentials (loaded once; reused across all clients) ──────────────
if [[ ! -f "$SHARED_CREDS_FILE" ]]; then
  mkdir -p "$(dirname "$SHARED_CREDS_FILE")"
  chmod 700 "$(dirname "$SHARED_CREDS_FILE")"
  SEED_ENV="$SERVER_TEMPLATE/.env"
  if [[ -f "$SEED_ENV" ]]; then
    echo ""
    echo "First run — seeding $SHARED_CREDS_FILE from $SEED_ENV"
    {
      echo "# Rung shared credentials — reused across all client deployments."
      echo "# Edit this file directly to rotate keys. Never commit it to git."
      echo ""
      for key in NOTION_TOKEN TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_FROM_NUMBER CLAUDE_API_KEY RESEND_API_KEY; do
        val=$(grep "^${key}=" "$SEED_ENV" | head -1 | cut -d= -f2-)
        echo "export ${key}=${val}"
      done
      echo "export NOTION_PARENT_PAGE_ID=3442239512dd809fb57bc7e61db936d5"
    } > "$SHARED_CREDS_FILE"
    chmod 600 "$SHARED_CREDS_FILE"
    echo "✓ Saved. Edit $SHARED_CREDS_FILE to rotate any key later."
  else
    echo ""
    echo "First run — enter each shared credential once (saved to $SHARED_CREDS_FILE):"
    read -rp "  Notion integration token (ntn_/secret_): " _NOTION_TOKEN
    read -rp "  Notion parent page ID (32-char hex, no dashes): " _NOTION_PARENT_PAGE_ID
    read -rp "  Twilio Account SID (ACxxx): " _TWILIO_ACCOUNT_SID
    read -rp "  Twilio Auth Token: " _TWILIO_AUTH_TOKEN
    read -rp "  Twilio 'from' number (E.164): " _TWILIO_FROM_NUMBER
    read -rp "  Anthropic API key (sk-ant-xxx): " _CLAUDE_API_KEY
    read -rp "  Resend API key (re_xxx): " _RESEND_API_KEY
    cat > "$SHARED_CREDS_FILE" << CREDS
# Rung shared credentials — reused across all client deployments.
# Edit this file directly to rotate keys. Never commit it to git.

export NOTION_TOKEN=${_NOTION_TOKEN}
export NOTION_PARENT_PAGE_ID=${_NOTION_PARENT_PAGE_ID}
export TWILIO_ACCOUNT_SID=${_TWILIO_ACCOUNT_SID}
export TWILIO_AUTH_TOKEN=${_TWILIO_AUTH_TOKEN}
export TWILIO_FROM_NUMBER=${_TWILIO_FROM_NUMBER}
export CLAUDE_API_KEY=${_CLAUDE_API_KEY}
export RESEND_API_KEY=${_RESEND_API_KEY}
CREDS
    chmod 600 "$SHARED_CREDS_FILE"
    echo "✓ Saved to $SHARED_CREDS_FILE."
  fi
fi

# shellcheck source=/dev/null
source "$SHARED_CREDS_FILE"

for key in NOTION_TOKEN NOTION_PARENT_PAGE_ID TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_FROM_NUMBER CLAUDE_API_KEY RESEND_API_KEY; do
  if [[ -z "${!key}" ]]; then
    echo "✗ Missing $key in $SHARED_CREDS_FILE. Edit the file and rerun."
    exit 1
  fi
done

echo ""
echo "═══════════════════════════════════════════════"
echo "  Rung — New Client Setup"
echo "═══════════════════════════════════════════════"
echo ""

# ── Identity ─────────────────────────────────────
SLUG=$(prompt_until "Client slug (lowercase, hyphens only, e.g. metro-plumbing): " "$RE_SLUG" "lowercase alphanumeric with single hyphens; no spaces, underscores, or uppercase")
read -rp "Business name (e.g. Metro Plumbing): " BIZ_NAME
BIZ_NAME="${BIZ_NAME//\"/}"
read -rp "Tagline (e.g. Fast. Reliable. Licensed.): " TAGLINE
read -rp "City, State (e.g. Chicago, IL): " CITY
read -rp "Phone (e.g. 312-555-0100): " PHONE
EMAIL=$(prompt_until "Business email: " "$RE_EMAIL" "must look like name@domain.tld")
read -rp "Owner first name: " OWNER_NAME
OWNER_PHONE_E164=$(prompt_until "Owner phone E.164 (e.g. +13125550100): " "$RE_E164" "must start with + and contain 10-15 digits (no spaces, no dashes)")
CUSTOM_DOMAIN=$(prompt_until "Custom domain (optional, e.g. metroplumbing.com — ENTER to skip): " "$RE_DOMAIN_OPT" "must be a bare domain like metroplumbing.com (no https://, no slashes)")

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

# ── Copy site ────────────────────────────────────
SITE_DIR=~/Desktop/$SLUG
if [ -d "$SITE_DIR" ]; then
  echo ""
  echo "⚠  ~/Desktop/$SLUG already exists. Overwrite? [y/N] "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  rm -rf "$SITE_DIR"
fi
# Pull the latest template from GitHub so every new client inherits recent changes
if [ -d "$TEMPLATE/.git" ]; then
  (cd "$TEMPLATE" && git pull --ff-only --quiet 2>/dev/null) || echo "  (template git pull skipped — no remote or offline)"
fi
cp -r "$TEMPLATE" "$SITE_DIR"
rm -rf "$SITE_DIR/.git"   # drop the template's history; client site gets a fresh or no git later

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
  echo ""
  echo "⚠  ~/Desktop/${SLUG}-server already exists. Overwrite? [y/N] "
  read -r CONFIRM
  [[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
  rm -rf "$SERVER_DIR"
fi
cp -r "$SERVER_TEMPLATE" "$SERVER_DIR"

# ── Write .env ───────────────────────────────────
cat > "$SERVER_DIR/.env" << ENVFILE
CLIENT_NAME=${BIZ_NAME}
OWNER_NAME=${OWNER_NAME}
OWNER_PHONE=${OWNER_PHONE_E164}
OWNER_EMAIL=${EMAIL}
SMS_DRY_RUN=true
NOTION_TOKEN=${NOTION_TOKEN}
TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID}
TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN}
TWILIO_FROM_NUMBER=${TWILIO_FROM_NUMBER}
CLAUDE_API_KEY=${CLAUDE_API_KEY}
RESEND_API_KEY=${RESEND_API_KEY}
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
      \"Phone\": { \"rich_text\": {} },
      \"Message\": { \"rich_text\": {} },
      \"Service\": { \"select\": { \"options\": [] } },
      \"Status\": { \"select\": { \"options\": [{ \"name\": \"New Lead\" }] } },
      \"Source\": { \"rich_text\": {} },
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

# ── Resend sender domain (auto-register when custom domain provided) ─────────
RESEND_DNS_RECORDS=""
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  echo ""
  echo "Registering ${CUSTOM_DOMAIN} with Resend..."
  RESEND_RESP=$(curl -sS -X POST https://api.resend.com/domains \
    -H "Authorization: Bearer ${RESEND_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${CUSTOM_DOMAIN}\",\"region\":\"us-east-1\"}")

  RESEND_DNS_RECORDS=$(echo "$RESEND_RESP" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  if 'records' not in d:
    print('ERROR: ' + (d.get('message') or json.dumps(d)))
    sys.exit(0)
  for r in d['records']:
    name = r.get('name','')
    rtype = r.get('type','')
    value = r.get('value','')
    prio = r.get('priority')
    if prio is not None:
      print(f'{rtype:<5}  {name:<30}  priority {prio}  {value}')
    else:
      print(f'{rtype:<5}  {name:<30}  {value}')
except Exception as e:
  print(f'ERROR: could not parse Resend response: {e}', file=sys.stderr)
" 2>&1)

  if echo "$RESEND_DNS_RECORDS" | grep -q '^ERROR'; then
    echo "⚠  Resend domain registration failed:"
    echo "   $RESEND_DNS_RECORDS"
    echo "   Email replies will fall back to leads@rungproductions.com."
    RESEND_DNS_RECORDS=""
  else
    echo "✓ Resend domain ${CUSTOM_DOMAIN} registered — DNS records to add shown in final summary"
    echo "SENDER_DOMAIN=${CUSTOM_DOMAIN}" >> "$SERVER_DIR/.env"
  fi
fi

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

RAILWAY_NAME=$(echo "${SLUG}-server" | tr '[:upper:]' '[:lower:]')
railway init --name "$RAILWAY_NAME"

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
NETLIFY_OUTPUT=$(netlify deploy --prod --dir="$SITE_DIR" 2>&1) || true
NETLIFY_URL=$(echo "$NETLIFY_OUTPUT" | grep -oE 'https://[a-z0-9-]+\.netlify\.app' | tail -1)

if [[ -z "$NETLIFY_URL" ]]; then
  echo "⚠  Could not capture Netlify URL. Check netlify.com for the live URL."
  NETLIFY_URL="(check netlify.com)"
fi

echo "✓ Site deployed: ${NETLIFY_URL}"

# ── Netlify custom domain (auto-add if provided) ─────────────────────
if [[ -n "$CUSTOM_DOMAIN" ]]; then
  NETLIFY_SITE_ID=$(grep -o '"siteId":"[^"]*"' "$SITE_DIR/.netlify/state.json" 2>/dev/null | sed 's/"siteId":"//;s/"$//')
  if [[ -n "$NETLIFY_SITE_ID" ]]; then
    netlify api updateSite --data "{\"site_id\":\"$NETLIFY_SITE_ID\",\"body\":{\"custom_domain\":\"$CUSTOM_DOMAIN\",\"domain_aliases\":[\"www.$CUSTOM_DOMAIN\"]}}" > /dev/null 2>&1 \
      && echo "✓ Custom domain $CUSTOM_DOMAIN added in Netlify (SSL auto-provisions once DNS resolves)" \
      || echo "⚠  Could not add custom domain in Netlify — add manually at Netlify → Domain settings"
  else
    echo "⚠  Netlify site ID not found — add custom domain manually"
  fi
fi

# ── Patch ALLOWED_ORIGINS on Railway (CORS allowlist) ────────────────
if [[ -n "$NETLIFY_URL" && "$NETLIFY_URL" != "(check netlify.com)" ]]; then
  ALLOWED_ORIGINS="$NETLIFY_URL"
  if [[ -n "$CUSTOM_DOMAIN" ]]; then
    ALLOWED_ORIGINS="https://${CUSTOM_DOMAIN},https://www.${CUSTOM_DOMAIN},${ALLOWED_ORIGINS}"
  fi
  echo "ALLOWED_ORIGINS=${ALLOWED_ORIGINS}" >> "$SERVER_DIR/.env"
  cd "$SERVER_DIR"
  railway variables --set "ALLOWED_ORIGINS=${ALLOWED_ORIGINS}" --service "${RAILWAY_NAME}" > /dev/null 2>&1 \
    && echo "✓ ALLOWED_ORIGINS set on Railway: ${ALLOWED_ORIGINS}" \
    || echo "⚠  Failed to set ALLOWED_ORIGINS on Railway — set manually via dashboard"
  cd - > /dev/null
else
  echo "⚠  Skipping ALLOWED_ORIGINS patch — Netlify URL missing. CORS will block form submissions until you set it."
fi

# ── Post-deploy smoke test ───────────────────────────────────────────
echo ""
echo "Running smoke test against ${RAILWAY_URL}/webhook ..."
SMOKE_PAYLOAD=$(cat <<JSON
{"name":"Smoke Test","phone":"${OWNER_PHONE_E164}","email":"${EMAIL}","service":"smoke","message":"Automated post-deploy test — ignore"}
JSON
)
SMOKE_RESP=$(curl -sS --max-time 15 -X POST "${RAILWAY_URL}/webhook" \
  -H "Content-Type: application/json" \
  -H "Origin: ${NETLIFY_URL}" \
  -d "$SMOKE_PAYLOAD" 2>&1) || true

if echo "$SMOKE_RESP" | grep -q '"success":true'; then
  echo "✓ Webhook accepted the smoke test"
  # Give the async Notion/Email/SMS tasks a moment
  sleep 6
  cd "$SERVER_DIR"
  SMOKE_LOGS=$(railway logs --service "${RAILWAY_NAME}" 2>&1 | tail -20 || true)
  cd - > /dev/null
  for check in "NOTION success" "EMAIL success" "SMS"; do
    if echo "$SMOKE_LOGS" | grep -q "$check"; then
      echo "  ✓ $check confirmed in logs"
    else
      echo "  ⚠ $check not seen in recent logs — check Railway dashboard"
    fi
  done
else
  echo "✗ Webhook rejected smoke test:"
  echo "  $SMOKE_RESP"
fi

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
echo "  3. Test: submit the contact form at ${NETLIFY_URL}"
if [[ -n "$CUSTOM_DOMAIN" ]]; then
echo "  4. Wire ${CUSTOM_DOMAIN} DNS at the registrar (for the website):"
echo "     ALIAS  @    → apex-loadbalancer.netlify.com"
echo "     CNAME  www  → $(echo "$NETLIFY_URL" | sed 's|https://||')"
fi
if [[ -n "$RESEND_DNS_RECORDS" ]]; then
echo ""
echo "  5. Add these DNS records at ${CUSTOM_DOMAIN}'s registrar (for email sending):"
echo "$RESEND_DNS_RECORDS" | sed 's/^/       /'
echo "     Resend will auto-verify within ~15 min of DNS propagation."
echo "     Until verified, replies fall back to leads@rungproductions.com."
fi
echo "  6. Flip SMS_DRY_RUN=false on Railway once per-client A2P is approved"
echo "═══════════════════════════════════════════════"
echo ""
