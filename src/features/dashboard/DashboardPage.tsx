import { useAuth } from '@/features/auth/AuthProvider';
import { PageShell } from '@/components/PageShell';
import { InviteManager } from '@/features/auth/InviteManager';

export function DashboardPage() {
  const { profile, isAdmin, signOut } = useAuth();

  return (
    <PageShell
      actions={
        <>
          <span className="hidden font-display text-xs uppercase tracking-widest text-parchment-300 sm:inline">
            {profile?.display_name}
            {isAdmin && <span className="ml-2 text-gold-400">· Keeper</span>}
          </span>
          <button className="btn-blood px-3 py-1 text-xs" onClick={() => void signOut()}>
            Depart
          </button>
        </>
      }
    >
      <section className="text-center">
        <p className="font-display text-xs uppercase tracking-[0.35em] text-gold-400">
          The hearth is lit
        </p>
        <h1 className="mt-3 text-3xl font-bold">Welcome, {profile?.display_name || 'traveler'}</h1>
        <p className="mx-auto mt-3 max-w-xl text-parchment-200">
          Your campaigns and characters will gather here. Campaign creation and the
          roster arrive in the next slice (Stage&nbsp;1c).
        </p>
        <div className="rule-ornament" />
      </section>

      {isAdmin && (
        <div className="mx-auto max-w-2xl">
          <InviteManager />
        </div>
      )}
    </PageShell>
  );
}
