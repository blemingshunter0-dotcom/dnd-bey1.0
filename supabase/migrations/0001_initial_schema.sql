-- ============================================================================
--  The Character Forge — Stage 1a: initial schema + Row-Level Security
-- ============================================================================
--  Run top-to-bottom. Safe to run in the Supabase SQL editor or via the CLI.
--  Order: extensions → enums → tables → triggers → helper fns → RLS policies.
--
--  Security model (see docs/PLAN.md §4):
--    * Global admin (Hunter)      — full read/write everywhere, campaign-independent.
--    * Campaign DM (any member)    — full edit on characters/companions/gating in
--                                    their campaign; multiple DMs per campaign allowed.
--    * Character owner             — full edit on their own sheet only.
--    * All members                 — read the ruleset + document libraries and the
--                                    rosters of campaigns they belong to.
-- ============================================================================

create extension if not exists "pgcrypto";  -- gen_random_uuid()

-- ----------------------------------------------------------------------------
--  Enums
-- ----------------------------------------------------------------------------
create type leveling_mode    as enum ('milestone', 'xp');
create type member_role      as enum ('dm', 'player');
create type content_type     as enum ('race', 'class', 'subclass', 'background', 'feat', 'spell', 'equipment', 'monster');
create type content_source   as enum ('srd', 'homebrew', 'official');   -- 'official' = non-SRD, manually transcribed
create type character_status as enum ('active', 'retired', 'deceased');
create type companion_type   as enum ('npc', 'beastmaster', 'artificer_construct', 'pet', 'familiar');
create type document_kind    as enum ('upload', 'drive_link');

-- ============================================================================
--  IDENTITY
-- ============================================================================

-- Mirrors auth.users. One row per real account; created automatically on signup.
create table profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  display_name    text not null default '',
  avatar_url      text,
  -- Senior, campaign-independent admin flag. Only Hunter is true.
  -- Bootstrapped manually after signup: update profiles set is_global_admin = true where id = '<hunter-uuid>';
  is_global_admin boolean not null default false,
  created_at      timestamptz not null default now()
);

-- Invite-link accounts (no public signup). A DM/admin creates an invite; the
-- token is emailed as a link. Token-based acceptance is handled by an Edge
-- Function with the service role in Stage 1b (bypasses RLS pre-signup).
create table invites (
  id           uuid primary key default gen_random_uuid(),
  email        text,
  token        text not null unique default encode(gen_random_bytes(24), 'hex'),
  note         text,
  invited_by   uuid references profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '14 days'),
  accepted_at  timestamptz,
  accepted_by  uuid references profiles (id) on delete set null
);

-- ============================================================================
--  CAMPAIGNS
-- ============================================================================

create table campaigns (
  id                          uuid primary key default gen_random_uuid(),
  name                        text not null,
  created_by                  uuid references profiles (id) on delete set null,
  leveling_mode               leveling_mode not null default 'milestone',
  multiclassing_allowed       boolean not null default false,
  enforce_multiclass_prereqs  boolean not null default true,
  created_at                  timestamptz not null default now()
);

-- Membership + role. Multiple 'dm' rows per campaign = multi-DM support.
create table campaign_members (
  campaign_id  uuid not null references campaigns (id) on delete cascade,
  user_id      uuid not null references profiles (id) on delete cascade,
  role         member_role not null default 'player',
  added_at     timestamptz not null default now(),
  primary key (campaign_id, user_id)
);
create index campaign_members_user_idx on campaign_members (user_id);

-- Explicit per-campaign allow/block overrides for ruleset content.
-- The DEFAULT (no row) is computed, not stored: content created on/before the
-- campaign defaults allowed; content added later defaults blocked. See
-- is_content_allowed() below. A row here is an explicit override either way.
create table campaign_content_overrides (
  campaign_id   uuid not null references campaigns (id) on delete cascade,
  content_type  content_type not null,
  content_id    uuid not null,
  allowed       boolean not null,
  primary key (campaign_id, content_type, content_id)
);

-- ============================================================================
--  RULESET LIBRARY  (feeds character creation AND the encounter bestiary)
-- ============================================================================
--  Separate table per content type for typed, queryable columns; a `data`
--  jsonb column holds the long tail of type-specific fields.
--
--  Shared columns on every content table:
--    id, name, source, is_scaffold, created_at, data
--  `is_scaffold = true` marks empty non-SRD placeholders (Artificer, Aasimar,
--  Beholder, etc.) awaiting Hunter's manual transcription.

create table content_races (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

create table content_classes (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  source         content_source not null default 'homebrew',
  is_scaffold    boolean not null default false,
  hit_die        smallint,                     -- e.g. 8 for d8
  -- Casting shape drives known-vs-prepared handling (Stage 5).
  spellcasting   text,                          -- null | 'known' | 'prepared'
  data           jsonb not null default '{}',
  created_at     timestamptz not null default now()
);

create table content_subclasses (
  id          uuid primary key default gen_random_uuid(),
  class_id    uuid not null references content_classes (id) on delete cascade,
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index content_subclasses_class_idx on content_subclasses (class_id);

create table content_backgrounds (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

create table content_feats (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);

create table content_spells (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  level       smallint,                          -- 0 = cantrip
  school      text,
  -- Which classes can access this spell (names or ids); used to build per-class lists.
  class_list  text[] not null default '{}',
  data        jsonb not null default '{}',
  created_at  timestamptz not null default now()
);
create index content_spells_level_idx on content_spells (level);

create table content_equipment (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  category    text,                              -- 'weapon' | 'armor' | 'shield' | 'gear' | 'magic' ...
  data        jsonb not null default '{}',       -- ac, damage dice, weight, properties, magic bonuses...
  created_at  timestamptz not null default now()
);

create table content_monsters (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  source      content_source not null default 'homebrew',
  is_scaffold boolean not null default false,
  cr          numeric,                           -- challenge rating
  xp          integer,
  data        jsonb not null default '{}',       -- full stat block
  created_at  timestamptz not null default now()
);
create index content_monsters_cr_idx on content_monsters (cr);

-- ============================================================================
--  CHARACTERS
-- ============================================================================

create table characters (
  id             uuid primary key default gen_random_uuid(),
  campaign_id    uuid not null references campaigns (id) on delete cascade,
  owner_id       uuid not null references profiles (id) on delete cascade,
  name           text not null default 'Unnamed',
  portrait_url   text,
  status         character_status not null default 'active',
  race_id        uuid references content_races (id) on delete set null,
  background_id  uuid references content_backgrounds (id) on delete set null,
  level          smallint not null default 1,
  ability_scores jsonb not null default '{}',    -- {str,dex,con,int,wis,cha}
  -- Live combat state (Stage 4). Kept as jsonb for fast whole-sheet updates.
  combat         jsonb not null default '{}',    -- {hp:{cur,max,temp}, death:{s,f}, conditions:[], effects:[]}
  date_of_death  date,                            -- set when status → deceased (Memorial)
  campaign_died  uuid references campaigns (id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index characters_campaign_idx on characters (campaign_id);
create index characters_owner_idx on characters (owner_id);
create index characters_status_idx on characters (status);

-- One row per class the character has levels in (multiclassing).
create table character_classes (
  id           uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters (id) on delete cascade,
  class_id     uuid references content_classes (id) on delete set null,
  subclass_id  uuid references content_subclasses (id) on delete set null,
  level        smallint not null default 1,
  is_primary   boolean not null default false,   -- first class (hit dice, starting prof)
  data         jsonb not null default '{}'
);
create index character_classes_char_idx on character_classes (character_id);

create table character_equipment (
  id           uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters (id) on delete cascade,
  equipment_id uuid references content_equipment (id) on delete set null,
  name         text,                              -- override / custom item
  equipped     boolean not null default false,
  proficient   boolean not null default false,    -- affects attack/AC math
  attuned      boolean not null default false,
  data         jsonb not null default '{}',       -- ac bonus, conditional effects, magic bonuses
  sort_order   smallint not null default 0
);
create index character_equipment_char_idx on character_equipment (character_id);

create table character_spells (
  id           uuid primary key default gen_random_uuid(),
  character_id uuid not null references characters (id) on delete cascade,
  spell_id     uuid references content_spells (id) on delete set null,
  from_class   uuid references content_classes (id) on delete set null,
  prepared     boolean not null default false,    -- for prepared casters
  always_known boolean not null default false,    -- e.g. domain/racial spells
  data         jsonb not null default '{}'
);
create index character_spells_char_idx on character_spells (character_id);

-- ============================================================================
--  COMPANIONS  (DM-only; full stat block; excluded from Party Export)
-- ============================================================================

create table companions (
  id                  uuid primary key default gen_random_uuid(),
  campaign_id         uuid not null references campaigns (id) on delete cascade,
  created_by          uuid references profiles (id) on delete set null,
  name                text not null default 'Companion',
  ctype               companion_type not null default 'npc',
  -- Optional links: to a player (ownership) and/or a character (stat scaling).
  linked_player_id    uuid references profiles (id) on delete set null,
  linked_character_id uuid references characters (id) on delete set null,
  stat_block          jsonb not null default '{}',   -- full skill list + abilities
  created_at          timestamptz not null default now()
);
create index companions_campaign_idx on companions (campaign_id);

-- ============================================================================
--  DOCUMENT LIBRARY  (one shared library across ALL campaigns)
-- ============================================================================

create table documents (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  kind          document_kind not null,
  storage_path  text,                              -- for kind = 'upload' (Supabase Storage)
  drive_url     text,                              -- for kind = 'drive_link'
  tags          text[] not null default '{}',      -- category tags
  uploaded_by   uuid references profiles (id) on delete set null,
  created_at    timestamptz not null default now()
);
create index documents_tags_idx on documents using gin (tags);

-- ============================================================================
--  TRIGGERS
-- ============================================================================

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- When a campaign is created, make its creator a DM automatically. Runs as
-- definer so it bypasses the campaign_members RLS insert policy (avoids a
-- chicken-and-egg bootstrap where the creator isn't yet a DM).
create or replace function public.handle_new_campaign()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is not null then
    insert into public.campaign_members (campaign_id, user_id, role)
    values (new.id, new.created_by, 'dm')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

create trigger on_campaign_created
  after insert on campaigns
  for each row execute function public.handle_new_campaign();

-- Prevent a logged-in NON-admin from granting themselves is_global_admin.
-- The trusted service-role / SQL-editor context (auth.uid() is null) is allowed,
-- so Hunter can be bootstrapped with a one-off UPDATE; existing admins may also
-- change it. Only a regular authenticated non-admin caller is blocked.
create or replace function public.guard_admin_flag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.is_global_admin is distinct from old.is_global_admin
     and auth.uid() is not null
     and not coalesce((select is_global_admin from profiles where id = auth.uid()), false) then
    raise exception 'only a global admin may change is_global_admin';
  end if;
  return new;
end;
$$;

create trigger guard_profiles_admin_flag
  before update on profiles
  for each row execute function public.guard_admin_flag();

-- keep characters.updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
create trigger characters_touch_updated_at
  before update on characters
  for each row execute function public.touch_updated_at();

-- ============================================================================
--  HELPER FUNCTIONS  (SECURITY DEFINER — bypass RLS to avoid policy recursion)
-- ============================================================================

create or replace function public.is_global_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_global_admin from profiles where id = auth.uid()), false);
$$;

create or replace function public.is_campaign_member(p_campaign uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from campaign_members
    where campaign_id = p_campaign and user_id = auth.uid()
  );
$$;

create or replace function public.is_campaign_dm(p_campaign uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from campaign_members
    where campaign_id = p_campaign and user_id = auth.uid() and role = 'dm'
  );
$$;

create or replace function public.can_view_character(p_char uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from characters c
    where c.id = p_char
      and (public.is_global_admin() or public.is_campaign_member(c.campaign_id))
  );
$$;

create or replace function public.can_edit_character(p_char uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from characters c
    where c.id = p_char
      and (public.is_global_admin()
           or c.owner_id = auth.uid()
           or public.is_campaign_dm(c.campaign_id))
  );
$$;

-- created_at of a ruleset item, resolved across the per-type tables.
create or replace function public.content_created_at(p_type content_type, p_id uuid)
returns timestamptz language sql stable security definer set search_path = public as $$
  select case p_type
    when 'race'       then (select created_at from content_races       where id = p_id)
    when 'class'      then (select created_at from content_classes     where id = p_id)
    when 'subclass'   then (select created_at from content_subclasses  where id = p_id)
    when 'background' then (select created_at from content_backgrounds where id = p_id)
    when 'feat'       then (select created_at from content_feats       where id = p_id)
    when 'spell'      then (select created_at from content_spells      where id = p_id)
    when 'equipment'  then (select created_at from content_equipment   where id = p_id)
    when 'monster'    then (select created_at from content_monsters    where id = p_id)
  end;
$$;

-- Effective allow/block for a piece of content in a campaign:
--   explicit override if present, else default by creation-time comparison.
create or replace function public.is_content_allowed(p_campaign uuid, p_type content_type, p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select allowed from campaign_content_overrides
       where campaign_id = p_campaign and content_type = p_type and content_id = p_id),
    (public.content_created_at(p_type, p_id) <= (select created_at from campaigns where id = p_campaign))
  );
$$;

-- ============================================================================
--  ROW-LEVEL SECURITY
-- ============================================================================

alter table profiles                   enable row level security;
alter table invites                    enable row level security;
alter table campaigns                  enable row level security;
alter table campaign_members           enable row level security;
alter table campaign_content_overrides enable row level security;
alter table content_races              enable row level security;
alter table content_classes            enable row level security;
alter table content_subclasses         enable row level security;
alter table content_backgrounds        enable row level security;
alter table content_feats              enable row level security;
alter table content_spells             enable row level security;
alter table content_equipment          enable row level security;
alter table content_monsters           enable row level security;
alter table characters                 enable row level security;
alter table character_classes          enable row level security;
alter table character_equipment        enable row level security;
alter table character_spells           enable row level security;
alter table companions                 enable row level security;
alter table documents                  enable row level security;

-- ---- profiles -------------------------------------------------------------
create policy profiles_read on profiles
  for select to authenticated using (true);           -- closed group: all members visible
create policy profiles_update_self on profiles
  for update to authenticated
  using (id = auth.uid() or public.is_global_admin())
  with check (id = auth.uid() or public.is_global_admin());  -- admin-flag change guarded by trigger

-- ---- invites (global admin only; token acceptance via Edge Function) ------
create policy invites_admin_all on invites
  for all to authenticated
  using (public.is_global_admin())
  with check (public.is_global_admin());

-- ---- campaigns ------------------------------------------------------------
create policy campaigns_read on campaigns
  for select to authenticated
  using (public.is_global_admin() or public.is_campaign_member(id));
create policy campaigns_insert on campaigns
  for insert to authenticated
  with check (created_by = auth.uid() or public.is_global_admin());
create policy campaigns_update on campaigns
  for update to authenticated
  using (public.is_global_admin() or public.is_campaign_dm(id))
  with check (public.is_global_admin() or public.is_campaign_dm(id));
create policy campaigns_delete on campaigns
  for delete to authenticated
  using (public.is_global_admin() or public.is_campaign_dm(id));

-- ---- campaign_members -----------------------------------------------------
create policy members_read on campaign_members
  for select to authenticated
  using (public.is_global_admin() or public.is_campaign_member(campaign_id));
create policy members_write on campaign_members
  for all to authenticated
  using (public.is_global_admin() or public.is_campaign_dm(campaign_id))
  with check (public.is_global_admin() or public.is_campaign_dm(campaign_id));

-- ---- campaign_content_overrides ------------------------------------------
create policy overrides_read on campaign_content_overrides
  for select to authenticated
  using (public.is_global_admin() or public.is_campaign_member(campaign_id));
create policy overrides_write on campaign_content_overrides
  for all to authenticated
  using (public.is_global_admin() or public.is_campaign_dm(campaign_id))
  with check (public.is_global_admin() or public.is_campaign_dm(campaign_id));

-- ---- ruleset library: readable by all members, writable by global admin ---
--  (Homebrew/official content is curated by Hunter; DMs gate via overrides.)
do $$
declare t text;
begin
  foreach t in array array[
    'content_races','content_classes','content_subclasses','content_backgrounds',
    'content_feats','content_spells','content_equipment','content_monsters'
  ] loop
    execute format('create policy %I_read on %I for select to authenticated using (true);', t, t);
    execute format('create policy %I_write on %I for all to authenticated using (public.is_global_admin()) with check (public.is_global_admin());', t, t);
  end loop;
end $$;

-- ---- characters -----------------------------------------------------------
create policy characters_read on characters
  for select to authenticated
  using (public.is_global_admin() or public.is_campaign_member(campaign_id));
create policy characters_insert on characters
  for insert to authenticated
  with check (public.is_global_admin()
              or (owner_id = auth.uid() and public.is_campaign_member(campaign_id)));
create policy characters_update on characters
  for update to authenticated
  using (public.is_global_admin() or owner_id = auth.uid() or public.is_campaign_dm(campaign_id))
  with check (public.is_global_admin() or owner_id = auth.uid() or public.is_campaign_dm(campaign_id));
create policy characters_delete on characters
  for delete to authenticated
  using (public.is_global_admin() or owner_id = auth.uid() or public.is_campaign_dm(campaign_id));

-- ---- character child tables (mirror parent character access) --------------
do $$
declare t text;
begin
  foreach t in array array['character_classes','character_equipment','character_spells'] loop
    execute format('create policy %I_read on %I for select to authenticated using (public.can_view_character(character_id));', t, t);
    execute format('create policy %I_write on %I for all to authenticated using (public.can_edit_character(character_id)) with check (public.can_edit_character(character_id));', t, t);
  end loop;
end $$;

-- ---- companions (DM-only writes; members read) ----------------------------
create policy companions_read on companions
  for select to authenticated
  using (public.is_global_admin() or public.is_campaign_member(campaign_id));
create policy companions_write on companions
  for all to authenticated
  using (public.is_global_admin() or public.is_campaign_dm(campaign_id))
  with check (public.is_global_admin() or public.is_campaign_dm(campaign_id));

-- ---- documents (shared library: all read; uploader/admin manage) ----------
create policy documents_read on documents
  for select to authenticated using (true);
create policy documents_insert on documents
  for insert to authenticated with check (uploaded_by = auth.uid() or public.is_global_admin());
create policy documents_modify on documents
  for update to authenticated
  using (uploaded_by = auth.uid() or public.is_global_admin())
  with check (uploaded_by = auth.uid() or public.is_global_admin());
create policy documents_delete on documents
  for delete to authenticated
  using (uploaded_by = auth.uid() or public.is_global_admin());

-- ============================================================================
--  End of Stage 1a migration.
-- ============================================================================
