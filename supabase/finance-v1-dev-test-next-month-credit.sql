-- FOLKLORAS DEV/V1 ONLY
-- Pokrece stvarni mesecni obracun za i3 p3 za sledeci mesec.
-- Ocekivanje: 3.000 RSD clanarina, 500 RSD automatski kredit, 2.500 RSD dug.

select *
from public.finance_generate_membership_fees(
  (
    select s.id
    from public.societies s
    where s.name = 'Test' and s.status = 'ACTIVE'
    order by s.created_at
    limit 1
  ),
  (date_trunc('month', current_date) + interval '1 month')::date,
  (
    select sm.id
    from public.society_members sm
    join public.people p on p.id = sm.person_id
    join public.societies s on s.id = sm.society_id
    where s.name = 'Test'
      and s.status = 'ACTIVE'
      and sm.status = 'ACTIVE'
      and lower(trim(p.first_name)) = 'i3'
      and lower(trim(p.last_name)) = 'p3'
    order by sm.created_at
    limit 1
  ),
  'RECHECK',
  null
);
