select
  to_regclass('public.wardrobe_loans') as loans_table,
  to_regprocedure('public.auth_get_wardrobe_loans(uuid)') as loans_read,
  to_regprocedure('public.auth_wardrobe_create_loan(uuid,jsonb)') as loan_create,
  to_regprocedure('public.auth_wardrobe_transition_loan(uuid,uuid,text,text)') as loan_transition,
  to_regprocedure('public.auth_get_wardrobe_notifications(uuid)') as notifications_read,
  has_function_privilege(
    'authenticated','public.auth_get_wardrobe_loans(uuid)','EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon','public.auth_get_wardrobe_loans(uuid)','EXECUTE'
  ) as anon_execute;
