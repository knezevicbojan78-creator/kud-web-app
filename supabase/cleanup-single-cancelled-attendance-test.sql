-- FOLKLORAS: brisanje jedine testne otkazane probe.
--
-- Sigurnosno pravilo:
-- SQL radi samo ako u public.attendance_sessions postoji tacno jedan zapis
-- i ako taj zapis ima status CANCELLED. U svakom drugom slucaju ceo DO blok
-- se ponistava i nista se ne brise.

do $$
declare
  v_session_count bigint;
  v_cancelled_count bigint;
  v_session_id uuid;
  v_deleted_history bigint;
  v_deleted_records bigint;
  v_deleted_sessions bigint;
begin
  select
    count(*),
    count(*) filter (where session.status = 'CANCELLED'),
    min(session.id)
  into
    v_session_count,
    v_cancelled_count,
    v_session_id
  from public.attendance_sessions session;

  raise notice
    'Pronadjeno proba: %, otkazanih: %, cilj: %',
    v_session_count,
    v_cancelled_count,
    coalesce(v_session_id::text, '(nema)');

  if v_session_count = 0 then
    raise notice 'Nema proba za brisanje. Baza je vec cista.';
    return;
  end if;

  if v_session_count <> 1 or v_cancelled_count <> 1 then
    raise exception
      'BRISANJE ODBIJENO: ocekivana je tacno jedna proba sa statusom CANCELLED. Nista nije obrisano.';
  end if;

  delete from public.attendance_record_history history
  where history.attendance_record_id in (
    select record.id
    from public.attendance_records record
    where record.attendance_session_id = v_session_id
  );
  get diagnostics v_deleted_history = row_count;

  delete from public.attendance_records record
  where record.attendance_session_id = v_session_id;
  get diagnostics v_deleted_records = row_count;

  delete from public.attendance_sessions session
  where session.id = v_session_id
    and session.status = 'CANCELLED';
  get diagnostics v_deleted_sessions = row_count;

  if v_deleted_sessions <> 1 then
    raise exception
      'BRISANJE NIJE ZAVRSENO: testna proba nije obrisana. Sve promene se ponistavaju.';
  end if;

  raise notice
    'Brisanje uspesno. Istorija: %, zapisi prisustva: %, probe: %.',
    v_deleted_history,
    v_deleted_records,
    v_deleted_sessions;
end
$$;

select
  (select count(*) from public.attendance_sessions) as attendance_sessions,
  (select count(*) from public.attendance_records) as attendance_records,
  (select count(*) from public.attendance_record_history) as attendance_history;
