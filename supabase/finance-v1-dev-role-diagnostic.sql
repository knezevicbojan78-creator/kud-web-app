-- FOLKLORAS DEV/V1
-- READ-ONLY: proverava da li testna drustva imaju dodeljenog predsednika/blagajnika.
-- Ne prikazuje licne podatke i ne menja bazu.

select
  s.name as society_name,
  s.status as society_status,
  smf.name as assigned_role,
  smf.is_active as role_is_active,
  sm.status as member_status,
  count(*) as assignment_count
from public.society_member_function_assignments smfa
join public.society_member_functions smf
  on smf.id = smfa.function_id
join public.society_members sm
  on sm.id = smfa.society_member_id
 and sm.society_id = smfa.society_id
join public.societies s
  on s.id = smfa.society_id
where smf.name in ('Predsednik', 'Blagajnik')
group by s.name, s.status, smf.name, smf.is_active, sm.status
order by s.name, smf.name, sm.status;
