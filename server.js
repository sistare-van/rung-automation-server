require("dotenv").config();

const express = require("express");
const helmet = require("helmet");
const cors = require("cors");
const rateLimit = require("express-rate-limit");
const { Client: NotionClient } = require("@notionhq/client");
const twilio = require("twilio");
const Anthropic = require("@anthropic-ai/sdk");
const nodemailer = require("nodemailer");

// ── App setup ────────────────────────────────────────────────────────────────

const app = express();
const PORT = process.env.PORT || 3000;

app.set("trust proxy", 1);
app.use(helmet());
app.use(cors());
app.use(express.json());

const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10,             // 10 requests per IP per minute
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// ── Clients ──────────────────────────────────────────────────────────────────

const notion = new NotionClient({ auth: process.env.NOTION_TOKEN });

const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

const anthropic = new Anthropic({ apiKey: process.env.CLAUDE_API_KEY });

const mailer = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 465,
  secure: true,
  auth: {
    user: process.env.GMAIL_USER,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

// ── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Wraps a promise so it rejects after `ms` milliseconds.
 */
function withTimeout(promise, ms) {
  const timeout = new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`Timed out after ${ms}ms`)), ms)
  );
  return Promise.race([promise, timeout]);
}

/**
 * Returns a lead score based on the requested service keyword.
 */
function scoreService(service = "") {
  const s = service.toLowerCase();
  if (s.includes("emergency")) return 3;
  if (s.includes("water heater")) return 2;
  return 1;
}

// ── Tasks ────────────────────────────────────────────────────────────────────

async function saveToNotion({ name, phone, email, service, message }) {
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

  const properties = {
    Name: {
      title: [{ text: { content: name } }],
    },
    Phone: {
      rich_text: [{ text: { content: phone } }],
    },
    Email: {
      email: email,
    },
    Service: {
      select: { name: service },
    },
    Status: {
      select: { name: "New Lead" },
    },
    Source: {
      rich_text: [{ text: { content: "Website" } }],
    },
    Date: {
      date: { start: today },
    },
    LeadScore: {
      number: scoreService(service),
    },
  };

  if (message) {
    properties.Message = {
      rich_text: [{ text: { content: message } }],
    };
  }

  await notion.pages.create({
    parent: { database_id: process.env.NOTION_DATABASE_ID },
    properties,
  });
}

async function sendOwnerSMS({ name, phone, service, message }) {
  const lines = [
    `New lead — ${process.env.CLIENT_NAME}`,
    "",
    `Name: ${name}`,
    `Phone: ${phone}`,
    `Service: ${service}`,
  ];

  if (message) {
    lines.push(`Message: ${message}`);
  }

  lines.push("", "Call within 5 min for best close rate.");

  await twilioClient.messages.create({
    from: process.env.TWILIO_FROM_NUMBER,
    to: process.env.OWNER_PHONE,
    body: lines.join("\n"),
  });
}

async function generateAndSendEmail({ name, email, service, message }) {
  const prompt = [
    `Write a 3-4 sentence email reply for ${process.env.CLIENT_NAME}.`,
    `Owner: ${process.env.OWNER_NAME}. Lead name: ${name}.`,
    `Service: ${service}. Message: ${message || "N/A"}.`,
    `Confirm receipt. Say ${process.env.OWNER_NAME} will call within the hour.`,
    `Mention same-day availability.`,
    `Sign off as ${process.env.OWNER_NAME} from ${process.env.CLIENT_NAME}.`,
    `Email body only — no subject line.`,
  ].join(" ");

  const response = await anthropic.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 300,
    messages: [{ role: "user", content: prompt }],
  });

  const emailBody = response.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("");

  await mailer.sendMail({
    from: `"${process.env.CLIENT_NAME}" <${process.env.GMAIL_USER}>`,
    to: email,
    subject: `Re: Your ${service} request — ${process.env.CLIENT_NAME}`,
    text: emailBody,
  });
}

// ── Routes ────────────────────────────────────────────────────────────────────

app.get("/", (req, res) => {
  res.json({ status: "ok", client: process.env.CLIENT_NAME });
});

app.post("/webhook", async (req, res) => {
  const { name, phone, email, service, message } = req.body;

  // Step 1 — Validate required fields
  const required = { name, phone, email, service };
  const missing = Object.entries(required)
    .filter(([, v]) => !v || !String(v).trim())
    .map(([k]) => k);

  if (missing.length > 0) {
    return res.status(400).json({
      success: false,
      message: "Missing required fields",
      missing,
    });
  }

  // Step 2 — Run all 3 tasks in parallel with 10-second timeouts
  const TIMEOUT_MS = 10_000;
  const payload = { name, phone, email, service, message };

  async function runNotion() {
    console.log("Starting NOTION task...");
    try {
      await withTimeout(saveToNotion(payload), TIMEOUT_MS);
      console.log("NOTION success");
    } catch (error) {
      console.log("NOTION failed:", error.message, error.stack);
    }
  }

  async function runSMS() {
    console.log("Starting SMS task...");
    try {
      await withTimeout(sendOwnerSMS(payload), TIMEOUT_MS);
      console.log("SMS success");
    } catch (error) {
      console.log("SMS failed:", error.message, error.stack);
    }
  }

  async function runEmail() {
    console.log("Starting EMAIL task...");
    try {
      await withTimeout(generateAndSendEmail(payload), TIMEOUT_MS);
      console.log("EMAIL success");
    } catch (error) {
      console.log("EMAIL failed:", error.message, error.stack);
    }
  }

  await Promise.all([runNotion(), runSMS(), runEmail()]);

  // Step 4 — Always return success to the lead's browser
  return res.json({ success: true, message: "Lead received" });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Rung server running on port ${PORT} — client: ${process.env.CLIENT_NAME}`);
  const token = process.env.NOTION_TOKEN;
  console.log(`NOTION_TOKEN (first 10 chars): ${token ? token.slice(0, 10) : "NOT SET"}`);
});
