import { isSupabaseConfigured } from './lib/supabase';

/**
 * Stage 0 shell. Establishes the gothic-fantasy visual language and reports
 * backend-connection status. Real routing (auth, campaigns, characters) lands
 * in Stage 1 once a Supabase project is wired up.
 */
export default function App() {
  return (
    <div className="min-h-screen">
      <header className="border-b border-gold-500/20 bg-ink-900/60 backdrop-blur">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5">
          <div className="flex items-center gap-3">
            <span aria-hidden className="text-2xl text-gold-400">⚜</span>
            <span className="font-display text-lg font-semibold uppercase tracking-[0.2em] text-parchment-50">
              The Character Forge
            </span>
          </div>
          <span className="font-display text-xs uppercase tracking-widest text-parchment-300">
            D&amp;D 5e · 2024 Rules
          </span>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-6 py-16">
        <section className="text-center">
          <p className="font-display text-xs uppercase tracking-[0.35em] text-gold-400">
            By candlelight the party gathers
          </p>
          <h1 className="mt-4 text-4xl font-bold sm:text-5xl">A Forge for Heroes &amp; Their Doom</h1>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-parchment-200">
            A private character creator and campaign manager for the party — forged for our
            own table, our own homebrew, and the long roads ahead.
          </p>
          <div className="rule-ornament" />
        </section>

        <section className="mx-auto max-w-xl">
          <div className="panel p-6">
            <h2 className="text-xl">Backend status</h2>
            {isSupabaseConfigured ? (
              <p className="mt-3 text-parchment-200">
                <span className="text-gold-300">◆</span> Supabase is configured. Ready to build
                Stage&nbsp;1 (accounts, campaigns, characters).
              </p>
            ) : (
              <div className="mt-3 space-y-3 text-parchment-200">
                <p>
                  <span className="text-blood-500">◆</span> Supabase is not yet configured. Copy{' '}
                  <code className="rounded bg-ink-700 px-1.5 py-0.5 text-parchment-100">.env.example</code>{' '}
                  to <code className="rounded bg-ink-700 px-1.5 py-0.5 text-parchment-100">.env</code>{' '}
                  and add your project URL and anon key.
                </p>
                <p className="text-sm text-parchment-300">
                  The app builds and deploys without it — this is the Stage&nbsp;0 checkpoint.
                </p>
              </div>
            )}
          </div>
          <div className="mt-6 flex justify-center gap-3">
            <button className="btn-gold" disabled>
              Enter the Forge
            </button>
            <button className="btn-blood" disabled>
              View Memorial
            </button>
          </div>
          <p className="mt-3 text-center text-xs text-parchment-300">
            Actions unlock in Stage&nbsp;1.
          </p>
        </section>
      </main>

      <footer className="border-t border-gold-500/20 py-6">
        <p className="mx-auto max-w-5xl px-6 text-center text-xs text-parchment-300">
          Includes material from the System Reference Document 5.2, © Wizards of the Coast,
          available under the Creative Commons Attribution 4.0 International License.
        </p>
      </footer>
    </div>
  );
}
