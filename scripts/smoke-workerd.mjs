import { execFileSync, spawn } from "node:child_process";
import { resolve } from "node:path";

const port = 8787;
const baseUrl = `http://127.0.0.1:${port}`;
const wranglerBin = resolve("node_modules", "wrangler", "bin", "wrangler.js");
const worker = spawn(process.execPath, [wranglerBin, "dev", "--local", "--port", String(port)], {
  cwd: process.cwd(),
  stdio: ["ignore", "pipe", "pipe"],
});

let logs = "";
worker.stdout.setEncoding("utf8");
worker.stderr.setEncoding("utf8");
worker.stdout.on("data", (chunk) => {
  logs += chunk;
});
worker.stderr.on("data", (chunk) => {
  logs += chunk;
});

async function fetchWithTimeout(path) {
  const signal = AbortSignal.timeout(2_000);
  return fetch(`${baseUrl}${path}`, { signal });
}

async function waitForWorker() {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    if (worker.exitCode !== null) {
      throw new Error(`workerd exited before becoming ready\n${logs}`);
    }

    try {
      return await fetchWithTimeout("/api/health");
    } catch {
      await new Promise((resolveDelay) => setTimeout(resolveDelay, 500));
    }
  }

  throw new Error(`workerd did not become ready\n${logs}`);
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

try {
  const health = await waitForWorker();
  const home = await fetchWithTimeout("/");
  const healthBody = await health.json();

  assert(home.status === 200, `expected / status 200, received ${home.status}`);
  assert(health.status === 200, `expected /api/health status 200, received ${health.status}`);
  assert(health.headers.get("cache-control") === "no-store", "health endpoint must use no-store");
  assert(home.headers.has("content-security-policy"), "CSP header is missing");
  assert(home.headers.get("x-frame-options") === "DENY", "X-Frame-Options must be DENY");
  assert(healthBody.status === "ok", "health response status must be ok");

  console.log(JSON.stringify({
    homeStatus: home.status,
    healthStatus: health.status,
    healthCacheControl: health.headers.get("cache-control"),
    contentSecurityPolicyPresent: true,
    xFrameOptions: home.headers.get("x-frame-options"),
    healthBody,
  }));
} finally {
  if (worker.exitCode === null) {
    if (process.platform === "win32") {
      execFileSync("taskkill", ["/PID", String(worker.pid), "/T", "/F"], { stdio: "ignore" });
    } else {
      worker.kill("SIGTERM");
    }
  }
}
