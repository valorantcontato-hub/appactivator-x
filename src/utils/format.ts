export function formatDuration(seconds: number): string {
  const safe = Math.max(0, Math.round(seconds));
  const m = Math.floor(safe / 60);
  const s = safe % 60;
  if (m === 0) return `${s}s`;
  return `${m}m ${String(s).padStart(2, "0")}s`;
}

export function formatClock(timestamp: number): string {
  const d = new Date(timestamp);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

export function logMarker(level: "info" | "success" | "warn" | "error"): string {
  switch (level) {
    case "success":
      return "[✓]";
    case "warn":
      return "[!]";
    case "error":
      return "[x]";
    default:
      return "[»]";
  }
}
