// PicklePark Real-Time Crowdsourced Sync Worker v3 (Cloudflare Workers + Durable Objects + KV)
// Powers atomic cross-device syncing for:
// 1. Live Court Occupancy, Walk-On Sides & Paddle Queue Wait Times (/wp_live_feed_v1)
//    Served by a Durable Object so every device reads the same state instantly and
//    concurrent reports are applied one at a time (KV is only an eventually-consistent mirror).
// 2. Hourly Wait-Time Analytics & City Telemetry (/wp_city_telemetry_osodoso_v1)
// 3. Washington Park Lost & Found Board (/wp_lost_and_found_v1)   - Durable Object
// 4. Community Leaderboard (/wp_leaderboard_v1)                      - Durable Object
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

// ---------------------------------------------------------------------------
// Community Leaderboard + Lost & Found (Durable Object, KV mirror)
// ---------------------------------------------------------------------------

// Production stores plus isolated copies the XCTest suite writes to
const LEADERBOARD_KEYS = new Set(["wp_leaderboard_v1", "wp_leaderboard_test_v1"]);
const LOST_FOUND_KEYS = new Map([
  ["wp_lost_and_found_v1", "wp_lost_and_found_store_v2"],
  ["wp_lost_and_found_test_v1", "wp_lost_and_found_test_store_v1"],
]);
const LOST_FOUND_ITEM_LIMIT = 80;
const LOST_FOUND_TOMBSTONE_LIMIT = 200;
const LEADERBOARD_USER_LIMIT = 200;
const LEADERBOARD_AWARD_MEMORY = 100;
// Older builds saved this placeholder as the player's name, so every unnamed player looked like "you"
const PLACEHOLDER_PLAYER_NAME = "Player (You)";
const DEFAULT_LOST_FOUND_REPORTER = "Washington Park Player";

// Same "<year>-<month>" key the app uses, in park-local time
function pacificMonthKey(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/Los_Angeles",
    year: "numeric",
    month: "numeric",
  }).formatToParts(date);
  const year = parts.find((p) => p.type === "year").value;
  const month = parts.find((p) => p.type === "month").value;
  return `${year}-${Number(month)}`;
}

function defaultPlayerName(id) {
  const suffix = String(id || "").replace(/^player_/, "").slice(0, 4).toUpperCase();
  return suffix ? `Player ${suffix}` : "Player";
}

function leaderboardName(name, id) {
  const trimmed = typeof name === "string" ? name.trim() : "";
  if (!trimmed || trimmed === PLACEHOLDER_PLAYER_NAME) return defaultPlayerName(id);
  return trimmed.slice(0, 60);
}

function nonNegativeInt(val) {
  return clampInt(val, 0, 10000000, 0);
}

// Applies uploads from phones. New builds send each point award once with a unique id
// (so two devices on the same account add up instead of overwriting each other);
// totals are only used as a floor, which also covers older builds that send totals only.
function mergeLeaderboard(users, body, monthKey) {
  const incoming = Array.isArray(body) ? body : body ? [body] : [];
  const byId = new Map();
  for (const u of users) {
    if (u && u.id) byId.set(u.id, u);
  }

  for (const u of incoming) {
    if (!u || typeof u.id !== "string" || !u.id) continue;
    if (typeof u.mergedFrom === "string" && u.mergedFrom && u.mergedFrom !== u.id) {
      // Same person's old device id: its points arrive as an award below, so drop the duplicate row
      byId.delete(u.mergedFrom);
    }

    const prev = byId.get(u.id);
    const entry = prev
      ? { ...prev }
      : { id: u.id, monthlyPoints: 0, allTimePoints: 0, monthlyReports: 0, allTimeReports: 0, recentAwardIds: [] };
    if (entry.monthKey !== monthKey) {
      entry.monthlyPoints = 0;
      entry.monthlyReports = 0;
      entry.monthKey = monthKey;
    }

    const seen = new Set(entry.recentAwardIds || []);
    for (const award of Array.isArray(u.awards) ? u.awards : []) {
      if (!award || typeof award.id !== "string" || seen.has(award.id)) continue;
      seen.add(award.id);
      entry.allTimePoints += clampInt(award.allTimePoints, 0, 100000, 0);
      entry.allTimeReports += clampInt(award.allTimeReports, 0, 100000, 0);
      entry.monthlyPoints += clampInt(award.monthlyPoints, 0, 100000, 0);
      entry.monthlyReports += clampInt(award.monthlyReports, 0, 100000, 0);
    }
    entry.recentAwardIds = Array.from(seen).slice(-LEADERBOARD_AWARD_MEMORY);

    entry.allTimePoints = Math.max(entry.allTimePoints, nonNegativeInt(u.allTimePoints));
    entry.allTimeReports = Math.max(entry.allTimeReports, nonNegativeInt(u.allTimeReports));
    if (!u.monthKey || u.monthKey === monthKey) {
      entry.monthlyPoints = Math.max(entry.monthlyPoints, nonNegativeInt(u.monthlyPoints));
      entry.monthlyReports = Math.max(entry.monthlyReports, nonNegativeInt(u.monthlyReports));
    }

    entry.name = leaderboardName(u.name, u.id);
    entry.favoriteSnack = cleanString(u.favoriteSnack) || entry.favoriteSnack || "Cold Coconut Water & RXBar";
    entry.avatarEmoji = (typeof u.avatarEmoji === "string" && u.avatarEmoji.trim().slice(0, 8)) || entry.avatarEmoji || "🎾";
    entry.isCurrentUser = false;
    byId.set(u.id, entry);
  }

  return Array.from(byId.values())
    .sort((a, b) => (b.allTimePoints || 0) - (a.allTimePoints || 0))
    .slice(0, LEADERBOARD_USER_LIMIT);
}

// What every phone sees: unique names, last month's points shown as 0, internal fields stripped
function leaderboardForViewers(users, monthKey) {
  return users
    .filter((u) => u && u.id)
    .map((u) => {
      const thisMonth = (u.monthKey || monthKey) === monthKey;
      return {
        id: u.id,
        name: leaderboardName(u.name, u.id),
        monthlyPoints: thisMonth ? u.monthlyPoints || 0 : 0,
        allTimePoints: u.allTimePoints || 0,
        monthlyReports: thisMonth ? u.monthlyReports || 0 : 0,
        allTimeReports: u.allTimeReports || 0,
        isCurrentUser: false,
        favoriteSnack: u.favoriteSnack || "Cold Coconut Water & RXBar",
        avatarEmoji: u.avatarEmoji || "🎾",
      };
    })
    .sort((a, b) => b.monthlyPoints - a.monthlyPoints || b.allTimePoints - a.allTimePoints)
    .slice(0, 100);
}

function lostFoundPersonName(name) {
  if (typeof name !== "string") return name;
  return name.trim() === PLACEHOLDER_PLAYER_NAME ? DEFAULT_LOST_FOUND_REPORTER : name;
}

function normalizeLostFoundItem(item) {
  return {
    ...item,
    reporterName: lostFoundPersonName(item.reporterName) || DEFAULT_LOST_FOUND_REPORTER,
    foundByName: lostFoundPersonName(item.foundByName) ?? null,
  };
}

function itemUpdatedMs(item) {
  return parseTimestampMs(item.updatedAt || item.foundDate || item.lostDate);
}

function activeLostFoundItems(store) {
  const deletedSet = new Set(store.deletedIds);
  return store.items
    .filter((item) => item && item.id && !deletedSet.has(item.id))
    .sort((a, b) => parseTimestampMs(b.lostDate) - parseTimestampMs(a.lostDate));
}

// Applies one POST to the Lost & Found store. Newer edits win; an owner delete is permanent.
function applyLostFoundPost(store, body) {
  const deletedSet = new Set(store.deletedIds);
  const byId = new Map();
  for (const item of store.items) {
    if (item && item.id && !deletedSet.has(item.id)) byId.set(item.id, item);
  }

  const mergeSingleItem = (incomingItem) => {
    if (!incomingItem || !incomingItem.id || deletedSet.has(incomingItem.id)) return;
    const existing = byId.get(incomingItem.id);
    // Phones re-upload their saved copies; only a strictly newer copy may replace the server's
    if (!existing || itemUpdatedMs(incomingItem) > itemUpdatedMs(existing)) {
      byId.set(incomingItem.id, normalizeLostFoundItem(incomingItem));
    }
  };

  if (body && !Array.isArray(body) && body.action === "delete" && Array.isArray(body.ids)) {
    for (const delId of body.ids) {
      if (typeof delId !== "string") continue;
      deletedSet.add(delId);
      byId.delete(delId);
    }
  } else if (body && !Array.isArray(body) && body.action === "upsert" && body.item) {
    // An explicit edit replaces the item, but can't bring back one the owner deleted
    if (body.item.id && !deletedSet.has(body.item.id)) {
      byId.set(body.item.id, normalizeLostFoundItem(body.item));
    }
  } else if (body && !Array.isArray(body) && body.action === "sync" && Array.isArray(body.items)) {
    body.items.forEach(mergeSingleItem);
  } else if (Array.isArray(body)) {
    body.forEach(mergeSingleItem);
  }

  const items = Array.from(byId.values())
    .sort((a, b) => parseTimestampMs(b.lostDate) - parseTimestampMs(a.lostDate))
    .slice(0, LOST_FOUND_ITEM_LIMIT);
  return { items, deletedIds: Array.from(deletedSet).slice(-LOST_FOUND_TOMBSTONE_LIMIT) };
}

function lostFoundResponse(store, includeEnvelope, body, etag) {
  const activeItems = activeLostFoundItems(store);
  const wantsEnvelope = includeEnvelope || (body && body.action === "sync");
  const response = jsonResponse(wantsEnvelope ? { items: activeItems, deletedIds: store.deletedIds } : activeItems, 200);
  if (etag) response.headers.set("ETag", etag);
  return response;
}

// One instance per store key. Lost & Found items are stored one per key because photos make
// the whole board too big for a single Durable Object value.
export class CommunityStoreDO extends DurableObject {
  // ---- Leaderboard ----
  async loadLeaderboard(kvKey, monthKey) {
    if (this.users) return this.users;
    await this.ctx.blockConcurrencyWhile(async () => {
      if (this.users) return;
      let users = await this.ctx.storage.get("lb:users");
      if (!users) {
        const raw = this.env.PICKLEPARK_KV ? await this.env.PICKLEPARK_KV.get(kvKey) : null;
        const seeded = raw ? JSON.parse(raw) : [];
        // Rows saved before monthly tracking existed are from the current month
        users = (Array.isArray(seeded) ? seeded : []).map((u) => ({ ...u, monthKey: u.monthKey || monthKey }));
        await this.ctx.storage.put("lb:users", users);
      }
      this.users = users;
    });
    return this.users;
  }

  async leaderboardGet(kvKey, monthKey) {
    return leaderboardForViewers(await this.loadLeaderboard(kvKey, monthKey), monthKey);
  }

  async leaderboardPost(kvKey, body, monthKey) {
    const users = mergeLeaderboard(await this.loadLeaderboard(kvKey, monthKey), body, monthKey);
    this.users = users;
    await this.ctx.storage.put("lb:users", users);
    return { users: leaderboardForViewers(users, monthKey), stored: users };
  }

  // ---- Lost & Found ----
  async loadLostFound(kvStoreKey) {
    if (this.lostFound) return this.lostFound;
    await this.ctx.blockConcurrencyWhile(async () => {
      if (this.lostFound) return;
      const seeded = await this.ctx.storage.get("lf:seeded");
      if (!seeded) {
        const raw = this.env.PICKLEPARK_KV ? await this.env.PICKLEPARK_KV.get(kvStoreKey) : null;
        const parsed = raw ? JSON.parse(raw) : {};
        const items = (Array.isArray(parsed.items) ? parsed.items : []).filter((i) => i && i.id).map(normalizeLostFoundItem);
        const deletedIds = Array.isArray(parsed.deletedIds) ? parsed.deletedIds : [];
        for (const item of items) await this.ctx.storage.put(`lf:item:${item.id}`, item);
        await this.ctx.storage.put("lf:deleted", deletedIds);
        await this.ctx.storage.put("lf:version", 1);
        await this.ctx.storage.put("lf:seeded", true);
      }
      const itemMap = await this.ctx.storage.list({ prefix: "lf:item:" });
      this.lostFound = {
        store: { items: Array.from(itemMap.values()), deletedIds: (await this.ctx.storage.get("lf:deleted")) || [] },
        version: (await this.ctx.storage.get("lf:version")) || 1,
      };
    });
    return this.lostFound;
  }

  async lostFoundGet(kvStoreKey) {
    const { store, version } = await this.loadLostFound(kvStoreKey);
    return { store, version };
  }

  async lostFoundPost(kvStoreKey, body) {
    const current = await this.loadLostFound(kvStoreKey);
    const next = applyLostFoundPost(current.store, body);

    const before = new Map(current.store.items.map((i) => [i.id, JSON.stringify(i)]));
    const after = new Set();
    for (const item of next.items) {
      after.add(item.id);
      if (before.get(item.id) !== JSON.stringify(item)) {
        await this.ctx.storage.put(`lf:item:${item.id}`, item);
      }
    }
    for (const id of before.keys()) {
      if (!after.has(id)) await this.ctx.storage.delete(`lf:item:${id}`);
    }
    await this.ctx.storage.put("lf:deleted", next.deletedIds);
    const version = current.version + 1;
    await this.ctx.storage.put("lf:version", version);

    this.lostFound = { store: next, version };
    return { store: next, version };
  }
}

async function handleLeaderboard(request, env, ctx, storeKey) {
  const kv = env.PICKLEPARK_KV;
  const monthKey = pacificMonthKey();

  if (env.COMMUNITY_STORE) {
    const stub = env.COMMUNITY_STORE.get(env.COMMUNITY_STORE.idFromName(storeKey));
    if (request.method === "GET") {
      return jsonResponse(await stub.leaderboardGet(storeKey, monthKey), 200);
    }
    if (request.method === "POST" || request.method === "PUT") {
      const body = await request.json();
      const result = await stub.leaderboardPost(storeKey, body, monthKey);
      ctx.waitUntil(kv.put(storeKey, JSON.stringify(result.stored)));
      return jsonResponse(result.users, 200);
    }
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Fallback when the Durable Object binding is unavailable: KV only
  const raw = await kv.get(storeKey);
  const users = raw ? JSON.parse(raw) : [];
  if (request.method === "GET") {
    return jsonResponse(leaderboardForViewers(Array.isArray(users) ? users : [], monthKey), 200);
  }
  if (request.method === "POST" || request.method === "PUT") {
    const merged = mergeLeaderboard(Array.isArray(users) ? users : [], await request.json(), monthKey);
    await kv.put(storeKey, JSON.stringify(merged));
    return jsonResponse(leaderboardForViewers(merged, monthKey), 200);
  }
  return jsonResponse({ error: "Method not allowed" }, 405);
}

async function handleLostFound(request, env, ctx, url, path) {
  const kv = env.PICKLEPARK_KV;
  const kvStoreKey = LOST_FOUND_KEYS.get(path);
  const includeEnvelope = url.searchParams.get("envelope") === "1";

  if (env.COMMUNITY_STORE) {
    const stub = env.COMMUNITY_STORE.get(env.COMMUNITY_STORE.idFromName(path));
    if (request.method === "GET") {
      const { store, version } = await stub.lostFoundGet(kvStoreKey);
      // Lets phones skip re-downloading every photo when nothing changed
      const etag = `"lf-${version}-${includeEnvelope ? "e" : "a"}"`;
      // Cloudflare marks the tag weak (W/"...") when it compresses the response; phones echo that back
      const clientTag = (request.headers.get("If-None-Match") || "").replace(/^W\//, "");
      if (clientTag === etag) {
        return new Response(null, { status: 304, headers: { ETag: etag, ...CORS_HEADERS } });
      }
      return lostFoundResponse(store, includeEnvelope, null, etag);
    }
    if (request.method === "POST" || request.method === "PUT") {
      const body = await request.json();
      const { store } = await stub.lostFoundPost(kvStoreKey, body);
      ctx.waitUntil(kv.put(kvStoreKey, JSON.stringify(store)));
      return lostFoundResponse(store, includeEnvelope, body, null);
    }
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Fallback when the Durable Object binding is unavailable: KV only
  const rawStore = await kv.get(kvStoreKey);
  const parsed = rawStore ? JSON.parse(rawStore) : {};
  const store = {
    items: Array.isArray(parsed.items) ? parsed.items : [],
    deletedIds: Array.isArray(parsed.deletedIds) ? parsed.deletedIds : [],
  };
  if (request.method === "GET") {
    return lostFoundResponse(store, includeEnvelope, null, null);
  }
  if (request.method === "POST" || request.method === "PUT") {
    const body = await request.json();
    const next = applyLostFoundPost(store, body);
    await kv.put(kvStoreKey, JSON.stringify(next));
    return lostFoundResponse(next, includeEnvelope, body, null);
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
          version: "3.1",
          liveFeedStore: env.LIVE_FEED ? "durable-object" : "kv",
          communityStore: env.COMMUNITY_STORE ? "durable-object" : "kv",
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
      if (LOST_FOUND_KEYS.has(path)) {
        return await handleLostFound(request, env, ctx, url, path);
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
      if (LEADERBOARD_KEYS.has(path)) {
        return await handleLeaderboard(request, env, ctx, path);
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
