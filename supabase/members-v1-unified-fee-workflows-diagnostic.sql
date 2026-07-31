select
  to_regprocedure('public.auth_create_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)') as create_with_fee,
  to_regprocedure('public.auth_update_society_member_with_fee(uuid,jsonb,jsonb,uuid[],uuid[],jsonb)') as update_with_fee,
  to_regprocedure('public.auth_finalize_pending_member_with_fee(uuid,uuid,date,jsonb,jsonb)') as finalize_with_fee;
