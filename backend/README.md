# Skill Tree API Backend

Cloudflare Worker backend that proxies requests to Google Gemini API with rate limiting.

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Create Cloudflare Account

Sign up at https://cloudflare.com (free tier)

### 3. Login to Wrangler

```bash
npx wrangler login
```

### 4. Create KV Namespace

```bash
# Create production namespace
npx wrangler kv:namespace create RATE_LIMIT

# Create preview namespace for development
npx wrangler kv:namespace create RATE_LIMIT --preview
```

Update `wrangler.toml` with the returned IDs:
```toml
[[kv_namespaces]]
binding = "RATE_LIMIT"
id = "YOUR_PRODUCTION_KV_ID"
preview_id = "YOUR_PREVIEW_KV_ID"
```

### 5. Set Gemini API Key Secret

```bash
npx wrangler secret put GEMINI_API_KEY
# Enter your Gemini API key when prompted
```

### 6. Deploy

```bash
npm run deploy
```

Your worker will be available at: `https://skill-tree-api.<your-subdomain>.workers.dev`

## Development

Run locally:
```bash
npm run dev
```

View logs:
```bash
npm run tail
```

## API Endpoints

All endpoints require `X-Device-ID` header (UUID v4 format).

### POST /api/skill-tree
Generate a skill tree for a career goal.

**Request:**
```json
{
  "goal": "software engineer"
}
```

### POST /api/skill-proposal
Get skill proposals based on user's background.

**Request:**
```json
{
  "goal": "software engineer",
  "currentSkillsText": "I have 2 years of JavaScript experience..."
}
```

### POST /api/gap-analysis
Perform gap analysis and create action plan.

**Request:**
```json
{
  "goal": "software engineer",
  "currentSkills": "I have 2 years of JavaScript experience...",
  "checkedSkills": [{"name": "JavaScript"}, {"name": "HTML/CSS"}]
}
```

### POST /api/education-resources
Get learning resources for a plan item.

**Request:**
```json
{
  "item": {
    "name": "Learn TypeScript",
    "type": "skill",
    "description": "Master TypeScript for type-safe JavaScript",
    "fields": {"tag": "other"}
  }
}
```

## Rate Limits

| Limit | Value |
|-------|-------|
| Per device/minute | 5 requests |
| Per device/hour | 30 requests |
| Per device/day | 100 requests |
| Burst (5 seconds) | 3 requests |

Rate limit errors return HTTP 429 with `Retry-After` header.

## Cost

Free tier includes:
- 100,000 requests/day
- 10ms CPU time per request
- 1 GB KV storage

This is more than enough for a solo developer app.
