import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import * as path from "path";
import * as fs from "fs";

// BrainX V2 compatible types
type ContentType = "decision" | "action" | "learning" | "gotcha" | "error" | "config" | "email" | "finance" | "task" | "contact" | "project" | "url" | "github" | "secret" | "general";
type TierType = "hot" | "warm" | "cold";

interface MemoryEntry {
  id: string;
  type: ContentType;
  content: string;
  context?: string;
  tier: TierType;
  timestamp: string;
  access_count: number;
  source?: string;
  tags?: string[];
}

// Detection patterns
const PATTERNS = {
  email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
  github: /https?:\/\/(www\.)?github\.com\/[a-zA-Z0-9-]+\/[a-zA-Z0-9-._]+/g,
  githubCommit: /\b[a-f0-9]{40}\b/g,
  url: /https?:\/\/[^\s<>"{}|\\^`\[\]]+/g,
  phone: /\+?[\d\s\-\(\)]{10,}/g,
  money: /[$€£¥]\s?[\d,]+(?:\.\d{2})?|(?:USD|EUR|GBP|BTC|ETH)\s?[\d,]+/gi,
  date: /\d{4}-\d{2}-\d{2}|\d{1,2}\/\d{1,2}\/\d{2,4}|today|tomorrow|next week|deadline/gi,
  configPath: /\.?([a-zA-Z0-9_\-\/]+\.(json|yaml|yml|ts|js|env|config|mjs|cjs))/g,
  stacktrace: /at\s+[a-zA-Z$_.<>]+\s+\([^)]+\)/g,
  task: /(?:TODO|FIXME|ACTION|需要|hacer|review|check)\s*:?\s*/gi,
  apiKey: /(?:api[_-]?key|token|secret|password|auth)\s*[:=]\s*[a-zA-Z0-9_\-]{20,}/gi
};

// Category keywords for auto-typing
const CATEGORY_KEYWORDS: Record<string, { type: ContentType; tier: TierType; keywords: string[] }> = {
  task: { type: "task", tier: "warm", keywords: ["todo", "action", "task", "deadline", "reminder", "review", "check"] },
  project: { type: "project", tier: "warm", keywords: ["project", "feature", "build", "deploy", "release", "version"] },
  error: { type: "error", tier: "hot", keywords: ["error", "bug", "fix", "crash", "exception", "fail"] },
  decision: { type: "decision", tier: "warm", keywords: ["decide", "decision", "choose", "pick", "vs", "versus"] },
  learning: { type: "learning", tier: "warm", keywords: ["learn", "note", "tip", "how to", "best practice"] },
  contact: { type: "contact", tier: "warm", keywords: ["contact", "email", "phone", "@", "ceo", "founder"] },
  finance: { type: "finance", tier: "hot", keywords: ["money", "cost", "budget", "price", "invoice", "payment"] }
};

// BrainX V2 storage path - auto-detect from plugin location or env
const BRAINX_HOME = process.env.BRAINX_HOME || path.resolve(__dirname, '../../..');
const BRAINX_STORAGE = path.join(BRAINX_HOME, 'storage');

// Generate BrainX V2 compatible ID
function generateId(): string {
  const timestamp = Math.floor(Date.now() / 1000);
  const hash = Math.random().toString(36).substring(2, 10);
  return `${timestamp}-${hash}`;
}

// Format timestamp BrainX V2 style
function formatTimestamp(): string {
  const now = new Date();
  return now.toISOString().replace('T', ' ').substring(0, 19);
}

// Determine tier based on content
function determineTier(type: string, content: string): TierType {
  // Hot tier for critical items
  if (type === "error" || type === "secret" || type === "finance") return "hot";
  if (content.toLowerCase().includes("urgent") || content.toLowerCase().includes("critical")) return "hot";
  
  // Cold tier for old reference items
  if (type === "url" || type === "github") return "cold";
  
  // Default warm tier
  return "warm";
}

// Extract entities from text
function extractEntities(text: string, source: string = "telegram"): MemoryEntry[] {
  const entries: MemoryEntry[] = [];
  const seen = new Set<string>();

  const addEntry = (content: string, type: ContentType, context?: string, tags?: string[]) => {
    // Skip duplicates
    const dedupeKey = `${type}:${content.substring(0, 50)}`;
    if (seen.has(dedupeKey)) return;
    seen.add(dedupeKey);

    const tier = determineTier(type, content);
    
    entries.push({
      id: generateId(),
      type,
      content: content.trim(),
      context: context || "",
      tier,
      timestamp: formatTimestamp(),
      access_count: 0,
      source: source,
      tags: tags || []
    });
  };

  // Extract emails
  const emails = text.match(PATTERNS.email);
  emails?.forEach(e => addEntry(e, "email", "Contact email", ["contact", "email"]));

  // Extract GitHub URLs
  const githubUrls = text.match(PATTERNS.github);
  githubUrls?.forEach(u => addEntry(u, "github", "GitHub repository", ["code", "repo"]));
  
  // Extract commit SHAs
  const commits = text.match(PATTERNS.githubCommit);
  commits?.forEach(c => {
    if (!text.includes(`github.com`) || !text.includes(c)) {
      addEntry(c, "github", "Git commit SHA", ["code", "commit"]);
    }
  });

  // Extract URLs (non-GitHub)
  const urls = text.match(PATTERNS.url);
  urls?.forEach(u => {
    if (!u.includes("github.com")) addEntry(u, "url", "Reference URL", ["link", "reference"]);
  });

  // Extract money/finance
  const money = text.match(PATTERNS.money);
  money?.forEach(m => addEntry(m, "finance", "Financial information", ["money", "financial"]));

  // Extract phone numbers
  const phones = text.match(PATTERNS.phone);
  phones?.forEach(p => {
    if (p.replace(/\s/g, "").length >= 10) {
      addEntry(p, "contact", "Phone number", ["contact", "phone"]);
    }
  });

  // Extract dates
  const dates = text.match(PATTERNS.date);
  dates?.forEach(d => addEntry(d, "task", "Date/timeline reference", ["timeline", "schedule"]));

  // Extract config file references
  const configs = text.match(PATTERNS.configPath);
  configs?.forEach(c => addEntry(c, "config", "Configuration file", ["file", "config"]));

  // Extract stacktraces (mark as error/hot)
  if (text.match(PATTERNS.stacktrace)) {
    const stack = text.match(PATTERNS.stacktrace)?.slice(0, 3).join(" | ");
    addEntry(stack || "Stacktrace detected", "error", "Error stacktrace", ["debug", "error", "stacktrace"]);
  }

  // Detect and redact secrets
  const secrets = text.match(PATTERNS.apiKey);
  secrets?.forEach(() => addEntry("[REDACTED SECRET]", "secret", "API key or secret detected - redacted for security", ["security", "credential"]));

  // Categorize by keywords
  const lowerText = text.toLowerCase();
  for (const [, config] of Object.entries(CATEGORY_KEYWORDS)) {
    if (config.keywords.some(k => lowerText.includes(k))) {
      // Add a summary entry for context
      addEntry(
        text.substring(0, 200),
        config.type,
        `Auto-detected ${config.type} from conversation`,
        [config.type, "auto-detected"]
      );
      break;
    }
  }

  return entries;
}

// Save to BrainX V2 storage
function saveToBrainX(entry: MemoryEntry, logger: any): boolean {
  const storageDir = path.join(BRAINX_STORAGE, entry.tier);
  const filePath = path.join(storageDir, `${entry.id}.json`);
  
  try {
    // Ensure directory exists
    fs.mkdirSync(storageDir, { recursive: true });
    
    // Write BrainX V2 compatible JSON
    fs.writeFileSync(filePath, JSON.stringify(entry, null, 2));
    
    logger.info(`[memory-inyection] Saved to BrainX V2: ${entry.type}/${entry.tier} - ${entry.content.substring(0, 50)}`);
    return true;
  } catch (error) {
    logger.error(`[memory-inyection] Failed to save: ${error}`);
    return false;
  }
}

// Plugin definition
const memoryInyectionPlugin = {
  id: "memory-inyection",
  name: "Memory Inyection",
  description: "Auto-detect and index critical information from incoming messages to BrainX V2 storage",
  kind: "memory" as const,
  configSchema: {
    type: "object",
    additionalProperties: false,
    properties: {
      enabled: { type: "boolean", default: true },
      storage: { type: "string", default: "brainx-v2" },
      patterns: {
        type: "object",
        additionalProperties: false,
        properties: {
          email: { type: "boolean", default: true },
          githubUrl: { type: "boolean", default: true },
          commitSha: { type: "boolean", default: true },
          errorStack: { type: "boolean", default: true },
          filePaths: { type: "boolean", default: true },
          urls: { type: "boolean", default: true },
          finance: { type: "boolean", default: true },
          dates: { type: "boolean", default: true },
          secrets: { type: "boolean", default: true }
        }
      }
    }
  },
  register(api: OpenClawPluginApi) {
    api.registerHook(
      "message_received",
      async (ctx: any) => {
        const text = ctx.message?.text || "";
        if (!text || text.length < 5) return;

        // Extract entities from incoming message
        const entries = extractEntities(text, ctx.channel || "telegram");
        
        // Save each to BrainX V2
        let saved = 0;
        entries.forEach(entry => {
          if (saveToBrainX(entry, api.logger)) saved++;
        });

        if (saved > 0) {
          api.logger.info(`[memory-inyection] Auto-saved ${saved} memories to BrainX V2`);
        }
      }
    );

    api.logger.info("[memory-inyection] Plugin loaded - integrated with BrainX V2 storage");
  },
};

export default memoryInyectionPlugin;

// CommonJS compatibility
if (typeof module !== 'undefined' && module.exports) {
  module.exports = memoryInyectionPlugin;
}
