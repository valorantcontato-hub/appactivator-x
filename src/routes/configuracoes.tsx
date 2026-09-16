import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { FolderSearch, RefreshCw, Info, Check, HardDrive } from "lucide-react";
import { WindowShell } from "@/components/WindowShell";
import { useSteamDetection } from "@/hooks/useSteamDetection";
import { getBackend } from "@/services";

export const Route = createFileRoute("/configuracoes")({
  head: () => ({
    meta: [
      { title: "Configurações — Nexus Activate" },
      {
        name: "description",
        content:
          "Ajuste o diretório da Steam, reescaneie a instalação e consulte a versão do Nexus Activate.",
      },
      { property: "og:title", content: "Configurações — Nexus Activate" },
      {
        property: "og:description",
        content: "Diretório da Steam, reescaneamento da instalação e informações do aplicativo.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: SettingsPage,
});

function SettingsPage() {
  const { info, scanning, scan, setPath } = useSteamDetection();
  const [draft, setDraft] = useState("");
  const [saved, setSaved] = useState(false);
  const [version, setVersion] = useState("—");

  useEffect(() => {
    if (info?.path) setDraft(info.path);
  }, [info?.path]);

  useEffect(() => {
    void getBackend()
      .getAppVersion()
      .then(setVersion)
      .catch(() => setVersion("—"));
  }, []);

  const save = async () => {
    await setPath(draft.trim());
    setSaved(true);
    setTimeout(() => setSaved(false), 1800);
  };

  return (
    <WindowShell>
      <div className="space-y-5">
        <div>
          <h1 className="font-display text-2xl font-semibold tracking-tight text-foreground">
            Configurações
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            Ajustes da instalação da Steam e informações do aplicativo.
          </p>
        </div>

        <section className="rounded-2xl border border-border/70 bg-surface/70 p-5 backdrop-blur-xl">
          <div className="mb-4 flex items-center gap-2">
            <HardDrive className="h-4 w-4 text-primary" />
            <h2 className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">
              Diretório da Steam
            </h2>
          </div>

          <div className="flex flex-col gap-3 sm:flex-row">
            <div className="relative flex-1">
              <FolderSearch className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <input
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                placeholder="C:\\Program Files (x86)\\Steam"
                spellCheck={false}
                className="w-full rounded-xl border border-border bg-surface-2/60 py-3.5 pl-11 pr-4 font-mono text-sm text-foreground outline-none transition-colors focus:border-primary/60"
              />
            </div>
            <button
              type="button"
              onClick={save}
              className="rounded-xl border border-border bg-secondary px-5 py-3.5 text-sm font-medium text-foreground transition-colors hover:bg-secondary/70"
            >
              {saved ? (
                <span className="flex items-center gap-2 text-success">
                  <Check className="h-4 w-4" /> Salvo
                </span>
              ) : (
                "Salvar"
              )}
            </button>
            <button
              type="button"
              onClick={() => void scan()}
              disabled={scanning}
              className="flex items-center justify-center gap-2 rounded-xl px-5 py-3.5 text-sm font-medium text-primary-foreground transition-all hover:-translate-y-0.5 disabled:opacity-60"
              style={{ background: "var(--gradient-accent)" }}
            >
              <RefreshCw className={`h-4 w-4 ${scanning ? "animate-spin" : ""}`} />
              Reescanear
            </button>
          </div>

          <p className="mt-3 text-xs text-muted-foreground">
            {scanning
              ? "Procurando instalação da Steam..."
              : info?.found
                ? `Instalação detectada automaticamente · versão ${info.version ?? "desconhecida"}`
                : "Nenhuma instalação detectada. Informe o caminho manualmente."}
          </p>

          {info?.libraries && info.libraries.length > 0 && (
            <div className="mt-4 rounded-xl border border-border/60 bg-surface-2/40 p-3">
              <p className="mb-2 text-[11px] uppercase tracking-[0.2em] text-muted-foreground">
                Bibliotecas encontradas
              </p>
              <ul className="space-y-1 font-mono text-xs text-foreground/80">
                {info.libraries.map((lib) => (
                  <li key={lib}>{lib}</li>
                ))}
              </ul>
            </div>
          )}
        </section>

        <section className="rounded-2xl border border-border/70 bg-surface/70 p-5 backdrop-blur-xl">
          <div className="mb-4 flex items-center gap-2">
            <Info className="h-4 w-4 text-primary" />
            <h2 className="text-xs font-medium uppercase tracking-[0.2em] text-muted-foreground">
              Sobre o aplicativo
            </h2>
          </div>
          <dl className="grid gap-3 sm:grid-cols-3">
            <InfoItem label="Versão" value={version} />
            <InfoItem label="Plataforma" value="Windows x64" />
            <InfoItem label="Modo de execução" value={getBackend().name === "tauri" ? "Nativo" : "Simulado"} />
          </dl>
        </section>
      </div>
    </WindowShell>
  );
}

function InfoItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-border/60 bg-surface-2/40 px-3 py-2.5">
      <dt className="text-[11px] uppercase tracking-[0.18em] text-muted-foreground">{label}</dt>
      <dd className="mt-1 font-mono text-sm text-foreground">{value}</dd>
    </div>
  );
}
