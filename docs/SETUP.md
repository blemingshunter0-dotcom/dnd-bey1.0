# Setup Checklist — standing up The Character Forge

One-time setup to take the app from "builds" to "live and logged in." ~10 minutes.
Do the steps in order. You only ever do this once.

---

## 1. Create the Supabase project

1. Go to <https://supabase.com> → sign in → **New project**.
2. Name it (e.g. `character-forge`), pick a region near the group, set a strong
   database password (save it somewhere), Free plan.
3. Wait ~2 minutes for it to provision.

---

## 2. Run the database schema

1. In the project: **SQL Editor** → **New query**.
2. Open `supabase/migrations/0001_initial_schema.sql` from this repo, copy the
   **entire** file, paste it in, and click **Run**.
3. You should see success with no errors. This creates every table, the security
   policies, and the helper functions.

---

## 3. Grab your API keys

**Settings → API**:

| Value | Where it goes |
|-------|---------------|
| **Project URL** (aka "API URL") — `https://<ref>.supabase.co` — use the **base**, drop any `/rest/v1/` | `VITE_SUPABASE_URL` |
| **`anon` / `public`** key (`eyJ...`) | `VITE_SUPABASE_ANON_KEY` |

> ⚠️ Never put the **`service_role`** / secret key in the app. It bypasses all
> security. Only the `anon` key belongs in the frontend.

---

## 4. Deploy the invite Edge Function

Needs the [Supabase CLI](https://supabase.com/docs/guides/cli) installed.

```bash
supabase login
supabase link --project-ref <your-project-ref>   # the <ref> from your URL
supabase functions deploy accept-invite
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically — no
manual secrets. This function is what lets invited players create their accounts.

---

## 5. Configure Netlify (the live site)

1. Netlify → **Add new site → Import from Git** → pick this repo/branch.
2. Build settings are already in `netlify.toml` (build `npm run build`, publish `dist`).
3. **Site configuration → Environment variables** → add both:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`
4. **Trigger a redeploy** (these are baked in at build time, so a rebuild is
   required after adding them).

Local dev (optional): copy `.env.example` to `.env` and paste the same two values.

---

## 6. Create the first admin (Hunter)

There's a deliberate chicken-and-egg: invites are created *by* an admin, so the
very first account can't be invited. Bootstrap it directly:

1. Supabase → **Authentication → Users → Add user** → enter Hunter's email + a
   password → **Create user** (tick "Auto Confirm" if shown).
2. Supabase → **SQL Editor** → run:

   ```sql
   update profiles set is_global_admin = true
   where id = (select id from auth.users where email = 'hunter@example.com');
   ```

   (Use Hunter's real email.) This is allowed from the SQL Editor even though the
   app blocks self-promotion.
3. Log in to the deployed site with those credentials. You'll see the **Keeper**
   badge and the invite panel.

---

## 7. Invite the rest of the group

From the dashboard (as Hunter):

1. **Invitations** panel → optionally add an email/note → **New Invite**.
2. **Copy link** → send it to Keane / Ethan / Holden.
3. They open the link, set their own display name + password, and they're in.

---

## Done

At this point cross-device login, invite-only accounts, and the admin role are all
live. The next build slice (Stage 1c) adds campaigns, DM assignment, content
allow/block, and the portrait-only roster.

### Troubleshooting

- **Login page says "Backend not configured"** → the `VITE_SUPABASE_*` env vars
  aren't set in the current build. Add them and redeploy.
- **Invite link errors** → make sure the `accept-invite` function is deployed
  (step 4) and the schema ran (step 2).
- **Can't see the invite panel** → your account isn't admin yet; re-run step 6's SQL.
