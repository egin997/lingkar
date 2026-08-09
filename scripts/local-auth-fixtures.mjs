import { execFile } from "node:child_process";
import { pathToFileURL } from "node:url";
import { promisify } from "node:util";

import { createClient } from "@supabase/supabase-js";

const execFileAsync = promisify(execFile);
const AUDIT_USERS = [
  { id: "11111111-1111-4111-8111-111111111111", email: "phase1-owner@example.com" },
  { id: "22222222-2222-4222-8222-222222222222", email: "phase1-other@example.com" },
  { id: "33333333-3333-4333-8333-333333333333", email: "phase2-moderator@example.com" },
  { id: "44444444-4444-4444-8444-444444444444", email: "phase2-outsider@example.com" },
];
const AUDIT_PASSWORD = "AuditOnly!Phase1Aa1";

export function parseLocalStatus(status) {
  const apiUrl = status.API_URL;
  const serviceRoleKey = status.SERVICE_ROLE_KEY;
  if (typeof apiUrl !== "string" || typeof serviceRoleKey !== "string") {
    throw new Error("Local Supabase status did not provide the required credentials.");
  }
  const parsedUrl = new URL(apiUrl);
  if (
    parsedUrl.protocol !== "http:" ||
    (parsedUrl.hostname !== "127.0.0.1" && parsedUrl.hostname !== "localhost")
  ) {
    throw new Error("Refusing to provision fixtures outside local Supabase.");
  }
  if (serviceRoleKey.length < 40) {
    throw new Error("Local Supabase service-role credential is invalid.");
  }
  return { apiUrl: parsedUrl.origin, serviceRoleKey };
}

async function loadLocalCredentials() {
  const { stdout } = await execFileAsync(
    process.execPath,
    ["node_modules/supabase/dist/supabase.js", "status", "--output", "json"],
    { maxBuffer: 1024 * 1024 },
  );
  return parseLocalStatus(JSON.parse(stdout));
}

export async function main({
  load = loadLocalCredentials,
  log = console.log,
  clientFactory = createClient,
} = {}) {
  const { apiUrl, serviceRoleKey } = await load();
  const admin = clientFactory(apiUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  for (const user of AUDIT_USERS) {
    const { data, error } = await admin.auth.admin.createUser({
      id: user.id,
      email: user.email,
      password: AUDIT_PASSWORD,
      email_confirm: true,
    });
    if (error || data.user?.id !== user.id) {
      throw new Error(`Could not create local Auth fixture (${error?.status ?? "unknown"}).`);
    }
  }
  log(`Created ${AUDIT_USERS.length} deterministic local Auth audit fixtures.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Local Auth fixture setup failed.");
    process.exitCode = 1;
  }
}
