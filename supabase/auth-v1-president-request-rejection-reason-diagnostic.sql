select
  to_regprocedure(
    'public.master_admin_reject_president_request(uuid,text)'
  ) as rejection_function,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'PresidentReg'
      and column_name = 'rejectionReason'
  ) as rejection_reason_column,
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'PresidentReg'
      and column_name = 'rejectedAt'
  ) as rejected_at_column,
  has_function_privilege(
    'authenticated',
    'public.master_admin_reject_president_request(uuid,text)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.master_admin_reject_president_request(uuid,text)',
    'EXECUTE'
  ) as anon_execute;
