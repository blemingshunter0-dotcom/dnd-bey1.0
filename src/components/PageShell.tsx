import type { ReactNode } from 'react';

/** Shared gothic frame: crest header + CC-BY attribution footer. */
export function PageShell({
  children,
  actions,
}: {
  children: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col">
      <header className="border-b border-gold-500/20 bg-ink-900/60 backdrop-blur">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
          <div className="flex items-center gap-3">
            <span aria-hidden className="text-2xl text-gold-400">⚜</span>
            <span className="font-display text-base font-semibold uppercase tracking-[0.2em] text-parchment-50">
              The Character Forge
            </span>
          </div>
          <div className="flex items-center gap-4">{actions}</div>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 px-6 py-10">{children}</main>

      <footer className="border-t border-gold-500/20 py-5">
        <p className="mx-auto max-w-5xl px-6 text-center text-xs text-parchment-300">
          Includes material from the System Reference Document 5.2, © Wizards of the Coast,
          used under the Creative Commons Attribution 4.0 International License.
        </p>
      </footer>
    </div>
  );
}
