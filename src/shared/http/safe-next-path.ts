export function safeNextPath(value: string | null, fallback: string): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || value.includes("\\")) {
    return fallback;
  }

  const resolved = new URL(value, "https://lingkar.invalid");

  if (resolved.origin !== "https://lingkar.invalid") {
    return fallback;
  }

  return `${resolved.pathname}${resolved.search}${resolved.hash}`;
}
