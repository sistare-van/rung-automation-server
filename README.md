# Rung Automation Server

Captures leads from a website form, then in parallel:
1. Creates a Notion database entry with lead info and a score
2. Sends the owner an SMS via Twilio
3. Generates a personalized reply email with Claude AI and sends it to the lead

---

## Setup

### 1. Clone the repo

```bash
git clone <repo-url> my-client-name
cd my-client-name
```

### 2. Install dependencies

```bash
npm install
```

### 3. Configure environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in every value (see **Environment Variables** below).

### 4. Run locally

```bash
npm start
```

The server starts on `http://localhost:3000` (or the port you set in `.env`).

---

## Cloning for a New Client

Every client gets their own copy of this repo. Only `.env` changes — `server.js` never has hardcoded client data.

```bash
# 1. Copy the master folder
cp -r rung-automation-server new-client-name
cd new-client-name

# 2. Fill in the new client's .env
cp .env.example .env
nano .env   # or open in your editor

# 3. Install and start
npm install && npm start
```

---

## Environment Variables

| Variable | Description |
|---|---|
| `PORT` | Port the Express server listens on. Railway sets this automatically; use `3000` locally. |
| `CLIENT_NAME` | Display name of the client business — appears in SMS alerts and email signatures. |
| `OWNER_NAME` | First name of the business owner — used in the AI email sign-off and prompt. |
| `OWNER_PHONE` | Owner's cell in E.164 format (e.g. `+15555550100`) — receives SMS lead alerts. |
| `NOTION_TOKEN` | Notion integration token from [notion.so/my-integrations](https://www.notion.so/my-integrations). |
| `NOTION_DATABASE_ID` | ID of the Notion database where new leads are saved. Copy from the database URL. |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID from [console.twilio.com](https://console.twilio.com). |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token from [console.twilio.com](https://console.twilio.com). |
| `TWILIO_FROM_NUMBER` | Twilio phone number to send SMS from, in E.164 format (e.g. `+15555550200`). |
| `CLAUDE_API_KEY` | Anthropic API key for Claude AI — generate at [console.anthropic.com](https://console.anthropic.com). |
| `GMAIL_USER` | Gmail address used to send the automated reply to the lead. |
| `GMAIL_APP_PASSWORD` | Gmail App Password (not your regular password). Generate at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords). |
| `OWNER_EMAIL` | Owner's email address (reserved for future owner notification features). |

---

## Deploying to Railway

1. Push your repo to GitHub (make sure `.env` is in `.gitignore` — it already is).
2. Go to [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**.
3. Select your repo.
4. In the Railway dashboard → **Variables**, add every key from `.env.example` with the real values.
5. Railway auto-detects `npm start` and sets `PORT` — no extra config needed.
6. Your webhook URL will be: `https://<your-app>.railway.app/webhook`

Point your website form's `action` to that URL.

---

## Testing Locally

Make sure the server is running (`npm start`), then use these curl commands:

### Health check

```bash
curl http://localhost:3000/
```

Expected response:
```json
{"status":"ok","client":"Your Client Name"}
```

---

### Valid lead (all fields)

```bash
curl -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Smith",
    "phone": "555-867-5309",
    "email": "jane@example.com",
    "service": "water heater replacement",
    "message": "My water heater stopped working this morning."
  }'
```

Expected response:
```json
{"success":true,"message":"Lead received"}
```

Server console will print `NOTION ✓`, `SMS ✓`, `EMAIL ✓` (or `✗` with an error message if a service is misconfigured).

---

### Valid lead (no message — message field is optional)

```bash
curl -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Bob Johnson",
    "phone": "555-123-4567",
    "email": "bob@example.com",
    "service": "emergency pipe burst"
  }'
```

Expected response:
```json
{"success":true,"message":"Lead received"}
```

---

### Missing required field (triggers 400 validation error)

```bash
curl -X POST http://localhost:3000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Test",
    "phone": "555-999-0000"
  }'
```

Expected response:
```json
{"success":false,"message":"Missing required fields","missing":["email","service"]}
```
# rung-automation-server
