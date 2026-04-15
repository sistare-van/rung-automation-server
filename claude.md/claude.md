# Rung Master Automation Server

This is the master server. Clone this folder per client.
After cloning, only update the .env file with client values.

Tech stack: Node.js, Express
Dependencies: express, @notionhq/client, twilio,
@anthropic-ai/sdk, nodemailer, dotenv, cors, helmet

All client-specific values come from .env only.
Zero hardcoded client data in server.js.

Security: helmet middleware, rate limiting 10 req/IP/min,
validate all required fields, never log API keys

Performance: all 3 tasks run in parallel with Promise.allSettled,
10-second timeout per task, server responds within 2 seconds