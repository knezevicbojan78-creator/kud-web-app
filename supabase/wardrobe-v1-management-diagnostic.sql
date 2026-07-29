select
  to_regprocedure('public.auth_wardrobe_get_item_repertoire(uuid,uuid)')
    as item_repertoire_function,
  has_function_privilege(
    'authenticated',
    'public.auth_wardrobe_get_item_repertoire(uuid,uuid)',
    'EXECUTE'
  ) as authenticated_execute,
  has_function_privilege(
    'anon',
    'public.auth_wardrobe_get_item_repertoire(uuid,uuid)',
    'EXECUTE'
  ) as anon_execute;

select
  to_regprocedure('public.auth_get_wardrobe_operations(uuid)') as operations_function,
  to_regprocedure('public.auth_wardrobe_update_repair(uuid,uuid,jsonb)') as repair_function,
  to_regprocedure('public.auth_wardrobe_resolve_loss(uuid,uuid,text,text,integer)') as loss_function,
  to_regprocedure('public.auth_wardrobe_handover_luggage(uuid,uuid,uuid,text)') as handover_function;
