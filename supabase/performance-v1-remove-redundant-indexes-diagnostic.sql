-- Read-only verification for performance-v1-remove-redundant-indexes.sql.

with expected(index_name, expected_present) as (
  values
    ('member_sections_unique_idx', false),
    ('member_sections_unique_member_section', true),
    ('society_members_society_person_unique_idx', false),
    ('society_members_one_person_per_society_idx', true),
    ('people_user_id_unique_idx', false),
    ('people_one_auth_user_idx', true),
    ('society_fee_month_rule_lookup_idx', false),
    ('society_fee_month_rule_histor_society_id_month_number_effec_key', true),
    ('society_email_attempts_outbox_idx', false),
    ('society_email_delivery_attempts_outbox_id_attempt_number_key', true)
), actual as (
  select indexname, indexdef
  from pg_indexes
  where schemaname = 'public'
)
select
  expected.index_name,
  expected.expected_present,
  (actual.indexname is not null) as is_present,
  ((actual.indexname is not null) = expected.expected_present) as is_correct,
  actual.indexdef
from expected
left join actual on actual.indexname = expected.index_name
order by expected.index_name;

-- Expected result: zero rows.
with expected(index_name, expected_present) as (
  values
    ('member_sections_unique_idx', false),
    ('member_sections_unique_member_section', true),
    ('society_members_society_person_unique_idx', false),
    ('society_members_one_person_per_society_idx', true),
    ('people_user_id_unique_idx', false),
    ('people_one_auth_user_idx', true),
    ('society_fee_month_rule_lookup_idx', false),
    ('society_fee_month_rule_histor_society_id_month_number_effec_key', true),
    ('society_email_attempts_outbox_idx', false),
    ('society_email_delivery_attempts_outbox_id_attempt_number_key', true)
), actual as (
  select indexname
  from pg_indexes
  where schemaname = 'public'
)
select expected.*
from expected
left join actual on actual.indexname = expected.index_name
where (actual.indexname is not null) <> expected.expected_present;
