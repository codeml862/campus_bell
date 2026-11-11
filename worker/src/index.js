// CampusBell push server on Cloudflare Workers (free plan, no billing).
// The app calls POST /notify {requestId} with its Firebase ID token.
//  - Sender + status "pending": validate, push, set delivered / failed / rejected.
//      kind "bell"    : loud ring, only top → bottom in the hierarchy
//      kind "request" : quiet "request to meet", only bottom → top
//      groupId set    : ring every member; the first to accept goes
//  - Recipient answered (accepted / declined): tell the sender; for a group,
//    also tell the other members who accepted (their ringing stops).
// Secrets (set with `wrangler secret put`): FIREBASE_SERVICE_ACCOUNT (JSON).
// Var: PROJECT_ID.

// Hierarchy, top to bottom. Must match lib/models/models.dart (Roles).
const ORDER = ["Administrator", "HOD", "Professor", "Associate Professor",
  "Assistant Professor", "Lab Assistant", "Student"];
// Older accounts were saved as "Assistant"; they are Lab Assistants.
const normal = (r) => (r === "Assistant" ? "Lab Assistant" : r);
const rank = (r) => (ORDER.includes(normal(r)) ? ORDER.indexOf(normal(r)) : ORDER.length);
const canCall = (from, to) =>
  from === "Administrator" || (from !== "Student" && rank(from) < rank(to));
const canRequest = (from, to) => from !== "Administrator" && rank(from) > rank(to);

export default {
  async fetch(req, env) {
    if (req.method !== "POST" || new URL(req.url).pathname !== "/notify") {
      return json({ error: "not found" }, 404);
    }
    try {
      const idToken = (req.headers.get("Authorization") || "").replace(/^Bearer /, "");
      const uid = await verifyIdToken(idToken, env.PROJECT_ID);
      const { requestId } = await req.json();
      if (typeof requestId !== "string" || !/^[A-Za-z0-9]{1,64}$/.test(requestId)) {
        return json({ error: "bad requestId" }, 400);
      }
      const g = new Google(env);
      const bell = await g.get(`bell_requests/${requestId}`);
      if (!bell) return json({ error: "not found" }, 404);

      if (bell.senderUid === uid && bell.status === "pending") {
        return json(bell.groupId
          ? await deliverGroup(g, requestId, bell)
          : await deliver(g, requestId, bell));
      }
      // Recipient answered: tell the sender (once).
      const isRecipient = bell.recipientUid === uid
        || (bell.recipientUids || []).includes(uid);
      if (isRecipient && ["accepted", "declined"].includes(bell.status)
          && !bell.answerSent) {
        return json(await tellSender(g, requestId, bell));
      }
      return json({ error: "nothing to do" }, 409);
    } catch (e) {
      return json({ error: String(e.message || e) }, e.status || 500);
    }
  },
};

// "on" / "off" for this user's phone right now: off when the ringer is
// silenced, or when they are in a timetable class (unless the bell is urgent).
function soundFor(user, bell) {
  const prefs = user.prefs || {};
  if (prefs.sound === false) return "off";
  if (prefs.quietInClass === false || bell.priority === "urgent") return "on";
  const offset = Number(prefs.tzOffset ?? 330); // minutes; default IST
  const local = new Date(Date.now() + offset * 60000);
  const day = local.getUTCDay() === 0 ? 7 : local.getUTCDay(); // 1 = Monday
  const now = local.getUTCHours() * 60 + local.getUTCMinutes();
  const mins = (s) => {
    const [h, m] = String(s || "0:0").split(":").map(Number);
    return (h || 0) * 60 + (m || 0);
  };
  const inClass = (user.timetable || []).some(
    (p) => Number(p.day) === day && mins(p.start) <= now && now < mins(p.end));
  return inClass ? "off" : "on";
}

function bellPayload(id, bell, sender, sound, extra = {}) {
  const request = bell.kind === "request";
  const message = String(bell.message || "").slice(0, 200);
  const priority = ["normal", "high", "urgent"].includes(bell.priority) ? bell.priority : "normal";
  const urgent = priority === "urgent" ? "URGENT · " : "";
  const title = request
    ? `${sender.name} (${sender.role}) wants to meet you`
    : `${urgent}${sender.name} (${sender.role}) is calling you`;
  return {
    data: {
      type: request ? "request" : "bell", requestId: id, senderName: sender.name,
      senderRole: sender.role, message, sound, priority,
      persistent: bell.persistent === false || request ? "false" : "true",
      ...extra,
    },
    // Android: data-only + high priority so the app shows its own notification.
    android: { priority: "HIGH", ttl: request ? "3600s" : "60s" },
    apns: {
      headers: { "apns-priority": "10", "apns-push-type": "alert" },
      payload: {
        aps: {
          alert: { title, body: message || (request ? "Can we meet?" : "Please come") },
          ...(sound === "off" ? {} : { sound: "default" }),
          ...(request ? {} : { "interruption-level": "time-sensitive" }),
        },
      },
    },
  };
}

async function deliver(g, id, bell) {
  const fail = async (status, error) => {
    await g.patch(`bell_requests/${id}`, { status, error });
    return { status, error };
  };
  const [sender, recipient] = await Promise.all([
    g.get(`users/${bell.senderUid}`),
    g.get(`users/${bell.recipientUid}`),
  ]);
  if (!sender || sender.status === "disabled") return fail("rejected", "Sender account is disabled.");
  if (!recipient || recipient.status === "disabled") return fail("rejected", "Recipient account is disabled.");
  const request = bell.kind === "request";
  if (request ? !canRequest(sender.role, recipient.role) : !canCall(sender.role, recipient.role)) {
    return fail("rejected", request
      ? "You can only send a request to someone above you."
      : `A ${sender.role} can't ring a ${recipient.role}. Send a request instead.`);
  }

  const sound = soundFor(recipient, bell);
  const sent = await pushToUser(g, bell.recipientUid, bellPayload(id, bell, sender, sound));
  if (sent === 0) {
    return fail("failed", "Recipient has no registered device. Ask them to log in to CampusBell.");
  }
  await markDelivered(g, id);
  return { status: "delivered", devices: sent };
}

async function deliverGroup(g, id, bell) {
  const fail = async (status, error) => {
    await g.patch(`bell_requests/${id}`, { status, error });
    return { status, error };
  };
  const [sender, group] = await Promise.all([
    g.get(`users/${bell.senderUid}`),
    g.get(`groups/${bell.groupId}`),
  ]);
  if (!sender || sender.status === "disabled") return fail("rejected", "Sender account is disabled.");
  if (!group) return fail("rejected", "This group no longer exists.");
  const allowed = sender.role === "Administrator"
    || (sender.role === "HOD" && group.department === sender.department)
    || group.ownerUid === bell.senderUid;
  if (!allowed) return fail("rejected", "You can't ring this group.");

  // Only real, active members below the sender, and never the sender.
  const wanted = (bell.recipientUids || []).filter(
    (u) => u !== bell.senderUid && (group.memberUids || []).includes(u));
  let devices = 0;
  for (const uid of wanted) {
    const m = await g.get(`users/${uid}`);
    if (!m || m.status === "disabled" || !canCall(sender.role, m.role)) continue;
    const sound = soundFor(m, bell);
    devices += await pushToUser(g, uid, bellPayload(id, bell, sender, sound, {
      groupId: bell.groupId, groupName: group.name || "",
    }));
  }
  if (devices === 0) {
    return fail("failed", "No one in this group has the app logged in.");
  }
  await markDelivered(g, id);
  return { status: "delivered", devices };
}

// Sets "delivered" only while still pending. A fast member may already have
// accepted while we were pushing to the others (a group can take seconds);
// overwriting that would hide who accepted and nobody would be told.
async function markDelivered(g, id) {
  const cur = await g.get(`bell_requests/${id}`);
  if (!cur || cur.status !== "pending") return;
  await g.patch(`bell_requests/${id}`, { status: "delivered", error: null, deliveredAt: new Date() });
}

async function tellSender(g, id, bell) {
  const accepted = bell.status === "accepted";
  const reason = String(bell.reason || "").slice(0, 100);
  const who = bell.claimedByName || bell.recipientName || "They";
  const what = bell.kind === "request" ? "request" : "bell";
  const title = accepted ? `${who} accepted your ${what}` : `${who} declined your ${what}`;
  const body = accepted
    ? (bell.kind === "request" ? "You can go now." : "They are on the way.")
    : (reason || "No reason given");
  const sent = await pushToUser(g, bell.senderUid, {
    data: { type: "answer", requestId: id, title, body, status: bell.status },
    android: { priority: "HIGH", ttl: "300s" },
    apns: {
      headers: { "apns-priority": "10", "apns-push-type": "alert" },
      payload: { aps: { alert: { title, body }, sound: "default" } },
    },
  });
  // Group: stop everyone else's ringing and tell them who is going.
  if (bell.groupId && accepted) {
    for (const uid of bell.recipientUids || []) {
      if (uid === bell.claimedBy) continue;
      await pushToUser(g, uid, {
        data: {
          type: "claimed", requestId: id, name: who,
          title: `${who} accepted ${bell.senderName}'s bell`,
          body: `${who} is going. You don't need to go.`,
        },
        android: { priority: "HIGH", ttl: "300s" },
        apns: {
          headers: { "apns-priority": "10", "apns-push-type": "alert" },
          payload: { aps: { alert: { title: `${who} accepted`, body: `${who} is going. You don't need to go.` } } },
        },
      });
    }
  }
  await g.patch(`bell_requests/${id}`, { answerSent: true });
  return { status: bell.status, devices: sent };
}

async function pushToUser(g, uid, message) {
  const user = await g.get(`users/${uid}`);
  const tokens = (user && user.fcmTokens) || [];
  let ok = 0;
  const dead = [];
  for (const token of tokens) {
    const r = await g.fcm({ ...message, token });
    if (r.ok) ok++;
    else if (r.status === 404 || r.status === 400) dead.push(token);
  }
  if (dead.length) {
    await g.patch(`users/${uid}`, { fcmTokens: tokens.filter((t) => !dead.includes(t)) });
  }
  return ok;
}

// ---------- Google APIs via the service account ----------

class Google {
  constructor(env) {
    this.sa = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
    this.project = env.PROJECT_ID;
    this.base = `https://firestore.googleapis.com/v1/projects/${this.project}/databases/(default)/documents`;
  }

  async token() {
    if (this._tok && this._exp > Date.now()) return this._tok;
    const now = Math.floor(Date.now() / 1000);
    const assertion = await signJwt(this.sa.private_key, {
      iss: this.sa.client_email,
      scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    });
    const r = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${assertion}`,
    });
    const j = await r.json();
    if (!j.access_token) throw new Error("Google auth failed");
    this._tok = j.access_token;
    this._exp = Date.now() + 50 * 60 * 1000;
    return this._tok;
  }

  async call(url, init = {}) {
    return fetch(url, {
      ...init,
      headers: { Authorization: `Bearer ${await this.token()}`, "Content-Type": "application/json" },
    });
  }

  async get(path) {
    const r = await this.call(`${this.base}/${path}`);
    if (r.status === 404) return null;
    if (!r.ok) throw new Error(`Firestore read failed (${r.status})`);
    return decodeDoc(await r.json());
  }

  async patch(path, data) {
    const mask = Object.keys(data).map((k) => `updateMask.fieldPaths=${k}`).join("&");
    const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, encode(v)]));
    const r = await this.call(`${this.base}/${path}?${mask}&currentDocument.exists=true`, {
      method: "PATCH",
      body: JSON.stringify({ fields }),
    });
    if (!r.ok) throw new Error(`Firestore write failed (${r.status})`);
  }

  async query(collection, filters) {
    const r = await this.call(`${this.base}:runQuery`, {
      method: "POST",
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: collection }],
          where: {
            compositeFilter: {
              op: "AND",
              filters: filters.map(([f, op, v]) => ({
                fieldFilter: { field: { fieldPath: f }, op, value: encode(v) },
              })),
            },
          },
          limit: 50,
        },
      }),
    });
    if (!r.ok) throw new Error(`Firestore query failed (${r.status})`);
    return (await r.json()).filter((x) => x.document).map((x) => decodeDoc(x.document));
  }

  async fcm(message) {
    return this.call(`https://fcm.googleapis.com/v1/projects/${this.project}/messages:send`, {
      method: "POST",
      body: JSON.stringify({ message }),
    });
  }
}

function decodeDoc(doc) {
  const out = { id: doc.name.split("/").pop() };
  for (const [k, v] of Object.entries(doc.fields || {})) out[k] = decode(v);
  return out;
}

function decode(v) {
  if ("stringValue" in v) return v.stringValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("nullValue" in v) return null;
  if ("arrayValue" in v) return (v.arrayValue.values || []).map(decode);
  if ("mapValue" in v) {
    return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)]));
  }
  return null;
}

function encode(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "boolean") return { booleanValue: v };
  if (typeof v === "number") return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) } };
}

// ---------- JWT helpers (WebCrypto) ----------

const b64url = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlStr = (s) => b64url(new TextEncoder().encode(s));
const fromB64url = (s) =>
  Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

async function signJwt(pem, payload) {
  const der = Uint8Array.from(
    atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const data = `${b64urlStr(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${b64urlStr(JSON.stringify(payload))}`;
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(data));
  return `${data}.${b64url(sig)}`;
}

let jwks = null, jwksExp = 0;

/** Verifies a Firebase Auth ID token and returns the uid. */
async function verifyIdToken(token, projectId) {
  const unauthorized = (m) => Object.assign(new Error(m), { status: 401 });
  const parts = token.split(".");
  if (parts.length !== 3) throw unauthorized("missing token");
  const header = JSON.parse(new TextDecoder().decode(fromB64url(parts[0])));
  const p = JSON.parse(new TextDecoder().decode(fromB64url(parts[1])));
  const now = Date.now() / 1000;
  if (header.alg !== "RS256") throw unauthorized("bad alg");
  if (p.aud !== projectId || p.iss !== `https://securetoken.google.com/${projectId}`) throw unauthorized("wrong project");
  if (!p.sub || p.exp < now || p.iat > now + 300) throw unauthorized("expired token");

  if (!jwks || jwksExp < Date.now()) {
    const r = await fetch("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com");
    jwks = (await r.json()).keys;
    jwksExp = Date.now() + 60 * 60 * 1000;
  }
  const jwk = jwks.find((k) => k.kid === header.kid);
  if (!jwk) throw unauthorized("unknown key");
  const key = await crypto.subtle.importKey(
    "jwk", jwk, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
  const ok = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5", key, fromB64url(parts[2]), new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!ok) throw unauthorized("bad signature");
  return p.sub;
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
