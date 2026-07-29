-- READ-ONLY provera finansijskog radnog prostora
select
  to_regprocedure('public.auth_get_finance_workspace(uuid)')
    as finance_workspace_function,
  to_regprocedure('public.finance_can_manage_society(uuid,uuid)')
    as finance_scope_function,
  has_function_privilege(
    'authenticated',
    'public.auth_get_finance_workspace(uuid)',
    'EXECUTE'
  ) as authenticated_workspace_execute,
  has_function_privilege(
    'anon',
    'public.auth_get_finance_workspace(uuid)',
    'EXECUTE'
  ) as anon_workspace_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_can_manage_society(uuid,uuid)',
    'EXECUTE'
  ) as direct_scope_execute_error,
  has_function_privilege(
    'authenticated',
    'public.finance_search_entities(uuid,text,uuid,integer)',
    'EXECUTE'
  ) as authenticated_search_execute,
  has_function_privilege(
    'anon',
    'public.finance_search_entities(uuid,text,uuid,integer)',
    'EXECUTE'
  ) as anon_search_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_get_entity_profile(uuid,text,uuid,uuid)',
    'EXECUTE'
  ) as authenticated_profile_execute,
  has_function_privilege(
    'anon',
    'public.finance_get_entity_profile(uuid,text,uuid,uuid)',
    'EXECUTE'
  ) as anon_profile_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_record_payment(uuid,numeric,text,text,jsonb,uuid,uuid,numeric,uuid,uuid)',
    'EXECUTE'
  ) as authenticated_payment_execute,
  has_function_privilege(
    'anon',
    'public.finance_record_payment(uuid,numeric,text,text,jsonb,uuid,uuid,numeric,uuid,uuid)',
    'EXECUTE'
  ) as anon_payment_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_void_payment(uuid,text,uuid,uuid)',
    'EXECUTE'
  ) as authenticated_void_payment_execute,
  has_function_privilege(
    'anon',
    'public.finance_void_payment(uuid,text,uuid,uuid)',
    'EXECUTE'
  ) as anon_void_payment_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_next_document_number(uuid,text)',
    'EXECUTE'
  ) as direct_number_execute_error,
  has_function_privilege(
    'authenticated',
    'public.finance_get_membership_settings(uuid,uuid)',
    'EXECUTE'
  ) as authenticated_settings_read_execute,
  has_function_privilege(
    'anon',
    'public.finance_get_membership_settings(uuid,uuid)',
    'EXECUTE'
  ) as anon_settings_read_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_update_membership_settings(uuid,numeric,integer[],text,uuid)',
    'EXECUTE'
  ) as authenticated_settings_save_execute,
  has_function_privilege(
    'anon',
    'public.finance_update_membership_settings(uuid,numeric,integer[],text,uuid)',
    'EXECUTE'
  ) as anon_settings_save_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_set_member_fee(uuid,text,numeric,text,uuid,uuid)',
    'EXECUTE'
  ) as authenticated_member_fee_execute,
  has_function_privilege(
    'anon',
    'public.finance_set_member_fee(uuid,text,numeric,text,uuid,uuid)',
    'EXECUTE'
  ) as anon_member_fee_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_schedule_standard_fee(uuid,numeric,text,uuid,uuid)',
    'EXECUTE'
  ) as direct_standard_fee_execute_error,
  has_function_privilege(
    'authenticated',
    'public.finance_record_refund(uuid,uuid,numeric,text,text,text,uuid)',
    'EXECUTE'
  ) as authenticated_refund_execute,
  has_function_privilege(
    'anon',
    'public.finance_record_refund(uuid,uuid,numeric,text,text,text,uuid)',
    'EXECUTE'
  ) as anon_refund_execute,
  has_function_privilege(
    'authenticated',
    'public.finance_void_refund(uuid,text,uuid)',
    'EXECUTE'
  ) as authenticated_void_refund_execute,
  has_function_privilege(
    'anon',
    'public.finance_void_refund(uuid,text,uuid)',
    'EXECUTE'
  ) as anon_void_refund_execute;
