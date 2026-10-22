// PicklePark Real-Time Crowdsourced Sync Worker v2 (Cloudflare Workers + KV)
// Powers atomic cross-device syncing for:
// 1. Live Court Occupancy, Walk-On Sides & Paddle Queue Wait Times (/wp_live_feed_v1)
// 2. Hourly Wait-Time Analytics & City Telemetry (/wp_city_telemetry_osodoso_v1)
// 3. Washington Park Lost & Found Board (/wp_lost_and_found_v1)
// 4. Community Leaderboard (/wp_leaderboard_v1)
// 5. Community Suggestions & Feedback (/wp_feedback_v1)

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

export default {
  async fetch(request, env) {
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
          version: "2.0",
          service: "PicklePark Crowdsourced Sync Engine",
          timestamp: Date.now() / 1000,
        });
      }

      // -----------------------------------------------------------------------
      // 1. LIVE COURT STATUS & WAIT TIME (/wp_live_feed_v1)
      // -----------------------------------------------------------------------
      if (path === "wp_live_feed_v1") {
        if (request.method === "GET") {
          const raw = await kv.get("wp_live_feed_v1");
          if (!raw) {
            return jsonResponse(null, 404);
          }
          return new Response(raw, {
            status: 200,
            headers: { "Content-Type": "application/json; charset=utf-8", ...CORS_HEADERS },
          });
        }

        if (request.method === "POST" || request.method === "PUT") {
          const incoming = await request.json();
          const existingRaw = await kv.get("wp_live_feed_v1");
          let current = existingRaw ? JSON.parse(existingRaw) : null;

          let priorUpdates = Array.isArray(incoming.priorUpdates)
            ? incoming.priorUpdates
            : current && Array.isArray(current.priorUpdates)
            ? current.priorUpdates
            : [];

          const incomingTs = incoming.reportTimestamp ?? Date.now() / 1000;

          if (
            current &&
            current.reportTimestamp &&
            Math.abs(incomingTs - current.reportTimestamp) > 2
          ) {
            const prevEntry = {
              id: `prior_${Math.round(current.reportTimestamp)}`,
              courts: current.courtsInUse ?? 4,
              extra: current.extraCourts ?? 0,
              queue: current.inQueue ?? 0,
              authorName: current.lastAuthor || "Player",
              extraNotes: current.extraNotes || null,
              timestamp: current.reportTimestamp,
            };
            priorUpdates = [
              prevEntry,
              ...priorUpdates.filter((u) => Math.abs((u.timestamp || 0) - prevEntry.timestamp) > 2),
            ].slice(0, 2);
          }

          const merged = {
            courtsInUse: incoming.courtsInUse ?? 4,
            extraCourts: incoming.extraCourts ?? 0,
            inQueue: incoming.inQueue ?? 0,
            lastAuthor: incoming.lastAuthor ?? "Community Player",
            extraNotes: incoming.extraNotes ?? null,
            reportTimestamp: incomingTs,
            court2State: incoming.court2State ?? "Free",
            court3State: incoming.court3State ?? "Free",
            priorUpdates: priorUpdates.slice(0, 2),
          };

          await kv.put("wp_live_feed_v1", JSON.stringify(merged));
          return jsonResponse(merged, 200);
        }
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
