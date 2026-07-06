import { useState, type FormEvent } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from './AuthProvider';
import { PageShell } from '@/components/PageShell';

export function LoginPage() {
  const { configured, user, loading, signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (user && !loading) return <Navigate to="/" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    const { error } = await signIn(email.trim(), password);
    setBusy(false);
    if (error) setError(error);
  }

  return (
    <PageShell>
      <div className="mx-auto max-w-md">
        <div className="text-center">
          <p className="font-display text-xs uppercase tracking-[0.35em] text-gold-400">
            Speak, and be known
          </p>
          <h1 className="mt-3 text-3xl font-bold">Enter the Forge</h1>
          <div className="rule-ornament" />
        </div>

        {!configured ? (
          <div className="panel space-y-2 p-6 text-parchment-200">
            <h2 className="text-lg">Backend not configured</h2>
            <p className="text-sm">
              Set <code className="rounded bg-ink-700 px-1.5 py-0.5">VITE_SUPABASE_URL</code> and{' '}
              <code className="rounded bg-ink-700 px-1.5 py-0.5">VITE_SUPABASE_ANON_KEY</code> in your
              environment, then reload. See <code className="rounded bg-ink-700 px-1.5 py-0.5">supabase/README.md</code>.
            </p>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="panel space-y-4 p-6">
            {error && <div className="form-error">{error}</div>}
            <div>
              <label className="label" htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                className="input"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div>
              <label className="label" htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                className="input"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <button type="submit" className="btn-gold w-full" disabled={busy}>
              {busy ? 'Entering…' : 'Enter'}
            </button>
            <p className="text-center text-xs text-parchment-300">
              No public signup — accounts are created by invitation only.
            </p>
          </form>
        )}
      </div>
    </PageShell>
  );
}
