-- Maloletni clan koristi kontakt roditelja/staratelja i ne mora imati svoj email.
do $$
declare
  v_definition text;
  v_updated text;
begin
  select pg_get_functiondef('public.auth_prepare_bulk_member_import(uuid,text,jsonb)'::regprocedure)
  into v_definition;
  v_updated := replace(v_definition,
    $old$if nullif(btrim(v_row ->> 'first_name'), '') is null
       or nullif(btrim(v_row ->> 'last_name'), '') is null
       or nullif(lower(btrim(v_row ->> 'email')), '') is null then
      raise exception 'Ime, prezime i email su obavezni u svakom redu.';
    end if;$old$,
    $new$if nullif(btrim(v_row ->> 'first_name'), '') is null
       or nullif(btrim(v_row ->> 'last_name'), '') is null then
      raise exception 'Ime i prezime su obavezni u svakom redu.';
    end if;
    if nullif(lower(btrim(v_row ->> 'email')), '') is null
       and (
         v_row ->> 'person_kind' = 'Roditelj/staratelj'
         or v_row ->> 'person_kind' <> 'Član'
         or nullif(v_row ->> 'birth_date', '') is null
         or (v_row ->> 'birth_date')::date <= current_date - interval '18 years'
       ) then
      raise exception 'Email je obavezan za punoletnog clana i roditelja/staratelja.';
    end if;$new$);
  if v_updated = v_definition then
    raise exception 'Nije pronadjeno pravilo za pripremu masovnog unosa.';
  end if;
  execute v_updated;

  select pg_get_functiondef('public.auth_get_pending_member_imports(uuid)'::regprocedure)
  into v_definition;
  v_updated := replace(v_definition,
    $old$('email', nullif(coalesce(data_draft.draft, candidate.profile) ->> 'email', '') is null),$old$,
    $new$('email',
            not coalesce((coalesce(data_draft.draft, candidate.profile) ->> 'is_minor_member')::boolean, false)
            and nullif(coalesce(data_draft.draft, candidate.profile) ->> 'email', '') is null),$new$);
  if v_updated = v_definition then
    raise exception 'Nije pronadjeno pravilo pregleda emaila kandidata.';
  end if;
  execute v_updated;

  select pg_get_functiondef('public.public_submit_member_data(text,jsonb,integer)'::regprocedure)
  into v_definition;
  v_updated := replace(v_definition,
    $old$if nullif(btrim(p_draft ->> 'first_name'), '') is null
     or nullif(btrim(p_draft ->> 'last_name'), '') is null
     or nullif(lower(btrim(p_draft ->> 'email')), '') is null then
    raise exception 'Ime, prezime i email su obavezni.';
  end if;$old$,
    $new$if nullif(btrim(p_draft ->> 'first_name'), '') is null
     or nullif(btrim(p_draft ->> 'last_name'), '') is null
     or (
       not v_minor
       and nullif(lower(btrim(p_draft ->> 'email')), '') is null
     ) then
    raise exception 'Ime i prezime su obavezni, a email je obavezan za punoletnog clana.';
  end if;$new$);
  if v_updated = v_definition then
    raise exception 'Nije pronadjeno pravilo javne dopune emaila kandidata.';
  end if;
  execute v_updated;
end;
$$;
