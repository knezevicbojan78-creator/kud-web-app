select
  has_function_privilege('authenticated', 'public.auth_get_president_onboarding()', 'EXECUTE')
    as context_execute,
  has_function_privilege('authenticated', 'public.auth_save_president_society_onboarding(jsonb)', 'EXECUTE')
    as society_save_execute,
  has_function_privilege('authenticated', 'public.auth_complete_president_onboarding(jsonb)', 'EXECUTE')
    as complete_execute,
  has_function_privilege('anon', 'public.auth_complete_president_onboarding(jsonb)', 'EXECUTE')
    as anon_complete_execute,
  (
    select count(*) from public.societies s
    where s.status = 'ONBOARDING'
  ) as onboarding_society_count;
