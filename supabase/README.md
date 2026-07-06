# Supabase — schema, policies, seed data

This folder holds everything that lives in the Supabase backend:

```
supabase/
├── migrations/   # versioned SQL — schema + Row-Level Security
├── seed/         # SRD 5.2 + homebrew content (loaded in Stage 2)
└── functions/    # Edge Functions — invite acceptance, keep-warm (later stages)
```

## One-time setup

1. Create a free project at <https://supabase.com>.
2. Open **SQL Editor** → paste and run **`migrations/0001_initial_schema.sql`**.
   It's idempotent-safe to read but run it once on a fresh project.
3. Grab **Project Settings → API** → `Project URL` and `anon public` key,
   and put them in the app's `.env` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`).

## Bootstrap Hunter as global admin

After Hunter has signed up (so his `auth.users` / `profiles` row exists), run once
in the SQL Editor:

```sql
update profiles set is_global_admin = true
where id = (select id from auth.users where email = 'hunter@example.com');
```

The `guard_admin_flag` trigger blocks a logged-in non-admin from doing this from
the app, but allows it from the SQL Editor (service-role context). This is the only
manual admin step.

## What `0001_initial_schema.sql` sets up

- **Identity:** `profiles` (auto-created on signup via trigger), `invites`.
- **Campaigns:** `campaigns`, `campaign_members` (multi-DM), `campaign_content_overrides`.
- **Ruleset library:** `content_races/classes/subclasses/backgrounds/feats/spells/equipment/monsters`.
- **Characters:** `characters` + `character_classes/equipment/spells`.
- **Companions** and the shared **documents** library.
- **Helper functions:** `is_global_admin`, `is_campaign_member`, `is_campaign_dm`,
  `can_view/edit_character`, and `is_content_allowed` (the default-block-vs-allow gating rule).
- **Row-Level Security** on every table, enforcing: global admin = full access;
  campaign DMs edit within their campaign; owners edit their own sheet; all members
  read the shared libraries and their campaign rosters.

The schema and every policy above were validated against a local Postgres 16
instance (10/10 access-control assertions passing) before commit.
