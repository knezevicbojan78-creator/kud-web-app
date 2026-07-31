-- Jednokratno vraćanje slučajno odbačenog E2E zahteva u listu za potvrđivanje.
-- Namenjeno isključivo testnom kandidatu codex.e2e.minor.002@example.com.

begin;

update public.member_import_candidates
set status = 'PENDING',
    reviewed_by_user_id = null,
    reviewed_at = null
where id = (
  select candidate.id
  from public.member_import_candidates candidate
  where lower(candidate.profile ->> 'email') = 'codex.e2e.minor.002@example.com'
    and candidate.status = 'REJECTED'
  order by candidate.created_at desc
  limit 1
);

commit;
