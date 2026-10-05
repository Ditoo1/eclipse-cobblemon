// Worker del pack de Eclipse Cobblemon: R2 como espejo del .minecraft del servidor.
//
// Público (lo usan las apps):
//   GET /v1/manifest                 manifiesto publicado (ETag; 304 si no cambió)
//   GET /v1/objects/<aa>/<sha1>      archivo por su SHA-1 (inmutable)
// Panel del owner (Authorization: Bearer <ADMIN_PASSWORD>):
//   GET    /admin                    panel web
//   GET    /v1/admin/state           borrador, revisión publicada e historial
//   PUT    /v1/admin/objects/<sha1>  subir un archivo (R2 comprueba el SHA-1)
//   PUT    /v1/admin/draft           guardar el borrador
//   POST   /v1/admin/publish         borrador -> manifiesto (revisión + 1, con el último Fabric estable)
//   POST   /v1/admin/rollback        {"revision": n} vuelve a publicar una revisión anterior
//   POST   /v1/admin/gc              borra objetos que ya no usa nadie
//
// Formato del manifiesto y reglas: docs/pack-sync.md (las apps validan lo mismo).

import PANEL from "./panel.html";

const MINECRAFT = "1.21.1";
const HISTORY_KEEP = 10;
const SHA1 = /^[0-9a-f]{40}$/;
const LOADER_VERSION = /^[0-9A-Za-z.+_-]{1,64}$/;
const PLATFORMS = new Set(["android", "ios"]);
const PROTECTED = new Set([
  ".eclipse", "saves", "screenshots", "logs", "crash-reports",
  "versions", "libraries", "assets", "accounts", "controlmap",
  "options.txt", "launcher_profiles.json", "launcher_preferences.plist",
]);

const EMPTY_DRAFT = { format: 1, minecraft: MINECRAFT, loader: null, exclusive: ["mods"], files: [], folders: [] };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;
    try {
      if (path === "/v1/manifest" && (method === "GET" || method === "HEAD")) return await manifest(request, env);

      const obj = path.match(/^\/v1\/objects\/([0-9a-f]{2})\/([0-9a-f]{40})$/);
      if (obj && (method === "GET" || method === "HEAD")) return await object(env, obj[1], obj[2], method);

      if ((path === "/admin" || path === "/admin/") && method === "GET") {
        return new Response(PANEL, {
          headers: {
            "content-type": "text/html; charset=utf-8",
            "cache-control": "no-store",
            "x-frame-options": "DENY",
            "content-security-policy": "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:",
          },
        });
      }

      if (path.startsWith("/v1/admin/")) {
        if (!env.ADMIN_PASSWORD) return json({ error: "Falta configurar el secreto ADMIN_PASSWORD" }, 503);
        if (!(await authorized(request, env))) return json({ error: "No autorizado" }, 401);
        return await admin(request, env, path.slice("/v1/admin/".length));
      }

      return new Response("Not found", { status: 404 });
    } catch (e) {
      return json({ error: e.message }, e.status || 500);
    }
  },
};

// ---------- Público ----------

async function manifest(request, env) {
  const obj = await env.PACK.get("manifest.json");
  if (!obj) return json({ error: "Todavía no hay ninguna revisión publicada" }, 404);
  const headers = { etag: obj.httpEtag, "cache-control": "no-cache", "content-type": "application/json; charset=utf-8" };
  if (request.headers.get("if-none-match") === obj.httpEtag) return new Response(null, { status: 304, headers });
  return new Response(request.method === "HEAD" ? null : obj.body, { headers });
}

async function object(env, prefix, sha1, method) {
  if (sha1.slice(0, 2) !== prefix) return new Response("Not found", { status: 404 });
  const obj = method === "HEAD" ? await env.PACK.head(objectKey(sha1)) : await env.PACK.get(objectKey(sha1));
  if (!obj) return new Response("Not found", { status: 404 });
  return new Response(method === "HEAD" ? null : obj.body, {
    headers: {
      etag: obj.httpEtag,
      "content-type": "application/octet-stream",
      "content-length": String(obj.size),
      // El contenido de un SHA-1 nunca cambia
      "cache-control": "public, max-age=31536000, immutable",
    },
  });
}

// ---------- Panel ----------

async function authorized(request, env) {
  const header = request.headers.get("authorization") || "";
  const given = header.startsWith("Bearer ") ? header.slice(7) : "";
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(given)),
    crypto.subtle.digest("SHA-256", enc.encode(env.ADMIN_PASSWORD)),
  ]);
  return crypto.subtle.timingSafeEqual(a, b);
}

async function admin(request, env, route) {
  const method = request.method;

  if (route === "state" && method === "GET") {
    const published = await readJson(env, "manifest.json");
    const draft = (await readJson(env, "draft.json")) || (published ? toDraft(published) : EMPTY_DRAFT);
    const latestLoader = await latestFabricLoader().catch(() => null);
    return json({ draft, published, history: await historyList(env), latestLoader });
  }

  const up = route.match(/^objects\/([0-9a-f]{40})$/);
  if (up && method === "PUT") {
    const sha1 = up[1];
    const existing = await env.PACK.head(objectKey(sha1));
    if (existing) return json({ sha1, size: existing.size, existed: true });
    if (!request.body) throw httpError(400, "Archivo vacío");
    // R2 rechaza la subida si el contenido no coincide con el SHA-1
    const put = await env.PACK.put(objectKey(sha1), request.body, { sha1 });
    return json({ sha1, size: put.size, existed: false });
  }

  if (route === "draft" && method === "PUT") {
    const draft = validate(await request.json());
    await env.PACK.put("draft.json", JSON.stringify(draft), { httpMetadata: { contentType: "application/json" } });
    return json({ ok: true });
  }

  if (route === "publish" && method === "POST") {
    const draft = validate((await readJson(env, "draft.json")) || EMPTY_DRAFT);
    const missing = await missingObjects(env, draft.files);
    if (missing.length) throw httpError(409, "Faltan archivos en R2: " + missing.slice(0, 5).join(", "));
    const revision = await publish(env, draft);
    return json({ revision });
  }

  if (route === "rollback" && method === "POST") {
    const { revision } = await request.json();
    const old = await readJson(env, `history/${Number(revision)}.json`);
    if (!old) throw httpError(404, `No existe la revisión ${revision}`);
    const draft = validate(toDraft(old));
    const missing = await missingObjects(env, draft.files);
    if (missing.length) throw httpError(409, "Esa revisión usa archivos ya borrados de R2");
    await env.PACK.put("draft.json", JSON.stringify(draft));
    return json({ revision: await publish(env, draft) });
  }

  if (route === "gc" && method === "POST") return json(await collectGarbage(env));

  throw httpError(404, "Ruta desconocida");
}

/** Última versión estable de Fabric Loader para la versión de Minecraft de las apps. */
async function latestFabricLoader() {
  const r = await fetch(`https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT}`);
  if (!r.ok) throw httpError(502, "meta.fabricmc.net no responde");
  const entry = (await r.json()).find((e) => e.loader?.stable);
  const version = entry?.loader?.version;
  if (!LOADER_VERSION.test(version || "")) throw httpError(502, "meta.fabricmc.net no devolvió ninguna versión estable");
  return version;
}

/**
 * Publica el borrador como nueva revisión y la guarda en el historial.
 * El loader es siempre el último Fabric estable, se elija lo que se elija en el borrador.
 */
async function publish(env, draft) {
  draft = { ...draft, loader: { type: "fabric", version: await latestFabricLoader() } };
  const current = await readJson(env, "manifest.json");
  const revision = (current?.revision || 0) + 1;
  const manifest = {
    format: 1,
    revision,
    publishedAt: new Date().toISOString(),
    minecraft: draft.minecraft,
    ...(draft.loader ? { loader: draft.loader } : {}),
    objects: "objects/",
    exclusive: draft.exclusive,
    files: draft.files,
  };
  const body = JSON.stringify(manifest);
  const meta = { httpMetadata: { contentType: "application/json" } };
  await env.PACK.put(`history/${revision}.json`, body, meta);
  await env.PACK.put("manifest.json", body, meta);
  return revision;
}

/** Borra los objetos que no usan ni el borrador, ni el manifiesto, ni las últimas revisiones. */
async function collectGarbage(env) {
  const used = new Set();
  const add = (m) => m?.files?.forEach((f) => used.add(f.sha1));
  add(await readJson(env, "draft.json"));
  add(await readJson(env, "manifest.json"));
  const history = await historyList(env);
  for (const h of history.slice(0, HISTORY_KEEP)) add(await readJson(env, `history/${h.revision}.json`));

  let deleted = 0;
  let kept = 0;
  let cursor;
  do {
    const page = await env.PACK.list({ prefix: "objects/", cursor });
    const stale = page.objects.map((o) => o.key).filter((k) => !used.has(k.split("/").pop()));
    if (stale.length) await env.PACK.delete(stale);
    deleted += stale.length;
    kept += page.objects.length - stale.length;
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return { deleted, kept };
}

async function historyList(env) {
  const out = [];
  let cursor;
  do {
    const page = await env.PACK.list({ prefix: "history/", cursor });
    for (const o of page.objects) {
      const revision = Number(o.key.slice("history/".length, -".json".length));
      if (Number.isInteger(revision)) out.push({ revision, publishedAt: o.uploaded });
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return out.sort((a, b) => b.revision - a.revision);
}

async function missingObjects(env, files) {
  const hashes = [...new Set(files.map((f) => f.sha1))];
  const missing = [];
  for (let i = 0; i < hashes.length; i += 20) {
    const batch = hashes.slice(i, i + 20);
    const heads = await Promise.all(batch.map((h) => env.PACK.head(objectKey(h))));
    heads.forEach((h, k) => !h && missing.push(batch[k]));
  }
  return missing;
}

// ---------- Validación (las apps aplican las mismas reglas) ----------

export function isSafePath(path) {
  if (typeof path !== "string" || !path || path.length > 512 || path.startsWith("/") || path.includes("\\") || path.includes(":")) return false;
  const parts = path.split("/");
  if (parts.some((p) => !p || p === "." || p === "..")) return false;
  return !PROTECTED.has(parts[0].toLowerCase());
}

export function validate(d) {
  const fail = (msg) => { throw httpError(400, msg); };
  if (!d || typeof d !== "object") fail("Borrador inválido");
  if (d.minecraft !== MINECRAFT) fail(`Las apps solo soportan Minecraft ${MINECRAFT}`);
  let loader = null;
  if (d.loader) {
    if (d.loader.type !== "fabric") fail("Solo se admite Fabric");
    if (!LOADER_VERSION.test(d.loader.version || "")) fail("Versión de Fabric inválida");
    loader = { type: "fabric", version: d.loader.version };
  }
  const exclusive = Array.isArray(d.exclusive) ? d.exclusive : [];
  exclusive.forEach((dir) => isSafePath(dir) || fail(`Carpeta no permitida: ${dir}`));
  if (!Array.isArray(d.files)) fail("Falta la lista de archivos");
  const seen = new Set();
  const files = d.files.map((f) => {
    if (!isSafePath(f.path)) fail(`Ruta no permitida: ${f.path}`);
    const key = f.path.toLowerCase();
    if (seen.has(key)) fail(`Ruta repetida: ${f.path}`);
    seen.add(key);
    if (!SHA1.test(f.sha1 || "")) fail(`SHA-1 inválido en ${f.path}`);
    if (!Number.isSafeInteger(f.size) || f.size < 0) fail(`Tamaño inválido en ${f.path}`);
    const mode = f.mode || "sync";
    if (mode !== "sync" && mode !== "once") fail(`Modo inválido en ${f.path}`);
    const out = { path: f.path, sha1: f.sha1, size: f.size };
    if (mode !== "sync") out.mode = mode;
    if (f.platforms != null) {
      if (!Array.isArray(f.platforms) || !f.platforms.length || f.platforms.some((p) => !PLATFORMS.has(p))) fail(`Plataformas inválidas en ${f.path}`);
      if (f.platforms.length < PLATFORMS.size) out.platforms = [...new Set(f.platforms)];
    }
    return out;
  });
  files.sort((a, b) => a.path.localeCompare(b.path));
  // Carpetas vacías creadas en el panel: solo viven en el borrador, el manifiesto no las lleva
  const folders = Array.isArray(d.folders) ? d.folders : [];
  folders.forEach((dir) => isSafePath(dir) || fail(`Carpeta no permitida: ${dir}`));
  return { format: 1, minecraft: MINECRAFT, loader, exclusive: [...new Set(exclusive)], files, folders: [...new Set(folders)].sort() };
}

// ---------- Utilidades ----------

function toDraft(m) {
  return { format: 1, minecraft: m.minecraft, loader: m.loader || null, exclusive: m.exclusive || [], files: m.files || [], folders: [] };
}

function objectKey(sha1) {
  return `objects/${sha1.slice(0, 2)}/${sha1}`;
}

async function readJson(env, key) {
  const obj = await env.PACK.get(key);
  return obj ? obj.json() : null;
}

function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}
