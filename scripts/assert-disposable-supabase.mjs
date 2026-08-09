import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

export const RESET_ACKNOWLEDGEMENT = "RESET_DISPOSABLE_DATABASE_ONLY";

export function validateTarget({ linkedRef, expectedRef, environment, acknowledgement }) {
  const normalizedEnvironment = environment?.trim().toLowerCase();
  const allowedEnvironments = new Set(["audit", "dev", "disposable", "staging", "throwaway"]);

  if (!linkedRef || !expectedRef || linkedRef !== expectedRef) {
    throw new Error("Linked project ref does not match SUPABASE_AUDIT_PROJECT_REF.");
  }

  if (!normalizedEnvironment || !allowedEnvironments.has(normalizedEnvironment)) {
    throw new Error("SUPABASE_AUDIT_ENVIRONMENT must explicitly name a non-production environment.");
  }

  if (acknowledgement !== RESET_ACKNOWLEDGEMENT) {
    throw new Error("Destructive reset acknowledgement is missing or incorrect.");
  }

  return { projectRef: linkedRef, environment: normalizedEnvironment };
}

export async function main({
  read = readFile,
  environmentVariables = process.env,
  log = console.log,
} = {}) {
  let linkedRef;
  try {
    linkedRef = (await read("supabase/.temp/project-ref", "utf8")).trim();
  } catch {
    throw new Error("No linked Supabase project. Run supabase link only after target approval.");
  }
  const target = validateTarget({
    linkedRef,
    expectedRef: environmentVariables.SUPABASE_AUDIT_PROJECT_REF,
    environment: environmentVariables.SUPABASE_AUDIT_ENVIRONMENT,
    acknowledgement: environmentVariables.SUPABASE_AUDIT_RESET_ACK,
  });

  log(`Verified disposable Supabase target: ${target.projectRef} (${target.environment})`);
  return target;
}

/* v8 ignore start -- process adapter; target behavior is exercised through main() */
const entrypoint = process.argv[1] ? pathToFileURL(process.argv[1]).href : undefined;
if (entrypoint === import.meta.url) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : "Target verification failed.");
    process.exitCode = 1;
  }
}
/* v8 ignore stop */
