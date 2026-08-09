export type GateStatus = "ready";

export interface FoundationGate {
  readonly id: string;
  readonly label: string;
  readonly evidence: string;
  readonly status: GateStatus;
}

export interface FoundationStatus {
  readonly phase: "Phase 0 · Verified";
  readonly gates: readonly FoundationGate[];
}
