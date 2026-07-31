-- Canonical Supabase CLI migration for performance-v1-remove-redundant-indexes.sql.
-- Retained unique indexes continue to enforce every affected business rule.

drop index if exists public.member_sections_unique_idx;
drop index if exists public.society_members_society_person_unique_idx;
drop index if exists public.people_user_id_unique_idx;
drop index if exists public.society_fee_month_rule_lookup_idx;
drop index if exists public.society_email_attempts_outbox_idx;
