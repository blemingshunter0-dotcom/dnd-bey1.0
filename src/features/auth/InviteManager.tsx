import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '@/lib/supabase';
import type { Invite } from '@/types';

const inviteLink = (token: string) => `${window.location.origin}/invite/${token}`;

/** Admin-only: generate invite links (no public signup) and see pending ones. */
export function InviteManager() {
  const qc = useQueryClient();
  const [email, setEmail] = useState('');
  const [note, setNote] = useState('');
  const [copied, setCopied] = useState<string | null>(null);

  const { data: invites, isLoading } = useQuery({
    queryKey: ['invites'],
    queryFn: async (): Promise<Invite[]> => {
      const { data, error } = await supabase!
        .from('invites')
        .select('*')
        .order('created_at', { ascending: false });
      if (error) throw error;
      return data as Invite[];
    },
  });

  const create = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase!
        .from('invites')
        .insert({ email: email.trim() || null, note: note.trim() || null })
        .select()
        .single();
      if (error) throw error;
      return data as Invite;
    },
    onSuccess: () => {
      setEmail('');
      setNote('');
      qc.invalidateQueries({ queryKey: ['invites'] });
    },
  });

  async function copy(token: string) {
    await navigator.clipboard.writeText(inviteLink(token));
    setCopied(token);
    setTimeout(() => setCopied((c) => (c === token ? null : c)), 1500);
  }

  const pending = (invites ?? []).filter((i) => !i.accepted_at);

  return (
    <section className="panel p-6">
      <h2 className="text-xl">Invitations</h2>
      <p className="mt-1 text-sm text-parchment-300">
        Generate a link and share it with a player. They set their own password on arrival.
      </p>

      <div className="mt-4 grid gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
        <div>
          <label className="label" htmlFor="inv-email">Email (optional)</label>
          <input id="inv-email" className="input" value={email}
            onChange={(e) => setEmail(e.target.value)} placeholder="player@email" />
        </div>
        <div>
          <label className="label" htmlFor="inv-note">Note (optional)</label>
          <input id="inv-note" className="input" value={note}
            onChange={(e) => setNote(e.target.value)} placeholder="e.g. Keane" />
        </div>
        <button className="btn-gold" onClick={() => create.mutate()} disabled={create.isPending}>
          {create.isPending ? 'Forging…' : 'New Invite'}
        </button>
      </div>
      {create.isError && (
        <p className="mt-2 form-error">{(create.error as Error).message}</p>
      )}

      <div className="rule-ornament" />

      {isLoading ? (
        <p className="text-sm text-parchment-300">Loading…</p>
      ) : pending.length === 0 ? (
        <p className="text-sm text-parchment-300">No pending invitations.</p>
      ) : (
        <ul className="space-y-2">
          {pending.map((inv) => (
            <li key={inv.id}
              className="flex flex-wrap items-center justify-between gap-2 rounded-sm border border-gold-500/20 bg-ink-950/40 px-3 py-2">
              <div className="min-w-0">
                <p className="truncate text-sm text-parchment-100">
                  {inv.email || inv.note || 'Open invite'}
                </p>
                <p className="truncate font-mono text-xs text-parchment-300">{inviteLink(inv.token)}</p>
              </div>
              <button className="btn-blood shrink-0 px-3 py-1 text-xs" onClick={() => copy(inv.token)}>
                {copied === inv.token ? 'Copied ✓' : 'Copy link'}
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
