export type GateStatus = "ready" | "pending";

export interface FoundationGate {
  readonly id: string;
  readonly label: string;
  readonly evidence: string;
  readonly status: GateStatus;
}

export interface FoundationStatus {
  readonly phase: "Phase 0 · Foundation";
  readonly gates: readonly FoundationGate[];
}
