select
  (
    select count(*)
    from information_schema.tables
    where table_schema = 'public'
      and table_name in (
        'member_import_candidates',
        'member_data_drafts',
        'member_data_invitations'
      )
  ) as table_count,
  (
    select count(distinct p.proname)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'auth_prepare_bulk_member_import',
        'auth_get_pending_member_imports',
        'auth_approve_pending_member_import',
        'auth_reject_pending_member_import',
        'auth_update_pending_member_draft',
        'auth_create_member_data_invitation',
        'auth_cancel_member_data_invitation',
        'public_get_member_data_invitation',
        'public_save_member_data_draft',
        'public_submit_member_data'
      )
  ) as function_count,
  has_function_privilege(
    'anon',
    'public.public_get_member_data_invitation(text)',
    'EXECUTE'
  ) as anon_can_open,
  has_function_privilege(
    'anon',
    'public.public_save_member_data_draft(text,jsonb,integer)',
    'EXECUTE'
  ) as anon_can_save,
  has_function_privilege(
    'anon',
    'public.public_submit_member_data(text,jsonb,integer)',
    'EXECUTE'
  ) as anon_can_submit,
  has_function_privilege(
    'anon',
    'public.auth_prepare_bulk_member_import(uuid,text,jsonb)',
    'EXECUTE'
  ) as anon_can_prepare_import,
  has_function_privilege(
    'authenticated',
    'public.auth_prepare_bulk_member_import(uuid,text,jsonb)',
    'EXECUTE'
  ) as authenticated_can_prepare_import;
