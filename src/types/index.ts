// Shared domain types mirroring the Postgres schema (supabase/migrations).

export interface Profile {
  id: string;
  display_name: string;
  avatar_url: string | null;
  is_global_admin: boolean;
  created_at: string;
}

export interface Invite {
  id: string;
  email: string | null;
  token: string;
  note: string | null;
  invited_by: string | null;
  created_at: string;
  expires_at: string;
  accepted_at: string | null;
  accepted_by: string | null;
}

export type LevelingMode = 'milestone' | 'xp';
export type MemberRole = 'dm' | 'player';

export interface Campaign {
  id: string;
  name: string;
  created_by: string | null;
  leveling_mode: LevelingMode;
  multiclassing_allowed: boolean;
  enforce_multiclass_prereqs: boolean;
  created_at: string;
}
