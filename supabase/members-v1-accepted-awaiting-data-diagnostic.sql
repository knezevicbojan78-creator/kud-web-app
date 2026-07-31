select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'society_members'
      and column_name = 'data_completion_status'
  ) as completion_status_exists,
  to_regprocedure('public.auth_accept_candidate_for_data_completion(uuid,uuid)') is not null
    as accept_function_exists,
  to_regprocedure('public.auth_complete_accepted_member_data(uuid,uuid,date,jsonb)') is not null
    as complete_function_exists;

select data_completion_status, count(*)
from public.society_members
group by data_completion_status
order by data_completion_status;

select count(*) as pending_candidate_without_member_after_invitation
from public.member_import_candidates candidate
where candidate.status = 'PENDING'
  and candidate.society_member_id is null
  and exists (
    select 1 from public.member_data_invitations invitation
    where invitation.candidate_id = candidate.id
      and invitation.status in ('INVITED', 'OPENED', 'IN_PROGRESS', 'SUBMITTED')
  );
