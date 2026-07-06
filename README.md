# The Character Forge

A private, gothic-fantasy **D&D 5e (2024 rules)** character creator and campaign
manager for a group of four. Replaces D&D Beyond for our own table — homebrew-first,
multi-campaign, no monetization.

See [`docs/PLAN.md`](docs/PLAN.md) for the full architecture, data model, security
model, and staged build order.

## Stack

- **Frontend:** React + TypeScript + Vite + Tailwind CSS (gothic-fantasy theme)
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions), secured by Row-Level Security
- **Hosting:** Netlify (static SPA)

## Local development

```bash
npm install
cp .env.example .env   # fill in Supabase URL + anon key (optional until Stage 1)
npm run dev
```

The app builds and runs without Supabase configured — it shows a Stage 0 status shell.

```bash
npm run build    # type-check + production build
npm run test     # unit tests (rules math)
```

## Deployment (Netlify)

Connect the repo, set build command `npm run build` and publish dir `dist`
(already in `netlify.toml`), and add the two `VITE_SUPABASE_*` environment
variables in the Netlify dashboard.

## Attribution

This product includes material from the System Reference Document 5.2 ("SRD 5.2")
by Wizards of the Coast LLC, available under the
[Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/legalcode).

No proprietary (non-SRD) Wizards of the Coast text is included in this repository.
