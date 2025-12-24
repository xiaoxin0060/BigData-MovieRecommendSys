#!/usr/bin/env node
'use strict';

/**
 * RecSys end-to-end load generator (Windows-friendly):
 *   register -> login -> rate random movies -> poll recommendations
 *
 * Requirements:
 * - the-backend running and reachable (default http://localhost:3000)
 * - (optional but recommended) Processor streaming jobs running on Linux:
 *   - RatingsIngestJob (Kafka -> MySQL rating + aggregates)
 *   - RealtimeRecBackfillJob (Kafka -> MySQL recommendation)
 *
 * Usage:
 *   node tools/load_test_recsys.js --users 50 --ratings-per-user 3 --concurrency 5
 *
 * Env:
 *   API_BASE=http://localhost:3000/api
 */

const DEFAULTS = {
  apiBase: process.env.API_BASE || 'http://localhost:3000/api',
  users: 20,
  ratingsPerUser: 3,
  concurrency: 3,
  moviePoolSize: 200,
  waitRecsMs: 15000,
  pollIntervalMs: 1000,
  requestTimeoutMs: 10000,
  ratingMin: 1.0,
  ratingMax: 5.0,
  ratingStep: 0.5,
};

function nowMs() {
  return Date.now();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseArgs(argv) {
  const out = {};
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--help' || a === '-h') out.help = true;
    else if (a === '--api-base') out.apiBase = args[++i];
    else if (a === '--users') out.users = Number(args[++i]);
    else if (a === '--ratings-per-user') out.ratingsPerUser = Number(args[++i]);
    else if (a === '--concurrency') out.concurrency = Number(args[++i]);
    else if (a === '--movie-pool-size') out.moviePoolSize = Number(args[++i]);
    else if (a === '--wait-recs-ms') out.waitRecsMs = Number(args[++i]);
    else if (a === '--poll-interval-ms') out.pollIntervalMs = Number(args[++i]);
    else if (a === '--request-timeout-ms') out.requestTimeoutMs = Number(args[++i]);
    else throw new Error(`Unknown arg: ${a} (use --help)`);
  }
  return out;
}

function usage() {
  return [
    'Usage:',
    '  node tools/load_test_recsys.js [options]',
    '',
    'Options:',
    `  --api-base <url>           default: ${DEFAULTS.apiBase}`,
    `  --users <n>                default: ${DEFAULTS.users}`,
    `  --ratings-per-user <n>     default: ${DEFAULTS.ratingsPerUser} (recommend >=3 to trigger fold-in)`,
    `  --concurrency <n>          default: ${DEFAULTS.concurrency}`,
    `  --movie-pool-size <n>      default: ${DEFAULTS.moviePoolSize}`,
    `  --wait-recs-ms <ms>        default: ${DEFAULTS.waitRecsMs}`,
    `  --poll-interval-ms <ms>    default: ${DEFAULTS.pollIntervalMs}`,
    `  --request-timeout-ms <ms>  default: ${DEFAULTS.requestTimeoutMs}`,
    '',
    'Examples:',
    '  node tools/load_test_recsys.js --users 100 --ratings-per-user 3 --concurrency 10',
    '  API_BASE=http://localhost:3000/api node tools/load_test_recsys.js --users 20',
    '',
  ].join('\n');
}

async function fetchJson(url, options = {}) {
  if (typeof fetch !== 'function') {
    throw new Error('Global fetch not found. Please use Node.js >= 18.');
  }
  const controller = new AbortController();
  const timeoutMs = options.timeoutMs ?? DEFAULTS.requestTimeoutMs;
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      ...options,
      signal: controller.signal,
      headers: {
        ...(options.headers || {}),
        'Content-Type': 'application/json',
      },
    });
    const text = await res.text();
    let body;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = { raw: text };
    }
    if (!res.ok) {
      const msg = body?.message ? `: ${body.message}` : '';
      throw new Error(`HTTP ${res.status} ${res.statusText}${msg}`);
    }
    return body;
  } finally {
    clearTimeout(t);
  }
}

function randInt(minIncl, maxIncl) {
  return minIncl + Math.floor(Math.random() * (maxIncl - minIncl + 1));
}

function randChoice(arr) {
  return arr[randInt(0, arr.length - 1)];
}

function randRating({ min, max, step }) {
  const steps = Math.round((max - min) / step);
  return min + randInt(0, steps) * step;
}

function uniqueSample(arr, count) {
  const picked = new Set();
  const out = [];
  const limit = Math.min(count, arr.length);
  while (out.length < limit) {
    const v = randChoice(arr);
    if (picked.has(v)) continue;
    picked.add(v);
    out.push(v);
  }
  return out;
}

async function getMovieIdPool(apiBase, moviePoolSize) {
  const url = new URL(`${apiBase.replace(/\/+$/, '')}/movies`);
  url.searchParams.set('page', '1');
  url.searchParams.set('pageSize', String(moviePoolSize));
  url.searchParams.set('sort', 'avgRating');
  const body = await fetchJson(url.toString(), { method: 'GET' });
  const movies = body?.data?.movies || [];
  const ids = movies.map((m) => m?.id).filter(Boolean);
  if (ids.length === 0) {
    throw new Error('No movies returned from /api/movies; ensure movie table is populated.');
  }
  return ids;
}

async function registerUser(apiBase, payload) {
  return fetchJson(`${apiBase.replace(/\/+$/, '')}/users/register`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

async function loginUser(apiBase, payload) {
  return fetchJson(`${apiBase.replace(/\/+$/, '')}/users/login`, {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

async function createRating(apiBase, token, payload) {
  return fetchJson(`${apiBase.replace(/\/+$/, '')}/ratings`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });
}

async function getMyRecommendations(apiBase, token) {
  const url = new URL(`${apiBase.replace(/\/+$/, '')}/recommendations/for-me`);
  url.searchParams.set('page', '1');
  url.searchParams.set('pageSize', '8');
  return fetchJson(url.toString(), {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
}

async function pollRecommendations({ apiBase, token, waitRecsMs, pollIntervalMs }) {
  const start = nowMs();
  while (nowMs() - start <= waitRecsMs) {
    const body = await getMyRecommendations(apiBase, token);
    const recs = body?.data?.recommendations || [];
    if (Array.isArray(recs) && recs.length > 0) {
      return { ok: true, body, latencyMs: nowMs() - start };
    }
    await sleep(pollIntervalMs);
  }
  const last = await getMyRecommendations(apiBase, token).catch(() => null);
  return { ok: false, body: last, latencyMs: nowMs() - start };
}

async function runOneUser(cfg, movieIds, userIndex) {
  const ts = new Date().toISOString().replace(/[-:.TZ]/g, '');
  const userAccount = `load_${ts}_${process.pid}_${userIndex}@example.com`;
  const userPassword = '123456';
  const userName = `LoadUser_${userIndex}`;
  const gender = userIndex % 2;

  const regPayload = { userAccount, userPassword, userName, gender };
  await registerUser(cfg.apiBase, regPayload);

  const loginBody = await loginUser(cfg.apiBase, { userAccount, userPassword });
  const token = loginBody?.data?.token;
  if (!token) throw new Error('Login succeeded but token missing');

  const pickedMovieIds = uniqueSample(movieIds, cfg.ratingsPerUser);
  for (const mid of pickedMovieIds) {
    const rating = randRating({ min: cfg.ratingMin, max: cfg.ratingMax, step: cfg.ratingStep });
    await createRating(cfg.apiBase, token, { movieId: String(mid), rating });
  }

  const recStart = nowMs();
  const recRes = await pollRecommendations({
    apiBase: cfg.apiBase,
    token,
    waitRecsMs: cfg.waitRecsMs,
    pollIntervalMs: cfg.pollIntervalMs,
  });

  const modelVersion = recRes?.body?.data?.modelVersion;
  const recCount = Array.isArray(recRes?.body?.data?.recommendations)
    ? recRes.body.data.recommendations.length
    : 0;

  return {
    userAccount,
    ratingsSent: pickedMovieIds.length,
    recOk: recRes.ok,
    recCount,
    recLatencyMs: nowMs() - recStart,
    modelVersion: modelVersion || null,
  };
}

async function runWithConcurrency(items, concurrency, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function oneWorker() {
    for (;;) {
      const i = nextIndex++;
      if (i >= items.length) return;
      results[i] = await worker(items[i], i);
    }
  }

  const workers = [];
  const n = Math.max(1, Math.min(concurrency, items.length));
  for (let i = 0; i < n; i++) workers.push(oneWorker());
  await Promise.all(workers);
  return results;
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    process.stdout.write(usage());
    return;
  }

  const cfg = { ...DEFAULTS, ...args };
  if (!Number.isFinite(cfg.users) || cfg.users <= 0) throw new Error('--users must be > 0');
  if (!Number.isFinite(cfg.ratingsPerUser) || cfg.ratingsPerUser <= 0) throw new Error('--ratings-per-user must be > 0');
  if (!Number.isFinite(cfg.concurrency) || cfg.concurrency <= 0) throw new Error('--concurrency must be > 0');

  const startAll = nowMs();
  console.log(`[load-test] apiBase=${cfg.apiBase} users=${cfg.users} ratingsPerUser=${cfg.ratingsPerUser} concurrency=${cfg.concurrency}`);

  const movieIds = await getMovieIdPool(cfg.apiBase, cfg.moviePoolSize);
  console.log(`[load-test] movie pool loaded: ${movieIds.length} ids`);

  const userIndices = Array.from({ length: cfg.users }, (_, i) => i + 1);
  const results = await runWithConcurrency(userIndices, cfg.concurrency, async (userIndex) => {
    const t0 = nowMs();
    try {
      const r = await runOneUser(cfg, movieIds, userIndex);
      console.log(`[user ${userIndex}] ok ratings=${r.ratingsSent} recOk=${r.recOk} recCount=${r.recCount} model=${r.modelVersion || '-'} recWaitMs=${r.recLatencyMs}`);
      return { ok: true, ...r, totalMs: nowMs() - t0 };
    } catch (e) {
      console.error(`[user ${userIndex}] failed: ${e && e.message ? e.message : String(e)}`);
      return { ok: false, error: e && e.message ? e.message : String(e), totalMs: nowMs() - t0 };
    }
  });

  const okUsers = results.filter((r) => r && r.ok);
  const failedUsers = results.filter((r) => r && !r.ok);
  const ratingsSent = okUsers.reduce((s, r) => s + (r.ratingsSent || 0), 0);
  const recOkCount = okUsers.reduce((s, r) => s + (r.recOk ? 1 : 0), 0);
  const avgRecWait = okUsers.length
    ? Math.round(okUsers.reduce((s, r) => s + (r.recLatencyMs || 0), 0) / okUsers.length)
    : 0;

  console.log('---');
  console.log(`[load-test] done in ${nowMs() - startAll}ms`);
  console.log(`[load-test] users ok=${okUsers.length} failed=${failedUsers.length}`);
  console.log(`[load-test] ratings sent=${ratingsSent}`);
  console.log(`[load-test] users with recommendations=${recOkCount}/${okUsers.length} avgRecWaitMs=${avgRecWait}`);

  if (recOkCount === 0) {
    console.log('[load-test] hint: if users are created but no recommendations appear, check Kafka connectivity + Processor streaming jobs + RealtimeRecBackfillJob logs.');
  }
}

main().catch((e) => {
  console.error(e && e.stack ? e.stack : String(e));
  process.exitCode = 1;
});

