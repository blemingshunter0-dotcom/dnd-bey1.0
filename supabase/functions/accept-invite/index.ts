// Supabase Edge Function: accept-invite
// Validates an invite token and creates the account with the service role
// (the recipient has no account yet, so this cannot be done from the client).
//
// Deploy:  supabase functions deploy accept-invite
// Secrets: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.
//
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'content-type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  try {
    const { token, email, password, display_name } = await req.json();
    if (!token || !password) return json({ error: 'Token and password are required.' }, 400);
    if (String(password).length < 8) return json({ error: 'Password must be at least 8 characters.' }, 400);

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } },
    );

    const { data: invite, error: invErr } = await admin
      .from('invites')
      .select('*')
      .eq('token', token)
      .maybeSingle();
    if (invErr) return json({ error: invErr.message }, 500);
    if (!invite) return json({ error: 'This invitation is not valid.' }, 400);
    if (invite.accepted_at) return json({ error: 'This invitation has already been used.' }, 400);
    if (new Date(invite.expires_at) < new Date()) return json({ error: 'This invitation has expired.' }, 400);

    const finalEmail: string | undefined = invite.email ?? email;
    if (!finalEmail) return json({ error: 'An email address is required.' }, 400);

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email: finalEmail,
      password,
      email_confirm: true,
      user_metadata: { display_name: display_name ?? '' },
    });
    if (createErr) return json({ error: createErr.message }, 400);

    await admin
      .from('invites')
      .update({ accepted_at: new Date().toISOString(), accepted_by: created.user!.id })
      .eq('id', invite.id);

    return json({ ok: true, email: finalEmail });
  } catch (e: any) {
    return json({ error: e?.message ?? String(e) }, 500);
  }
});
