begin;

-- Direktno čitanje i menjanje poslovnih tabela nije deo Auth V1 interfejsa.
revoke all on table public.financial_audit_log from anon;
revoke all on table public.financial_credit_entries from anon;
revoke all on table public.financial_email_outbox from anon;
revoke all on table public.financial_number_counters from anon;
revoke all on table public.financial_obligation_allocations from anon;
revoke all on table public.financial_obligations from anon;
revoke all on table public.financial_payments from anon;
revoke all on table public.financial_refunds from anon;
revoke all on table public.financial_reminder_runs from anon;
revoke all on table public.member_fee_grants from anon;
revoke all on table public.member_fee_setting_history from anon;
revoke all on table public.membership_fee_assessments from anon;
revoke all on table public.society_email_connections from anon;
revoke all on table public.society_fee_calendar from anon;
revoke all on table public.society_fee_month_rule_history from anon;
revoke all on table public.user_onboarding_state from anon;

-- Stari browser/DEV tokovi. Finalni interfejs koristi auth_* i kontrolisane
-- finance_* omotače koji sami određuju izvršioca iz Auth sesije.
revoke all on function public.approve_person_data_change_request(uuid,uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_event(uuid,text,text,uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.finance_configure_society(
  uuid,text,numeric,date,text,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.finance_generate_all_membership_fees(date)
  from public, anon, authenticated;
revoke all on function public.finance_generate_membership_fees(
  uuid,date,uuid,text,uuid
) from public, anon, authenticated;
revoke all on function public.finance_get_actor_context()
  from public, anon, authenticated;
revoke all on function public.finance_grant_initial_free_months(
  uuid,smallint,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.finance_set_fee_calendar_month(
  uuid,date,boolean,text,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.permissions_bootstrap_function_defaults()
  from public, anon, authenticated;
revoke all on function public.reject_person_data_change_request(
  uuid,text,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.set_event_participant_status(uuid,text,text)
  from public, anon, authenticated;

-- Trigger funkcije se izvršavaju kroz trigger i ne treba da budu RPC pozivi.
revoke all on function public.permissions_prevent_audit_mutation()
  from public, anon, authenticated;
revoke all on function public.permissions_set_updated_at()
  from public, anon, authenticated;
revoke all on function public.permissions_validate_scope()
  from public, anon, authenticated;
revoke all on function public.prevent_financial_audit_change()
  from public, anon, authenticated;
revoke all on function public.prevent_financial_row_delete()
  from public, anon, authenticated;
revoke all on function public.validate_event_appearance_repertoire()
  from public, anon, authenticated;
revoke all on function public.validate_event_participant()
  from public, anon, authenticated;
revoke all on function public.validate_event_participant_section()
  from public, anon, authenticated;
revoke all on function public.validate_event_repertoire_participant()
  from public, anon, authenticated;

commit;
