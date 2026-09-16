import { Zap } from "lucide-react";

export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <div
        className={`relative flex items-center justify-center ${
          compact ? "h-5 w-5 rounded-md" : "h-10 w-10 rounded-xl"
        }`}
        style={{ background: "var(--gradient-accent)", boxShadow: "var(--glow-primary)" }}
      >
        <Zap
          className={compact ? "h-3 w-3 text-primary-foreground" : "h-5 w-5 text-primary-foreground"}
          strokeWidth={2.5}
        />
      </div>
      {!compact && (
        <div className="leading-tight">
          <p className="font-display text-lg font-semibold tracking-tight text-foreground">
            NEXUS<span className="text-primary">ACTIVATE</span>
          </p>
          <p className="text-[11px] uppercase tracking-[0.22em] text-muted-foreground">
            Steam Activation Suite
          </p>
        </div>
      )}
    </div>
  );
}
