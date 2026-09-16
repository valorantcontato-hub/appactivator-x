import { KeyRound, Loader2, Check, X } from "lucide-react";
import { normalizeKey, isKeyFormatValid } from "@/utils/validation";
import type { ActivationPhase } from "@/types";

interface Props {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  onCancel: () => void;
  phase: ActivationPhase;
}

export function KeyField({ value, onChange, onSubmit, onCancel, phase }: Props) {
  const running = phase === "running";
  const valid = isKeyFormatValid(value);
  const showError = value.length > 0 && !valid;

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (valid && !running) onSubmit();
      }}
      className="space-y-3"
    >
      <label
        htmlFor="key"
        className="block text-[11px] font-medium uppercase tracking-[0.2em] text-muted-foreground"
      >
        Insira sua key
      </label>

      <div className="flex flex-col gap-3 sm:flex-row">
        <div
          className={`group relative flex-1 rounded-xl border bg-surface-2/60 transition-all duration-300 ${
            showError
              ? "border-destructive/70"
              : valid
                ? "border-primary/60"
                : "border-border focus-within:border-primary/60"
          }`}
        >
          <KeyRound className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <input
            id="key"
            autoComplete="off"
            spellCheck={false}
            disabled={running}
            value={value}
            onChange={(e) => onChange(normalizeKey(e.target.value))}
            placeholder="XXXXX-XXXXX-XXXXX-XXXXX"
            className="w-full bg-transparent py-3 pl-11 pr-11 font-mono text-sm tracking-[0.18em] text-foreground outline-none placeholder:text-muted-foreground/50 disabled:opacity-60"
          />
          {value.length > 0 && (
            <span className="absolute right-4 top-1/2 -translate-y-1/2">
              {valid ? (
                <Check className="h-4 w-4 text-success" />
              ) : (
                <X className="h-4 w-4 text-destructive" />
              )}
            </span>
          )}
        </div>

        {running ? (
          <button
            type="button"
            onClick={onCancel}
            className="flex items-center justify-center gap-2 rounded-xl border border-border bg-secondary px-7 py-3 font-display text-xs font-semibold uppercase tracking-[0.18em] text-foreground transition-colors hover:bg-secondary/70"
          >
            <Loader2 className="h-4 w-4 animate-spin" />
            Cancelar
          </button>
        ) : (
          <button
            type="submit"
            disabled={!valid}
            className="rounded-xl px-9 py-3 font-display text-xs font-semibold uppercase tracking-[0.18em] text-primary-foreground transition-all duration-300 disabled:cursor-not-allowed disabled:opacity-40 enabled:hover:-translate-y-0.5"
            style={{
              background: "var(--gradient-accent)",
              boxShadow: valid ? "var(--glow-primary)" : undefined,
            }}
          >
            Ativar
          </button>
        )}
      </div>

      {showError && (
        <p className="text-xs text-destructive">
          Formato inválido. A key tem 4 blocos de 5 caracteres.
        </p>
      )}
    </form>
  );
}
