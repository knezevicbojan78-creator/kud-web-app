-- Ocekivano: assignment_table=true, authenticated_execute=true,
-- anon_execute=false, activation_execute=true,
-- invalid_approved_request_count=0.

select
  to_regclass('public.president_license_assignments') is not null
    as assignment_table,
  has_function_privilege(
    'authenticated',
    'public.master_admin_approve_president_request(uuid,uuid,text,date,text,text,text)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.master_admin_approve_president_request(uuid,uuid,text,date,text,text,text)',
    'EXECUTE'
  ) as anon_execute,
  has_function_privilege(
    'authenticated',
    'public.auth_activate_approved_president()',
    'EXECUTE'
  ) as activation_execute,
  (
    select count(*)
    from public."PresidentReg" pr
    where pr."StatReg" = 'APPROVED'
      and (
        pr."societyId" is null
        or not exists (
          select 1
          from public.president_license_assignments pla
          where pla.president_reg_id = pr.id
            and pla.society_id = pr."societyId"
        )
      )
  ) as invalid_approved_request_count;
