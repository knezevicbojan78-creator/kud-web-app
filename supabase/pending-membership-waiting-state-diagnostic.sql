select
  count(*) filter (
    where candidate.status = 'PENDING'
      and member.status = 'ACTIVE'
      and member.data_completion_status <> 'COMPLETED'
  ) as wrongly_active_pending_count,
  count(*) filter (
    where candidate.status = 'PENDING'
      and member.status = 'INACTIVE'
      and member.data_completion_status <> 'COMPLETED'
  ) as correctly_waiting_member_count,
  count(*) filter (
    where candidate.status = 'PENDING'
      and candidate.society_member_id is null
  ) as pending_without_membership_count
from public.member_import_candidates candidate
left join public.society_members member
  on member.id = candidate.society_member_id;

select
  position(
    '''society_member_id'', candidate.society_member_id'
    in pg_get_functiondef(
      'public.auth_get_pending_member_imports(uuid)'::regprocedure
    )
  ) > 0 as pending_read_returns_member_id,
  position(
    '''INACTIVE'', current_date, true, 0, ''AWAITING_DATA'''
    in pg_get_functiondef(
      'public.auth_accept_candidate_for_data_completion(uuid,uuid)'::regprocedure
    )
  ) > 0 as acceptance_creates_waiting_membership;
