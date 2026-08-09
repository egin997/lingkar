import type { FoundationStatus } from "../domain/foundation";

const status: FoundationStatus = {
  phase: "Phase 0 · Verified",
  gates: [
    {
      id: "architecture",
      label: "Modular monolith",
      evidence: "Boundary domain, application, dan infrastructure.",
      status: "ready",
    },
    {
      id: "quality",
      label: "Quality gates",
      evidence: "Lint, typecheck, unit test, build, dan CI.",
      status: "ready",
    },
    {
      id: "database",
      label: "Database reproducible",
      evidence: "Migration replay, pgTAP, lint, dan security audit lulus.",
      status: "ready",
    },
    {
      id: "deployment",
      label: "Cloudflare-ready",
      evidence: "OpenNext build dan Wrangler config.",
      status: "ready",
    },
  ],
};

export function getFoundationStatus(): FoundationStatus {
  return status;
}
