import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { createClient } from "@supabase/supabase-js";
import { main as assertDisposableTarget } from "./assert-disposable-supabase.mjs";

const execFileAsync = promisify(execFile);
const AUDIT_USERS = [
  {
    id: "11111111-1111-4111-8111-111111111111",
    email: "phase1-owner@example.com",
  },
  {
    id: "22222222-2222-4222-8222-222222222222",
    email: "phase1-other@example.com",
  },
  {
    id: "33333333-3333-4333-8333-333333333333",
    email: "phase2-moderator@example.com",
  },
  {
    id: "44444444-4444-4444-8444-444444444444",
    email: "phase2-outsider@example.com",
  },
];
const AUDIT_PASSWORD = "AuditOnly!Phase1Aa1";

async function loadLegacyServiceRole(projectRef) {
  const { stdout } = await execFileAsync(
    process.execPath,
    [
      "node_modules/supabase/dist/supabase.js",
      "projects",
      "api-keys",
      "--project-ref",
      projectRef,
      "--output",
      "json",
    ],
    { maxBuffer: 1024 * 1024 },
  );
  const keys = JSON.parse(stdout);
  const serviceRole = keys.find(
    (key) => key.name === "service_role" && key.type === "legacy",
  );

  if (!serviceRole?.api_key) {
    throw new Error("The linked audit project has no usable legacy service-role key.");
  }
  return serviceRole.api_key;
}

function safeAuthError(action, error) {
  const detail = error?.code ?? error?.status ?? "unknown";
  return new Error(`Could not ${action} an audit Auth fixture (${detail}).`);
}

function isMissingUser(error) {
  return (
    error?.status === 404 ||
    error?.code === "user_not_found" ||
    /user not found/i.test(error?.message ?? "")
  );
}

async function deleteAuditUsers(admin, { tolerateMissing = true } = {}) {
  for (const user of AUDIT_USERS) {
    const { error } = await admin.auth.admin.deleteUser(user.id, false);
    if (error && !(tolerateMissing && isMissingUser(error))) {
      throw safeAuthError("delete", error);
    }
  }
}

async function setupAuditUsers(admin) {
  await deleteAuditUsers(admin);
  for (const user of AUDIT_USERS) {
    const { data, error } = await admin.auth.admin.createUser({
      id: user.id,
      email: user.email,
      password: AUDIT_PASSWORD,
      email_confirm: true,
    });
    if (error || data.user?.id !== user.id) {
      throw safeAuthError("create", error);
    }
  }
}

async function main() {
  const command = process.argv[2];
  if (command !== "setup" && command !== "cleanup") {
    throw new Error("Usage: node scripts/phase-1-auth-fixtures.mjs <setup|cleanup>");
  }

  const { projectRef } = await assertDisposableTarget();
  const serviceRole = await loadLegacyServiceRole(projectRef);
  const admin = createClient(`https://${projectRef}.supabase.co`, serviceRole, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (command === "setup") {
    await setupAuditUsers(admin);
    console.log(`Created ${AUDIT_USERS.length} deterministic Auth audit fixtures.`);
    return;
  }

  await deleteAuditUsers(admin);
  console.log(`Removed ${AUDIT_USERS.length} deterministic Auth audit fixtures.`);
}

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : "Auth fixture operation failed.");
  process.exitCode = 1;
}
