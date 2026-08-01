begin;

-- Slanje linka prihvata kandidata samo u proces dopune. Članstvo postoji kao
-- tehnički zapis, ali ne postaje aktivno pre završne predsedničke potvrde.
do $migration$
declare
  v_definition text;
  v_updated text;
begin
  select pg_get_functiondef(
    'public.auth_accept_candidate_for_data_completion(uuid,uuid)'::regprocedure
  ) into v_definition;

  v_updated := replace(
    v_definition,
    $old$p_society_id, v_person_id, 'ACTIVE', current_date, true, 0, 'AWAITING_DATA'$old$,
    $new$p_society_id, v_person_id, 'INACTIVE', current_date, true, 0, 'AWAITING_DATA'$new$
  );
  if v_updated = v_definition then
    raise exception 'Nije pronađen očekivani ACTIVE unos kandidata.';
  end if;

  v_definition := v_updated;
  v_updated := replace(
    v_definition,
    $old$values (v_member_id, 'ACTIVE', current_date);$old$,
    $new$values (v_member_id, 'INACTIVE', current_date);$new$
  );
  if v_updated = v_definition then
    raise exception 'Nije pronađena očekivana ACTIVE istorija kandidata.';
  end if;

  execute v_updated;
end;
$migration$;

-- Red čekanja vraća vezani članski ID kako bi aplikacija mogla da sakrije
-- tehnički zapis iz redovnog spiska do konačne potvrde.
do $migration$
declare
  v_definition text;
  v_updated text;
begin
  select pg_get_functiondef(
    'public.auth_get_pending_member_imports(uuid)'::regprocedure
  ) into v_definition;

  if position('''society_member_id'', candidate.society_member_id' in v_definition) = 0 then
    v_updated := replace(
      v_definition,
      $old$'created_at', candidate.created_at,$old$,
      $new$'created_at', candidate.created_at,
      'society_member_id', candidate.society_member_id,$new$
    );
    if v_updated = v_definition then
      raise exception 'Nije pronađen očekivani rezultat reda čekanja.';
    end if;
    execute v_updated;
  end if;
end;
$migration$;

-- Ispravka postojećih nepotpunih članstava: podaci, kandidat i poslati linkovi
-- ostaju sačuvani, menja se samo poslovni status članstva.
with repaired as (
  update public.society_members member
  set status = 'INACTIVE'
  from public.member_import_candidates candidate
  where candidate.society_member_id = member.id
    and candidate.status = 'PENDING'
    and member.status = 'ACTIVE'
    and member.data_completion_status <> 'COMPLETED'
  returning member.id
)
insert into public.member_status_history (
  society_member_id, status, effective_date
)
select id, 'INACTIVE', current_date
from repaired;

select pg_notify('pgrst', 'reload schema');

commit;
