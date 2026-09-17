// Build-time changes to upstream's source, applied to the pinned commit only. Every file is checked against
// the hash it had at that commit first, so a changed upstream file stops the build instead of being patched
// blindly. Usage: node patch-source.mjs /src
//
// The single change: make every browser WebSocket / direct-API URL derive from the page's own host at runtime,
// instead of `${host}:8001` (websocketClient.ts) or the server-only `process.env.SERVER_BASE_URL` that is
// undefined in the browser and falls back to localhost:8001 (slides/workshop pages — an upstream bug that
// breaks those features behind ANY reverse proxy, not only Railway). With this, a single public domain fronted
// by a proxy that routes /ws/* and /codemap/* to the API works with no build-time domain baking.
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = process.argv[2];
if (!root) throw new Error("usage: patch-source.mjs <source dir>");

const EXPECTED = {
  "src/utils/websocketClient.ts": "04e3d40902c9f48f06c1bd608dac27faa04d9700e5100c24ce22677294bd61a9",
  "src/app/[owner]/[repo]/slides/page.tsx": "fcaaef80738e71da2a5b7d631e0c09eeb579c841855b2f2d0ac93776944e8c81",
  "src/app/[owner]/[repo]/workshop/page.tsx": "50e352dcbc34387fde152da1265f5906631dcc608154260386edb2fe35a47992",
};

const read = (rel) => readFileSync(join(root, rel), "utf8");
const write = (rel, text) => writeFileSync(join(root, rel), text);

for (const [rel, want] of Object.entries(EXPECTED)) {
  const got = createHash("sha256").update(readFileSync(join(root, rel))).digest("hex");
  if (got !== want) throw new Error(`${rel} is not the file these patches were written for (sha256 ${got})`);
}

function replaceOnce(rel, from, to) {
  const text = read(rel);
  const at = text.indexOf(from);
  if (at < 0 || text.indexOf(from, at + 1) >= 0) throw new Error(`${rel}: expected exactly one match`);
  write(rel, text.slice(0, at) + to + text.slice(at + from.length));
}

function replaceAllRegex(rel, re, to, count) {
  const text = read(rel);
  const found = (text.match(re) || []).length;
  if (found !== count) throw new Error(`${rel}: expected ${count} matches, found ${found}`);
  write(rel, text.replace(re, to));
}

// 1. websocketClient.ts: the browser branch of getWsBase used `${host}:${NEXT_PUBLIC_API_PORT || 8001}`, which
//    is wrong behind a single-domain proxy. Use the page's own host (which already carries the right port via
//    the domain). The NEXT_PUBLIC_WS_BASE_URL override is left intact for anyone who wants explicit control.
replaceOnce(
  "src/utils/websocketClient.ts",
  "    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';\n    const host = window.location.hostname;\n    const port = process.env.NEXT_PUBLIC_API_PORT || '8001';\n    return `${wsProtocol}//${host}:${port}`;",
  "    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';\n    // Railway (and any single-domain reverse proxy) serves the API on the same host as the UI: use the page's\n    // own host, without appending the internal API port.\n    return `${wsProtocol}//${window.location.host}`;",
);

// 2. slides + workshop pages: the same broken block (`process.env.SERVER_BASE_URL || 'http://localhost:8001'`
//    in browser code). slides has it twice, workshop once, at different indentations. Replace each with a
//    same-host WebSocket URL. The regex tolerates leading whitespace but pins the exact code.
const BROKEN = /const serverBaseUrl = process\.env\.SERVER_BASE_URL \|\| 'http:\/\/localhost:8001';\s*\n\s*const wsBaseUrl = serverBaseUrl\.replace\(\/\^http\/, 'ws'\)\? serverBaseUrl\.replace\(\/\^https\/, 'wss'\): serverBaseUrl\.replace\(\/\^http\/, 'ws'\);\s*\n\s*const wsUrl = `\$\{wsBaseUrl\}\/ws\/chat`;/g;
const FIXED =
  "const wsUrl = `${(typeof window !== 'undefined' " +
  "? `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}` " +
  ": (process.env.SERVER_BASE_URL || 'http://localhost:8001').replace(/^http/, 'ws'))}/ws/chat`;";
replaceAllRegex("src/app/[owner]/[repo]/slides/page.tsx", BROKEN, FIXED, 2);
replaceAllRegex("src/app/[owner]/[repo]/workshop/page.tsx", BROKEN, FIXED, 1);

// Verify the broken browser-side pattern is gone from the two pages, and the same-host form is in.
for (const rel of ["src/app/[owner]/[repo]/slides/page.tsx", "src/app/[owner]/[repo]/workshop/page.tsx"]) {
  const t = read(rel);
  if (t.includes("const wsBaseUrl = serverBaseUrl.replace")) throw new Error(`${rel}: patch incomplete`);
  if (!t.includes("window.location.host}` : (process.env.SERVER_BASE_URL || 'http://localhost:8001')")) throw new Error(`${rel}: fixed form missing`);
}
if (!read("src/utils/websocketClient.ts").includes("return `${wsProtocol}//${window.location.host}`;")) {
  throw new Error("websocketClient.ts: fixed form missing");
}
console.log("patched:", Object.keys(EXPECTED).join(", "));
