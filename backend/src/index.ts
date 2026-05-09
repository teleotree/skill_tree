/**
 * Skill Tree API - Cloudflare Worker
 *
 * Proxies requests to Google Gemini API with rate limiting and device validation.
 */

export interface Env {
  GEMINI_API_KEY: string;
  RATE_LIMIT: KVNamespace;
  ENVIRONMENT: string;
}

// Rate limit configuration
const RATE_LIMITS = {
  perMinute: 5,
  perHour: 30,
  perDay: 100,
  burstPerFiveSeconds: 3,
};

// UUID v4 regex pattern
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// Gemini API endpoint
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

interface RateLimitData {
  minuteCount: number;
  minuteResetAt: number;
  hourCount: number;
  hourResetAt: number;
  dayCount: number;
  dayResetAt: number;
  burstTimestamps: number[];
}

async function getRateLimitData(kv: KVNamespace, deviceId: string): Promise<RateLimitData> {
  const data = await kv.get(`rate:${deviceId}`, 'json') as RateLimitData | null;
  const now = Date.now();

  if (!data) {
    return {
      minuteCount: 0,
      minuteResetAt: now + 60000,
      hourCount: 0,
      hourResetAt: now + 3600000,
      dayCount: 0,
      dayResetAt: now + 86400000,
      burstTimestamps: [],
    };
  }

  // Reset counters if windows have passed
  if (now >= data.minuteResetAt) {
    data.minuteCount = 0;
    data.minuteResetAt = now + 60000;
  }
  if (now >= data.hourResetAt) {
    data.hourCount = 0;
    data.hourResetAt = now + 3600000;
  }
  if (now >= data.dayResetAt) {
    data.dayCount = 0;
    data.dayResetAt = now + 86400000;
  }

  // Clean up old burst timestamps (older than 5 seconds)
  data.burstTimestamps = data.burstTimestamps.filter(ts => now - ts < 5000);

  return data;
}

async function saveRateLimitData(kv: KVNamespace, deviceId: string, data: RateLimitData): Promise<void> {
  // Store with TTL of 1 day (86400 seconds)
  await kv.put(`rate:${deviceId}`, JSON.stringify(data), { expirationTtl: 86400 });
}

function checkRateLimit(data: RateLimitData): { allowed: boolean; retryAfter?: number; reason?: string } {
  const now = Date.now();

  // Check burst limit (3 requests per 5 seconds)
  if (data.burstTimestamps.length >= RATE_LIMITS.burstPerFiveSeconds) {
    const oldestBurst = Math.min(...data.burstTimestamps);
    const retryAfter = Math.ceil((oldestBurst + 5000 - now) / 1000);
    return { allowed: false, retryAfter, reason: 'burst' };
  }

  // Check per-minute limit
  if (data.minuteCount >= RATE_LIMITS.perMinute) {
    const retryAfter = Math.ceil((data.minuteResetAt - now) / 1000);
    return { allowed: false, retryAfter, reason: 'minute' };
  }

  // Check per-hour limit
  if (data.hourCount >= RATE_LIMITS.perHour) {
    const retryAfter = Math.ceil((data.hourResetAt - now) / 1000);
    return { allowed: false, retryAfter, reason: 'hour' };
  }

  // Check per-day limit
  if (data.dayCount >= RATE_LIMITS.perDay) {
    const retryAfter = Math.ceil((data.dayResetAt - now) / 1000);
    return { allowed: false, retryAfter, reason: 'day' };
  }

  return { allowed: true };
}

function incrementRateLimits(data: RateLimitData): void {
  const now = Date.now();
  data.minuteCount++;
  data.hourCount++;
  data.dayCount++;
  data.burstTimestamps.push(now);
}

function corsHeaders(): HeadersInit {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Device-ID',
  };
}

function jsonResponse(data: object, status = 200, headers: HeadersInit = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
      ...headers,
    },
  });
}

function errorResponse(message: string, status = 400, headers: HeadersInit = {}): Response {
  return jsonResponse({ error: message }, status, headers);
}

async function logRequest(kv: KVNamespace, deviceId: string, endpoint: string, status: number): Promise<void> {
  const logKey = `log:${Date.now()}:${deviceId}`;
  const logData = {
    deviceId,
    endpoint,
    status,
    timestamp: new Date().toISOString(),
  };
  // Store logs with 7-day TTL
  await kv.put(logKey, JSON.stringify(logData), { expirationTtl: 604800 });
}

// Endpoint handlers
async function handleSkillTree(body: any, apiKey: string): Promise<Response> {
  const { goal } = body;

  if (!goal || typeof goal !== 'string') {
    return errorResponse('Missing or invalid "goal" parameter');
  }

  const prompt = `You are an expert career advisor and curriculum designer. I will give you a job or skill that someone wants to learn.

Return a comprehensive overview with the following sections:

## 1. Summary
Provide a detailed "summary" object with these fields (each should be 2-4 sentences):
- "narrative": What do people who achieve this goal actually do? Describe the role/skill in practice.
- "core_competencies": What are the most important aspects and responsibilities of this role/skill?
- "considerations": What should someone think about when deciding whether to pursue this?
- "market_outlook": How competitive is the field? What's the job market and growth outlook?
- "compensation": What are typical salary ranges and earning potential at different levels?
- "challenges": What are the main difficulties, obstacles, and downsides?
- "benefits": What are the rewards, advantages, and fulfilling aspects?
- "career_path": What's the typical progression? Where do people come from and where do they go?
- "day_in_life": What does a typical day or week look like? Give concrete examples of activities.
- "industries": Which industry sectors and company types commonly need this role/skill?
- "work_style": What's the remote work potential, collaboration level, autonomy, and work-life balance?
- "barrier_to_entry": How hard is it to break in? What's the typical ramp-up time for newcomers?

## 2. Education
Return an "education" field: a list of education and certification requirements.

**For each required degree (Bachelor's, Master's, Doctorate, etc.), include a separate entry in the order they must be obtained. Assume high school is already completed.**

**For every certification referenced in the skills, ensure it is also listed in the education array.**

Each education/certification should include:
- "name": the name of the degree or certification
- "description": a one-sentence summary of what it is and why it matters
- "years": the typical number of years required
- "links": a list of authoritative websites to learn more
- "prerequisites": a brief note on any significant prerequisites
- "type": either "degree" or "certification"
- "options": a list of alternative options, each with name, description, years, links, prerequisites

## 3. Experience
Return an "experience" field: a list of experience areas required. Each should include:
- "title": the name of the experience area
- "description": a one-sentence summary of the experience and why it matters
- "years_required": the typical number of years required in this area
- "breakdown": a list of bullet points describing specific experiences or milestones

## 4. Skills
Return a "skills" field: a hierarchical, ordered list of skills required. Each skill should include:
- "name": the skill name
- "description": a one-sentence summary of what the skill is and why it matters
- "resources": a list of recommended resources (each with "title" and "url")
- "subskills": a list of subskills (with the same structure), ordered by learning sequence
- "tag": either "degree", "certification", "experience", or "other"
- "education_name": if tag is "degree" or "certification", the exact name from the education list. Omit otherwise.

Return your response as a JSON object with this structure:
{
  "goal": "<the original goal>",
  "description": "<one-sentence summary of the goal>",
  "summary": {
    "narrative": "...",
    "core_competencies": "...",
    "considerations": "...",
    "market_outlook": "...",
    "compensation": "...",
    "challenges": "...",
    "benefits": "...",
    "career_path": "...",
    "day_in_life": "...",
    "industries": "...",
    "work_style": "...",
    "barrier_to_entry": "..."
  },
  "education": [ ... ],
  "experience": [ ... ],
  "skills": [ ... ]
}

Only return valid JSON. Do not include any explanations or extra text.

Goal: ${goal}`;

  return await callGemini(prompt, apiKey, 65536);
}

async function handleSkillProposal(body: any, apiKey: string): Promise<Response> {
  const { goal, currentSkillsText } = body;

  if (!goal || typeof goal !== 'string') {
    return errorResponse('Missing or invalid "goal" parameter');
  }
  if (!currentSkillsText || typeof currentSkillsText !== 'string') {
    return errorResponse('Missing or invalid "currentSkillsText" parameter');
  }

  const prompt = `You are an expert career advisor. A user wants to achieve a career goal and has described their background. Based on their description, propose a list of skills needed for the goal and indicate which ones they likely already have.

Target career/goal: ${goal}

User's self-described background:
${currentSkillsText}

Return a JSON array of skills with this structure:
[
  {
    "name": "<skill name>",
    "description": "<one sentence explaining what this skill is and why it matters for the goal>",
    "category": "<category like 'Programming', 'Communication', 'Domain Knowledge', 'Tools', etc.>",
    "level": <1 for beginner/foundational, 2 for intermediate, 3 for advanced/specialized>,
    "completed": <true if the user likely already has this skill based on their description, false otherwise>
  }
]

Include 10-20 skills covering the main requirements for the goal. Order skills within each category from beginner (level 1) to advanced (level 3). Be generous in marking skills as completed if the user's description suggests relevant experience.

Only return valid JSON. Do not include any explanations or extra text.`;

  return await callGemini(prompt, apiKey);
}

async function handleGapAnalysis(body: any, apiKey: string): Promise<Response> {
  const { goal, currentSkills, checkedSkills } = body;

  if (!goal || typeof goal !== 'string') {
    return errorResponse('Missing or invalid "goal" parameter');
  }
  if (!currentSkills || typeof currentSkills !== 'string') {
    return errorResponse('Missing or invalid "currentSkills" parameter');
  }

  const checkedSection = Array.isArray(checkedSkills) && checkedSkills.length > 0
    ? `\nSkills the user already has (from career exploration):\n${checkedSkills.map((s: any) => `- ${s.name}`).join('\n')}`
    : '';

  const prompt = `You are an expert career advisor. A user wants to achieve a career goal and has described their current skills. Perform a gap analysis and return a prioritized action plan.

Target career/goal: ${goal}

User's self-described current skills and experience:
${currentSkills}
${checkedSection}

Based on the gap between where they are and where they need to be, return a JSON object with this structure:
{
  "goal": "<the target goal>",
  "items": [
    {
      "type": "education" | "experience" | "skill",
      "name": "<action item name>",
      "description": "<what they need to do and why>",
      "priority": "high" | "medium" | "low",
      "fields": {
        "tag": "degree" | "certification" | "experience" | "other"
      }
    }
  ]
}

Order items by recommended sequence (what to do first). Include 5-15 items covering the most important gaps. Each item should be actionable.

Only return valid JSON. Do not include any explanations or extra text.`;

  return await callGemini(prompt, apiKey);
}

async function handleEducationResources(body: any, apiKey: string): Promise<Response> {
  const { item } = body;

  if (!item || typeof item !== 'object') {
    return errorResponse('Missing or invalid "item" parameter');
  }

  const { name, type, description, fields } = item;

  const prompt = `You are an expert career advisor. Given the following plan item, recommend learning resources.

Item name: ${name || 'Unknown'}
Item type: ${type || 'skill'}
Item description: ${description || 'No description'}
Additional fields: ${JSON.stringify(fields || {})}

Return a JSON array of resources, each with:
- "title": the resource name
- "url": a valid URL to the resource
- "description": a one-sentence description of what the resource offers

Only return valid JSON. Do not include any explanations or extra text.`;

  return await callGemini(prompt, apiKey);
}

async function callGemini(prompt: string, apiKey: string, maxOutputTokens = 8192): Promise<Response> {
  const requestBody = {
    contents: [{ parts: [{ text: prompt }] }],
    generationConfig: { maxOutputTokens },
  };

  const response = await fetch(`${GEMINI_API_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(requestBody),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error(`Gemini API error: ${response.status} ${errorText}`);

    if (response.status === 429) {
      return errorResponse('AI service is busy. Please try again in a moment.', 503);
    }
    if (response.status === 503) {
      return errorResponse('AI service is temporarily unavailable. Please try again.', 503);
    }

    return errorResponse('AI service error. Please try again.', 502);
  }

  const data = await response.json() as any;
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

  if (!text) {
    return errorResponse('No response from AI service.', 502);
  }

  // Clean up response (remove markdown code blocks if present)
  let cleaned = text.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.substring(cleaned.indexOf('\n') + 1);
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.lastIndexOf('```')).trim();
    }
  }

  // Validate JSON
  try {
    JSON.parse(cleaned);
  } catch (e) {
    console.error('Failed to parse Gemini response as JSON:', e);
    return errorResponse('Invalid response from AI service.', 502);
  }

  return new Response(cleaned, {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(),
    },
  });
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    // Only allow POST
    if (request.method !== 'POST') {
      return errorResponse('Method not allowed', 405);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Validate device ID
    const deviceId = request.headers.get('X-Device-ID');
    if (!deviceId || !UUID_REGEX.test(deviceId)) {
      return errorResponse('Invalid or missing X-Device-ID header', 401);
    }

    // Check rate limits
    const rateLimitData = await getRateLimitData(env.RATE_LIMIT, deviceId);
    const rateLimitResult = checkRateLimit(rateLimitData);

    if (!rateLimitResult.allowed) {
      const retryAfter = rateLimitResult.retryAfter || 60;
      let message = 'Rate limit exceeded. ';

      switch (rateLimitResult.reason) {
        case 'burst':
          message += 'Please slow down.';
          break;
        case 'minute':
          message += `Please wait ${retryAfter} seconds.`;
          break;
        case 'hour':
          message += `Hourly limit reached. Try again in ${Math.ceil(retryAfter / 60)} minutes.`;
          break;
        case 'day':
          message += `Daily limit reached. Try again tomorrow.`;
          break;
      }

      await logRequest(env.RATE_LIMIT, deviceId, path, 429);
      return errorResponse(message, 429, { 'Retry-After': String(retryAfter) });
    }

    // Parse request body
    let body: any;
    try {
      body = await request.json();
    } catch (e) {
      return errorResponse('Invalid JSON body', 400);
    }

    // Route to appropriate handler
    let response: Response;

    switch (path) {
      case '/api/skill-tree':
        response = await handleSkillTree(body, env.GEMINI_API_KEY);
        break;
      case '/api/skill-proposal':
        response = await handleSkillProposal(body, env.GEMINI_API_KEY);
        break;
      case '/api/gap-analysis':
        response = await handleGapAnalysis(body, env.GEMINI_API_KEY);
        break;
      case '/api/education-resources':
        response = await handleEducationResources(body, env.GEMINI_API_KEY);
        break;
      default:
        return errorResponse('Not found', 404);
    }

    // Only increment rate limits on successful API calls
    if (response.status === 200) {
      incrementRateLimits(rateLimitData);
      await saveRateLimitData(env.RATE_LIMIT, deviceId, rateLimitData);
    }

    // Log request
    ctx.waitUntil(logRequest(env.RATE_LIMIT, deviceId, path, response.status));

    return response;
  },
};
