import { execFileSync, spawn } from "node:child_process";
import { resolve } from "node:path";

const port = 8787;
const baseUrl = `http://127.0.0.1:${port}`;
const wranglerBin = resolve("node_modules", "wrangler", "bin", "wrangler.js");
const worker = spawn(
  process.execPath,
  [
    wranglerBin,
    "dev",
    "--local",
    "--port",
    String(port),
    "--var",
    "NEXT_PUBLIC_SUPABASE_URL:https://smoke-test.supabase.co",
    "--var",
    "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:sb_publishable_smoke_test_key",
    "--var",
    `NEXT_PUBLIC_SITE_URL:${baseUrl}`,
  ],
  {
    cwd: process.cwd(),
    stdio: ["ignore", "pipe", "pipe"],
  },
);

let logs = "";
worker.stdout.setEncoding("utf8");
worker.stderr.setEncoding("utf8");
worker.stdout.on("data", (chunk) => {
  logs += chunk;
});
worker.stderr.on("data", (chunk) => {
  logs += chunk;
});

async function fetchWithTimeout(path, options, timeoutMs = 15_000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(`${baseUrl}${path}`, { ...options, signal: controller.signal });
  } catch (error) {
    const detail = error instanceof Error ? error.message : "unknown request error";
    throw new Error(`workerd request ${path} failed: ${detail}\n${logs.slice(-4_000)}`);
  } finally {
    clearTimeout(timeout);
  }
}

async function waitForWorker() {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    if (worker.exitCode !== null) {
      throw new Error(`workerd exited before becoming ready\n${logs}`);
    }

    try {
      return await fetchWithTimeout("/api/health", undefined, 2_000);
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
  const signIn = await fetchWithTimeout("/auth/sign-in");
  const protectedAccount = await fetchWithTimeout("/account", { redirect: "manual" });
  const healthBody = await health.json();

  assert(home.status === 200, `expected / status 200, received ${home.status}`);
  assert(health.status === 200, `expected /api/health status 200, received ${health.status}`);
  assert(signIn.status === 200, `expected /auth/sign-in status 200, received ${signIn.status}`);
  assert(protectedAccount.status === 307, `expected /account redirect, received ${protectedAccount.status}`);
  assert(
    protectedAccount.headers.get("location")?.startsWith("/auth/sign-in") ||
      protectedAccount.headers.get("location")?.startsWith(`${baseUrl}/auth/sign-in`),
    "protected account must redirect to sign-in",
  );
  assert(health.headers.get("cache-control") === "no-store", "health endpoint must use no-store");
  assert(home.headers.has("content-security-policy"), "CSP header is missing");
  assert(home.headers.get("x-frame-options") === "DENY", "X-Frame-Options must be DENY");
  assert(healthBody.status === "ok", "health response status must be ok");

  console.log(JSON.stringify({
    homeStatus: home.status,
    signInStatus: signIn.status,
    protectedAccountStatus: protectedAccount.status,
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
