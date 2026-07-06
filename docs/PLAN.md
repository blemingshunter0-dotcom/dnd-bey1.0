# D&D Character Creator — Implementation Plan

> Working title: **dnd-bey** (D&D Beyond replacement). Private tool for a group of 4
> (Hunter, Keane, Ethan, Holden). D&D 5e (2024 rules). Not commercial.

This document is the agreed plan **before any application code is written**. It covers the
stack, architecture, data model, security model, seed-data strategy, and a stage-by-stage
build order with concrete deliverables and acceptance criteria for each stage.

---

## 1. Confirmed decisions

| Area | Decision | Reasoning |
|------|----------|-----------|
| **Backend** | **Supabase** (Postgres + Auth + Storage + Edge Functions) | Data is deeply relational (many-to-many campaign/DM/content-gating); permission model maps 1:1 to Row-Level Security; flat, generous free tier; SRD data is tabular. |
| **Frontend** | **React + TypeScript + Vite** | Heavy D&D rules modeling benefits from static types; fast static build for Netlify. |
| **Hosting** | **Netlify** free tier (static SPA) | Matches the group's existing project pattern. |
| **Styling** | Tailwind CSS | Fast iteration, consistent design tokens. |
| **Data fetching** | TanStack Query | Caching + optimistic updates for live combat tracking. |
| **Local state** | Zustand | Combat tracker / sheet-editing local state. |
| **Routing** | React Router | |
| **Testing** | Vitest (unit, esp. `lib/rules/`) + Playwright (a few E2E smoke tests) | Rules math must be correct and regression-proof. |

### Cost model (all free tier)

- **Supabase free**: 500 MB DB, 1 GB storage, 50k monthly active auth users, 2 GB egress. 4 users use a tiny fraction.
- **Netlify free**: 100 GB bandwidth, plenty of build minutes.
- **Known caveat — Supabase project pause**: free projects pause after ~7 days of no activity and cold-start on the next request. Mitigation: a scheduled keep-warm ping (see Stage 0). Documented so it is never a surprise.

---

## 2. Architecture overview

```
Browser (React SPA on Netlify)
   │  supabase-js  (auth JWT attached to every request)
   ▼
Supabase
   ├── Auth            (email/password, invite-only, no public signup)
   ├── Postgres        (all app data; RLS enforces every permission rule)
   ├── Storage         (uploaded homebrew PDFs, character portraits)
   └── Edge Functions  (bulk import validation, keep-warm ping)
```

**Security posture:** there is no custom API server. The React client talks directly to
Supabase, and **every access rule is enforced by Postgres RLS**, so a malicious client
cannot read or write anything the policies forbid. This is the standard Supabase model and
is why the relational + RLS fit matters so much for this spec.

### Directory layout

```
dnd-bey1.0/
├── docs/
│   └── PLAN.md                      # this file
├── src/
│   ├── main.tsx, App.tsx, router.tsx
│   ├── lib/
│   │   ├── supabase.ts              # client init
│   │   └── rules/                   # PURE D&D math — no I/O, fully unit-tested
│   │       ├── abilityScores.ts     # modifiers, standard array
│   │       ├── proficiency.ts       # proficiency bonus by level
│   │       ├── ac.ts                # AC + equipment/proficiency calc
│   │       ├── actionEconomy.ts     # actions/bonus/reactions by class+level
│   │       ├── spellcasting.ts      # slot tables, save DC, known vs prepared
│   │       ├── multiclass.ts        # prereqs + toggle handling
│   │       ├── dpr.ts               # damage-per-round (party export)
│   │       └── encounterMath.ts     # XP thresholds easy/med/hard/deadly
│   ├── features/
│   │   ├── auth/                    # login, invite acceptance
│   │   ├── campaigns/               # CRUD, DM assignment, content gating UI
│   │   ├── characters/             # creation wizard, sheet, combat tracker
│   │   ├── companions/             # stat-block editor, type-based scaling
│   │   ├── ruleset/                # library browser, single + bulk import
│   │   ├── encounter/             # encounter builder
│   │   ├── partyExport/           # plain-text summary generator
│   │   ├── documents/             # doc library (upload + Drive links)
│   │   └── memorial/              # cross-campaign memorial page
│   ├── components/                 # shared UI primitives
│   ├── hooks/                       # shared React hooks
│   ├── types/                       # shared TS domain types
│   └── stores/                      # Zustand stores
├── supabase/
│   ├── migrations/                # versioned SQL: schema + RLS policies
│   ├── seed/
│   │   ├── srd/                    # SRD 5.2 CC-BY-4.0 seed data
│   │   └── homebrew/              # group's own content
│   └── functions/                 # edge fns: bulk-import, keep-warm
├── scripts/
│   └── import-templates/          # CSV templates per content type
├── public/                         # static assets
├── netlify.toml
├── .env.example                    # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY
├── package.json, tsconfig.json, tailwind.config.ts, vite.config.ts
└── README.md                       # setup + CC-BY-4.0 attribution
```

**Two deliberate design choices:**
1. `src/lib/rules/` is **pure functions, no backend calls** — all D&D math lives there,
   unit-tested in isolation, and reused by the character sheet, party export, and encounter builder.
2. **Feature folders mirror the staged build order** below, so each stage is a self-contained slice.

---

## 3. Data model

Postgres schema. `auth.users` is Supabase-managed; everything else is app tables.
Names are illustrative and will be finalized in the first migration.

### Identity & membership
- **`profiles`** — `id (=auth.users.id)`, `display_name`, `is_global_admin (bool)`, `avatar_url`.
  Hunter's row has `is_global_admin = true`. This is the senior, campaign-independent admin flag.
- **`invites`** — `email`, `token`, `invited_by`, `accepted_at`. Powers invite-only signup.

### Campaigns
- **`campaigns`** — `id`, `name`, `created_at`, `leveling_mode ('milestone'|'xp')`,
  `multiclassing_allowed (bool)`, `enforce_multiclass_prereqs (bool)`.
- **`campaign_members`** — `campaign_id`, `user_id`, `role ('dm'|'player')`.
  Composite membership. **Multiple `dm` rows per campaign are allowed** → multi-DM support.
- **`campaign_content_overrides`** — `campaign_id`, `content_type`, `content_id`, `allowed (bool)`.
  Explicit per-campaign allow/block entries. **Default rule computed, not stored:** content with
  `created_at <= campaign.created_at` defaults allowed; content added later defaults blocked;
  a row here is an explicit override either way. This cleanly implements the spec's gating rule.

### Ruleset library (feeds both character creation and the bestiary)
- **`content_races`**, **`content_classes`**, **`content_subclasses`** (FK → class),
  **`content_backgrounds`**, **`content_feats`**, **`content_spells`**, **`content_equipment`**,
  **`content_monsters`** — each with the fields that content type needs. Shared columns:
  `id`, `name`, `source ('srd'|'homebrew'|'official-manual')`, `is_scaffold (bool)`, `created_at`, `data (jsonb)`.
  - `source` + attribution supports the CC-BY-4.0 requirement and distinguishes SRD vs homebrew vs manually-transcribed.
  - `is_scaffold = true` marks empty non-SRD placeholders (Artificer, Aasimar, etc.) awaiting Hunter's transcription.
  - Structured columns for the fields we query/filter on (e.g. spell `level`, `school`, class list);
    `data (jsonb)` for the long tail of type-specific fields — keeps the schema lean while staying queryable.

### Characters
- **`characters`** — `id`, `campaign_id`, `owner_id`, `name`, `portrait_url`,
  `status ('active'|'retired'|'deceased')`, `race_id`, `background_id`,
  `ability_scores (jsonb)`, `level`, `date_of_death (nullable)`.
- **`character_classes`** — `character_id`, `class_id`, `subclass_id`, `level`. One row per class → multiclassing.
- **`character_equipment`** — `character_id`, `equipment_id` (or inline), `equipped (bool)`,
  `proficient (bool)`, `attuned (bool)`, `conditional_notes`. Drives live AC math.
- **`character_spells`** — `character_id`, `spell_id`, `known_or_prepared`, `prepared (bool)`.
- **Combat state (jsonb or dedicated columns)** — current/max/temp HP, death-save successes/failures,
  active conditions (list of condition ids), active effects (list of `{name, note, on}`).

### Companions
- **`companions`** — `id`, `campaign_id`, `created_by (dm)`, `linked_player_id (nullable)`,
  `type ('npc'|'beastmaster'|'artificer_construct'|'pet'|'familiar')`,
  `linked_character_id (nullable, for scaling)`, `stat_block (jsonb — full skill list)`.
  Type drives which fields render and which stats auto-calculate off the linked character.

### Documents & memorial
- **`documents`** — `id`, `title`, `kind ('upload'|'drive_link')`, `storage_path (nullable)`,
  `drive_url (nullable)`, `tags (text[])`, `uploaded_by`. **One shared library across all campaigns.**
- Memorial is a **query**, not a table: `characters WHERE status='deceased'` across all campaigns.

---

## 4. Security model (RLS policies)

Every table gets RLS enabled. Core policy set:

- **Global admin (Hunter):** a `SELECT`/`ALL` policy allowing rows when
  `profiles.is_global_admin` is true for the requester — grants full read/write everywhere,
  independent of any DM role.
- **Campaign visibility:** users can read campaigns they are a member of (`campaign_members`).
- **DM edit rights:** users with a `dm` membership row on a campaign can edit any character,
  companion, and content-gating row **in that campaign**.
- **Character owner:** owner can edit their own character; no other non-DM/non-admin can.
- **Roster privacy:** enforced at the query/view layer — the roster query selects only
  `portrait_url, name, status`; the full-sheet query (on portrait click) is a separate read
  gated by the policies above. (Light privacy layer per the spec, not airtight security.)
- **Ruleset & document library:** readable by all authenticated members; writable by global admin
  (and, where the spec allows, DMs) only.

Policies are written as SQL in `supabase/migrations/` and reviewed as a unit in Stage 1.

---

## 5. Seed-data strategy (SRD 5.2 + homebrew)

- **SRD 5.2 (CC-BY-4.0):** parsed from the openly-licensed SRD into structured JSON/CSV under
  `supabase/seed/srd/` and loaded via a seed script. Covers most core spells, classes/subclasses,
  feats, weapons, equipment, and many monsters. A short CC-BY-4.0 attribution line (taken verbatim
  from the SRD document) ships in the app footer / About page — the license's only real requirement.
- **Homebrew** (Rattlesnake Monk, Gunslinger Conclave, Powder Monkey, Hexsmith, etc.): pre-loaded in
  full under `supabase/seed/homebrew/`, since the group owns it outright.
- **Non-SRD official** (Artificer + subclasses, Aasimar/Beholder/Mind Flayer, splatbook material):
  loaded as **scaffold rows** (`is_scaffold = true`) so they appear as known gaps for Hunter to fill
  via the bulk import tool. **No proprietary WotC text is transcribed by the build** — Hunter enters
  that himself from books he owns.

---

## 6. Staged build order

Mirrors the spec's suggested order. Each stage ends at a reviewable checkpoint.

### Stage 0 — Project scaffolding *(prerequisite, not in the spec's list)*
- Vite + React + TS + Tailwind + Router + TanStack Query + Zustand + Vitest set up.
- Supabase project connection, `.env.example`, `netlify.toml`, CI-friendly scripts.
- Keep-warm scheduled Edge Function (mitigates the free-tier pause).
- **Acceptance:** app builds, deploys to Netlify, connects to Supabase, empty shell renders.

### Stage 1 — Foundation
- Auth (email/password), invite-only account creation, cross-device login.
- Campaign CRUD, DM assignment (multi-DM), the content allow/block UI + gating rule.
- Basic character shell: portrait, name, race/class selection (no stats yet).
- Roster privacy view (portrait + name only; click → sheet).
- Full RLS policy set written and tested.
- **Acceptance:** log in from two devices; create a campaign; assign a DM; block a class and
  confirm it's hidden in creation; roster shows only portrait + name.

### Stage 2 — SRD pre-population + bulk import tool
- Load SRD 5.2 content; scaffold rows for non-SRD; CC-BY attribution in-app.
- Bulk import: CSV template per content type + structured paste box + duplicate/clone existing entry.
- Single-entry form retained for one-offs.
- **Acceptance:** SRD spells/classes/etc. visible in library; import a CSV of test entries;
  clone an existing weapon into a reskin.

### Stage 3 — Core character creation
- Full flow: race → class → subclass → background → feats → ability scores → skills → equipment → spells.
- Standard array + rolled/manual entry.
- Equipment with live AC math, proficiency toggle per item, magic bonuses, attunement.
- **Acceptance:** build a level-1 character end to end; AC recalculates live as equipment/proficiency changes.

### Stage 4 — Leveling & combat tracking
- Levels 1–20; action-economy display (Actions / Bonus / Reactions at current level).
- Multiclassing honoring the two campaign toggles.
- HP (current/max/temp), death saves, smart conditions tracker (with plain-language effects, no auto-apply),
  active effects tracker (manual toggle + note).
- **Acceptance:** level a character to 5; multiclass respecting toggles; run through combat trackers.

### Stage 5 — Spellcasting
- Known vs prepared handling; browsable per-class spell list; prepare/swap; spell slots; save DC on sheet.
- **Acceptance:** a Wizard (prepared) and a Sorcerer (known) both behave correctly; slots + DC display.

### Stage 6 — Companions
- DM-only companion sheets as full stat blocks (complete skill list).
- Type selector (NPC / Beast Master / Artificer construct / pet / familiar) drives fields +
  auto-scaling off a linked player where the rules call for it.
- **Acceptance:** DM adds a Beast Master companion linked to a Ranger; scaled stats compute; excluded from export.

### Stage 7 — Encounter Builder & Party Export
- Encounter Builder pulls only from the bestiary; standard XP-threshold difficulty math.
- Party Export: plain-text, paste-ready; per-character AC/HP/passive Perception/saves/DPR/speed/defenses/save DC;
  party rollup (avg AC, total DPR, level, size); **companions excluded**.
- **Acceptance:** build an encounter and get easy/med/hard/deadly; generate a party export block.

### Stage 8 — Document Library & Memorial
- Shared doc library with category tags; per-doc upload **or** Google Drive link; opens in new tab.
- Memorial page across all campaigns (portrait, name, date of death, campaign).
- **Acceptance:** upload a homebrew PDF and add a Drive link; mark a character deceased → appears in Memorial.

### Stage 9 — Ruleset editor refinements
- Ongoing polish for adding/editing content going forward.

---

## 7. Decisions & remaining questions

**Decided:**
- **Visual design:** custom **gothic fantasy** theme (dark parchment/candlelit palette, serif display
  type, ornamental framing) — *not* modeled on the group's Batman dashboard. Design tokens live in
  Tailwind config so the whole app stays consistent.
- **Invite mechanism:** **invite links** — Hunter generates a link/token that creates an account on
  acceptance. No public signup.

**Non-blocking, can default:**
1. **Portrait uploads** — Supabase Storage (default) vs. link out like documents. Default: Storage.
2. **SRD source file** — I'll pull the SRD 5.2 CC-BY-4.0 dataset for seeding. (No proprietary text included.)

## 7a. Usage-budget working agreement

To avoid getting stranded mid-build against Claude usage limits, every turn ends at a
**committed, working checkpoint**: the repo always builds and deploys. Large stages are split
into smaller reviewable slices. Stopping after any turn loses no committed work.

---

*Attribution note to ship in-app:* the SRD 5.2 material is © Wizards of the Coast, used under
CC-BY-4.0; the exact attribution string from the SRD document will appear in the app footer/About page.
