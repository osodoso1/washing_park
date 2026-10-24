// PicklePark Real-Time Crowdsourced Sync Worker v3 (Cloudflare Workers + Durable Objects + KV)
// Powers atomic cross-device syncing for:
// 1. Live Court Occupancy, Walk-On Sides & Paddle Queue Wait Times (/wp_live_feed_v1)
//    Served by a Durable Object so every device reads the same state instantly and
//    concurrent reports are applied one at a time (KV is only an eventually-consistent mirror).
// 2. Hourly Wait-Time Analytics & City Telemetry (/wp_city_telemetry_osodoso_v1)
// 3. Washington Park Lost & Found Board (/wp_lost_and_found_v1)
// 4. Community Leaderboard (/wp_leaderboard_v1)
// 5. Community Suggestions & Feedback (/wp_feedback_v1)

import { DurableObject } from "cloudflare:workers";

// Production feed plus an isolated feed the XCTest suite writes to
const LIVE_FEED_KEYS = new Set(["wp_live_feed_v1", "wp_live_feed_test_v1"]);
const LIVE_FEED_HISTORY_LIMIT = 2;
const COURT_SIDE_STATES = ["Free", "1 Side Taken", "Both Sides Taken"];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
};

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...CORS_HEADERS,
    },
  });
}

function parseTimestampMs(val) {
  if (typeof val === "number") {
    // Swift reference date (seconds since 2001-01-01) vs Unix epoch seconds vs ms
    if (val < 1200000000) {
      return (val + 978307200) * 1000;
    }
    if (val < 10000000000) {
      return val * 1000;
    }
    return val;
  }
  if (typeof val === "string") {
    const parsed = Date.parse(val);
    if (!Number.isNaN(parsed)) return parsed;
    const num = Number(val);
    if (!Number.isNaN(num)) return parseTimestampMs(num);
  }
  return Date.now();
}

function clampInt(val, min, max, fallback) {
  const num = Math.round(Number(val));
  if (!Number.isFinite(num)) return fallback;
  return Math.min(max, Math.max(min, num));
}

function cleanString(val) {
  if (typeof val !== "string") return null;
  const trimmed = val.trim();
  return trimmed ? trimmed.slice(0, 200) : null;
}

function courtSideState(val, fallback) {
  return COURT_SIDE_STATES.includes(val) ? val : fallback;
}

function courtSideOpenCount(state) {
  if (state === "Free") return 2;
  if (state === "1 Side Taken") return 1;
  return 0;
}

// Resolves when a report actually happened, in server time.
// New clients send reportAgeSeconds (measured on one device clock, so skew-free);
// older builds send their own Unix reportTimestamp, which is capped at server "now".
function resolveReportTimestamp(incoming, serverNowSec) {
  const age = Number(incoming.reportAgeSeconds);
  if (Number.isFinite(age)) {
    return serverNowSec - Math.min(Math.max(age, 0), 86400);
  }
  const deviceTs = Number(incoming.reportTimestamp);
  if (Number.isFinite(deviceTs) && deviceTs > 1000000000) {
    return Math.min(deviceTs, serverNowSec);
  }
  return serverNowSec;
}

function historyEntryFromState(state) {
  return {
    id: `upd_${Math.round(state.reportTimestamp * 1000)}`,
    courts: state.courtsInUse ?? 4,
    extra: state.extraCourts ?? 0,
    queue: state.inQueue ?? 0,
    authorName: state.lastAuthor || "Community Player",
    extraNotes: state.extraNotes || null,
    timestamp: state.reportTimestamp,
  };
}

// Applies one incoming report to the current live state.
// A report only becomes the live state if it is at least as new as what is already live,
// so a phone that was offline or behind can never roll everyone back to stale numbers.
function mergeLiveReport(current, incoming, serverNowSec) {
  const ts = resolveReportTimestamp(incoming, serverNowSec);
  const kind = incoming.updateKind;
  const base = current || {
    courtsInUse: 4,
    extraCourts: 0,
    inQueue: 0,
    court2State: "Free",
    court3State: "Free",
  };

  let report;
  if (kind === "walkOnCourt2" || kind === "walkOnCourt3") {
    // Walk-on toggle only changes that one court; keep everything else from the live state
    const court2State = kind === "walkOnCourt2"
      ? courtSideState(incoming.court2State, base.court2State)
      : courtSideState(base.court2State, "Free");
    const court3State = kind === "walkOnCourt3"
      ? courtSideState(incoming.court3State, base.court3State)
      : courtSideState(base.court3State, "Free");
    report = {
      courtsInUse: clampInt(base.courtsInUse, 0, 4, 4),
      extraCourts: courtSideOpenCount(court2State) + courtSideOpenCount(court3State),
      inQueue: clampInt(base.inQueue, 0, 500, 0),
      lastAuthor: cleanString(incoming.lastAuthor) || "Community Player",
      extraNotes: null,
      reportTimestamp: ts,
      court2State,
      court3State,
    };
  } else {
    report = {
      courtsInUse: clampInt(incoming.courtsInUse, 0, 4, 4),
      extraCourts: clampInt(incoming.extraCourts, 0, 4, 0),
      inQueue: clampInt(incoming.inQueue, 0, 500, 0),
      lastAuthor: cleanString(incoming.lastAuthor) || "Community Player",
      extraNotes: cleanString(incoming.extraNotes),
      reportTimestamp: ts,
      court2State: courtSideState(incoming.court2State, "Free"),
      court3State: courtSideState(incoming.court3State, "Free"),
    };
  }

  // History is owned by the server; client-sent history is ignored so stale phones can't re-inject old rows
  const candidates = [historyEntryFromState(report)];
  if (current && current.reportTimestamp) {
    candidates.push(historyEntryFromState(current));
  }
  if (current && Array.isArray(current.priorUpdates)) {
    candidates.push(...current.priorUpdates);
  }
  candidates.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
  const history = [];
  for (const item of candidates) {
    if (!item || !item.timestamp) continue;
    if (!history.some((existing) => Math.abs(existing.timestamp - item.timestamp) < 0.001)) {
      history.push(item);
    }
    if (history.length >= LIVE_FEED_HISTORY_LIMIT) break;
  }

  const isNewest = !current || !current.reportTimestamp || ts >= current.reportTimestamp;
  const liveState = isNewest ? report : current;
  return { ...liveState, priorUpdates: history };
}

function liveFeedResponse(state, status = 200) {
  return jsonResponse({ ...state, serverTime: Date.now() / 1000 }, status);
}

// One Durable Object instance per feed key: strongly consistent reads, serialized writes
export class LiveFeedDO extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.state = null;
    ctx.blockConcurrencyWhile(async () => {
      this.state = (await ctx.storage.get("state")) || null;
    });
  }

  async seedFromKV(kvKey) {
    if (this.state || !this.env.PICKLEPARK_KV) return;
    const raw = await this.env.PICKLEPARK_KV.get(kvKey);
    if (raw && !this.state) {
      this.state = JSON.parse(raw);
      await this.ctx.storage.put("state", this.state);
    }
  }

  async getState(kvKey) {
    await this.seedFromKV(kvKey);
    return this.state;
  }

  async submit(kvKey, incoming) {
    await this.seedFromKV(kvKey);
    const merged = mergeLiveReport(this.state, incoming, Date.now() / 1000);
    this.state = merged;
    await this.ctx.storage.put("state", merged);
    return merged;
  }
}

async function handleLiveFeed(request, env, ctx, feedKey) {
  const kv = env.PICKLEPARK_KV;

  if (env.LIVE_FEED) {
    const stub = env.LIVE_FEED.get(env.LIVE_FEED.idFromName(feedKey));
    if (request.method === "GET") {
      const state = await stub.getState(feedKey);
      return state ? liveFeedResponse(state) : jsonResponse(null, 404);
    }
    if (request.method === "POST" || request.method === "PUT") {
      const incoming = await request.json();
      const merged = await stub.submit(feedKey, incoming || {});
      // Mirror to KV for backup / fallback readers without delaying the response
      ctx.waitUntil(kv.put(feedKey, JSON.stringify(merged)));
      return liveFeedResponse(merged);
    }
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Fallback when the Durable Object binding is unavailable: KV only
  if (request.method === "GET") {
    const raw = await kv.get(feedKey);
    return raw ? liveFeedResponse(JSON.parse(raw)) : jsonResponse(null, 404);
  }
  if (request.method === "POST" || request.method === "PUT") {
    const incoming = await request.json();
    const existingRaw = await kv.get(feedKey);
    const merged = mergeLiveReport(existingRaw ? JSON.parse(existingRaw) : null, incoming || {}, Date.now() / 1000);
    await kv.put(feedKey, JSON.stringify(merged));
    return liveFeedResponse(merged);
  }
  return jsonResponse({ error: "Method not allowed" }, 405);
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/^\/+|\/+$/g, "");
    const kv = env.PICKLEPARK_KV;

    try {
      if (path === "" || path === "health") {
        return jsonResponse({
          ok: true,
          version: "3.0",
          liveFeedStore: env.LIVE_FEED ? "durable-object" : "kv",
          service: "PicklePark Crowdsourced Sync Engine",
          timestamp: Date.now() / 1000,
        });
      }

      // -----------------------------------------------------------------------
      // 1. LIVE COURT STATUS & WAIT TIME (/wp_live_feed_v1)
      // -----------------------------------------------------------------------
      if (LIVE_FEED_KEYS.has(path)) {
        return await handleLiveFeed(request, env, ctx, path);
      }

      // -----------------------------------------------------------------------
      // 2. LOST & FOUND BOARD (/wp_lost_and_found_v1)
      // -----------------------------------------------------------------------
      if (path === "wp_lost_and_found_v1") {
        const includeEnvelope = url.searchParams.get("envelope") === "1";
        const rawStore = await kv.get("wp_lost_and_found_store_v2");
        let store = rawStore ? JSON.parse(rawStore) : { items: [], deletedIds: [] };
        if (!Array.isArray(store.items)) store.items = [];
        if (!Array.isArray(store.deletedIds)) store.deletedIds = [];

        if (request.method === "GET") {
          const deletedSet = new Set(store.deletedIds);
          const activeItems = store.items
            .filter((item) => item && item.id && !deletedSet.has(item.id))
            .sort((a, b) => parseTimestampMs(b.lostDate) - parseTimestampMs(a.lostDate));
          if (includeEnvelope) {
            return jsonResponse({ items: activeItems, deletedIds: store.deletedIds }, 200);
          }
          return jsonResponse(activeItems, 200);
        }

        if (request.method === "POST" || request.method === "PUT") {
          const body = await request.json();
          const deletedSet = new Set(store.deletedIds);
          const byId = new Map();
          for (const item of store.items) {
            if (item && item.id && !deletedSet.has(item.id)) {
              byId.set(item.id, item);
            }
          }

          const mergeSingleItem = (incomingItem) => {
            if (!incomingItem || !incomingItem.id || deletedSet.has(incomingItem.id)) return;
            const existing = byId.get(incomingItem.id);
            if (!existing) {
              byId.set(incomingItem.id, incomingItem);
            } else {
              const incUpdated = incomingItem.updatedAt ? parseTimestampMs(incomingItem.updatedAt) : 0;
              const exUpdated = existing.updatedAt ? parseTimestampMs(existing.updatedAt) : 0;
              if (
                incUpdated >= exUpdated ||
                incomingItem.status === "MARKED FOUND" ||
                incomingItem.isFlagged ||
                (incomingItem.flagCount || 0) >= (existing.flagCount || 0)
              ) {
                byId.set(incomingItem.id, incomingItem);
              }
            }
          };

          if (body && !Array.isArray(body) && body.action === "delete" && Array.isArray(body.ids)) {
            for (const delId of body.ids) {
              deletedSet.add(delId);
              byId.delete(delId);
            }
          } else if (body && !Array.isArray(body) && body.action === "upsert" && body.item) {
            const item = body.item;
            if (item && item.id) {
              deletedSet.delete(item.id);
              byId.set(item.id, item);
            }
          } else if (body && !Array.isArray(body) && body.action === "sync" && Array.isArray(body.items)) {
            for (const incomingItem of body.items) {
              mergeSingleItem(incomingItem);
            }
          } else if (Array.isArray(body)) {
            for (const incomingItem of body) {
              mergeSingleItem(incomingItem);
            }
          }

          const mergedItems = Array.from(byId.values())
            .sort((a, b) => parseTimestampMs(b.lostDate) - parseTimestampMs(a.lostDate))
            .slice(0, 80);

          const updatedStore = {
            items: mergedItems,
            deletedIds: Array.from(deletedSet).slice(-200),
          };
          await kv.put("wp_lost_and_found_store_v2", JSON.stringify(updatedStore));
          if (includeEnvelope || (body && body.action === "sync")) {
            return jsonResponse(updatedStore, 200);
          }
          return jsonResponse(mergedItems, 200);
        }
      }

      // -----------------------------------------------------------------------
      // 3. WAIT TIME ANALYTICS & CITY TELEMETRY (/wp_city_telemetry_osodoso_v1)
      // -----------------------------------------------------------------------
      if (path === "wp_city_telemetry_osodoso_v1") {
        const rawLogs = await kv.get("wp_city_telemetry_osodoso_v1");
        let existingLogs = rawLogs ? JSON.parse(rawLogs) : [];
        if (!Array.isArray(existingLogs)) existingLogs = [];

        if (request.method === "GET") {
          return jsonResponse(existingLogs, 200);
        }

        if (request.method === "POST" || request.method === "PUT") {
          const body = await request.json();
          const incomingList = Array.isArray(body) ? body : body ? [body] : [];

          const byId = new Map();
          for (const entry of existingLogs) {
            if (entry && entry.id) byId.set(entry.id, entry);
          }
          for (const entry of incomingList) {
            if (entry && entry.id) byId.set(entry.id, entry);
          }

          const merged = Array.from(byId.values())
            .sort((a, b) => parseTimestampMs(b.timestamp) - parseTimestampMs(a.timestamp))
            .slice(0, 1500);

          await kv.put("wp_city_telemetry_osodoso_v1", JSON.stringify(merged));
          return jsonResponse(merged, 200);
        }
      }

      // -----------------------------------------------------------------------
      // 4. COMMUNITY LEADERBOARD (/wp_leaderboard_v1)
      // -----------------------------------------------------------------------
      if (path === "wp_leaderboard_v1") {
        const rawUsers = await kv.get("wp_leaderboard_v1");
        let users = rawUsers ? JSON.parse(rawUsers) : [];
        if (!Array.isArray(users)) users = [];

        if (request.method === "GET") {
          return jsonResponse(users, 200);
        }

        if (request.method === "POST" || request.method === "PUT") {
          const body = await request.json();
          const incoming = Array.isArray(body) ? body : body ? [body] : [];
          const byId = new Map();
          for (const u of users) {
            if (u && u.id) byId.set(u.id, u);
          }
          for (const u of incoming) {
            if (!u || !u.id) continue;
            const prev = byId.get(u.id);
            if (!prev || (u.allTimePoints || 0) >= (prev.allTimePoints || 0) || u.name !== prev.name) {
              byId.set(u.id, { ...u, isCurrentUser: false });
            }
          }
          const merged = Array.from(byId.values())
            .sort((a, b) => (b.monthlyPoints || 0) - (a.monthlyPoints || 0))
            .slice(0, 100);
          await kv.put("wp_leaderboard_v1", JSON.stringify(merged));
          return jsonResponse(merged, 200);
        }
      }

      // -----------------------------------------------------------------------
      // 5. COMMUNITY FEEDBACK BOARD (/wp_feedback_v1)
      // -----------------------------------------------------------------------
      if (path === "wp_feedback_v1") {
        const rawFeedback = await kv.get("wp_feedback_v1");
        let items = rawFeedback ? JSON.parse(rawFeedback) : [];
        if (!Array.isArray(items)) items = [];

        if (request.method === "GET") {
          return jsonResponse(items, 200);
        }

        if (request.method === "POST" || request.method === "PUT") {
          const body = await request.json();
          if (body && body.action === "delete" && body.id) {
            items = items.filter((x) => x.id !== body.id);
          } else {
            const incoming = Array.isArray(body) ? body : body ? [body] : [];
            const byId = new Map();
            for (const x of items) {
              if (x && x.id) byId.set(x.id, x);
            }
            for (const x of incoming) {
              if (x && x.id) byId.set(x.id, x);
            }
            items = Array.from(byId.values())
              .sort((a, b) => parseTimestampMs(b.timestamp) - parseTimestampMs(a.timestamp))
              .slice(0, 100);
          }
          await kv.put("wp_feedback_v1", JSON.stringify(items));
          return jsonResponse(items, 200);
        }
      }

      return jsonResponse({ error: "Not found", path }, 404);
    } catch (err) {
      return jsonResponse({ error: String(err) }, 500);
    }
  },
};
