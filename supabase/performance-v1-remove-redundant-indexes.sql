-- Performance V1: remove five indexes fully covered by retained unique indexes.
-- Prepared after the read-only production review on 2026-07-31.
-- This migration intentionally does not use CONCURRENTLY so all changes are atomic.

begin;

-- Retained: member_sections_unique_member_section
--           unique (section_id, society_member_id)
drop index if exists public.member_sections_unique_idx;

-- Retained: society_members_one_person_per_society_idx
--           unique (society_id, person_id)
drop index if exists public.society_members_society_person_unique_idx;

-- Retained: people_one_auth_user_idx
--           unique (user_id) where user_id is not null
drop index if exists public.people_user_id_unique_idx;

-- Retained: the table unique constraint index on
--           (society_id, month_number, effective_from).
-- Equality on the first two columns allows the retained B-tree to scan
-- effective_from in either direction.
drop index if exists public.society_fee_month_rule_lookup_idx;

-- Retained: the table unique constraint index on (outbox_id, attempt_number).
-- Equality on outbox_id allows the retained B-tree to scan attempt_number
-- in either direction.
drop index if exists public.society_email_attempts_outbox_idx;

commit;

-- Rollback (run only if this migration must be reversed):
-- create unique index member_sections_unique_idx
--   on public.member_sections(section_id, society_member_id);
-- create unique index society_members_society_person_unique_idx
--   on public.society_members(society_id, person_id);
-- create unique index people_user_id_unique_idx
--   on public.people(user_id) where user_id is not null;
-- create index society_fee_month_rule_lookup_idx
--   on public.society_fee_month_rule_history
--   (society_id, month_number, effective_from desc);
-- create index society_email_attempts_outbox_idx
--   on public.society_email_delivery_attempts(outbox_id, attempt_number desc);
