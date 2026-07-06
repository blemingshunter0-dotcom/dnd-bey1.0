import { useState, type FormEvent } from 'react';
import { Navigate, useParams } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from './AuthProvider';
import { PageShell } from '@/components/PageShell';

/**
 * Invite-link acceptance. The recipient has no account yet, so we call the
 * `accept-invite` Edge Function (service role) to validate the token and create
 * the account, then sign in with the credentials they just chose.
 */
export function AcceptInvitePage() {
  const { token } = useParams<{ token: string }>();
  const { user, loading, signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  if (user && !loading) return <Navigate to="/" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) return setError('Password must be at least 8 characters.');
    if (password !== confirm) return setError('Passwords do not match.');
    if (!supabase) return setError('Backend is not configured.');

    setBusy(true);
    const { data, error: fnError } = await supabase.functions.invoke('accept-invite', {
      body: { token, email: email.trim(), password, display_name: displayName.trim() },
    });
    if (fnError || data?.error) {
      setBusy(false);
      return setError(data?.error ?? fnError?.message ?? 'Could not accept invite.');
    }
    // Account created — sign in with the resolved email the function returned.
    const { error: signInError } = await signIn(data.email ?? email.trim(), password);
    setBusy(false);
    if (signInError) setError(signInError);
  }

  return (
    <PageShell>
      <div className="mx-auto max-w-md">
        <div className="text-center">
          <p className="font-display text-xs uppercase tracking-[0.35em] text-gold-400">
            A seat awaits at the table
          </p>
          <h1 className="mt-3 text-3xl font-bold">Claim Your Invitation</h1>
          <div className="rule-ornament" />
        </div>

        {!token ? (
          <div className="form-error">This invite link is missing its token.</div>
        ) : (
          <form onSubmit={onSubmit} className="panel space-y-4 p-6">
            {error && <div className="form-error">{error}</div>}
            <div>
              <label className="label" htmlFor="display">Display name</label>
              <input id="display" className="input" required value={displayName}
                onChange={(e) => setDisplayName(e.target.value)} placeholder="e.g. Hunter" />
            </div>
            <div>
              <label className="label" htmlFor="email">Email</label>
              <input id="email" type="email" autoComplete="email" required className="input"
                value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="password">Password</label>
              <input id="password" type="password" autoComplete="new-password" required className="input"
                value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
            <div>
              <label className="label" htmlFor="confirm">Confirm password</label>
              <input id="confirm" type="password" autoComplete="new-password" required className="input"
                value={confirm} onChange={(e) => setConfirm(e.target.value)} />
            </div>
            <button type="submit" className="btn-gold w-full" disabled={busy}>
              {busy ? 'Forging your account…' : 'Accept & Enter'}
            </button>
          </form>
        )}
      </div>
    </PageShell>
  );
}
