-- 20261012000500_warmup_requests.sql
-- Purpose: Persist private, retryable warmup requests and individual pair/trio acknowledgments.
create table public.warmup_requests (
    assignment_id uuid not null,
    requester_id uuid not null,
    created_at timestamptz not null default now(),
    primary key(assignment_id, requester_id),
    foreign key(assignment_id, requester_id) references public.assignment_members(assignment_id, user_id) on delete cascade
);
create table public.warmup_acknowledgments (
    assignment_id uuid not null,
    requester_id uuid not null,
    recipient_id uuid not null,
    created_at timestamptz not null default now(),
    primary key(assignment_id, requester_id, recipient_id),
    check(requester_id <> recipient_id),
    foreign key(assignment_id, requester_id) references public.warmup_requests on delete cascade,
    foreign key(assignment_id, recipient_id) references public.assignment_members(assignment_id, user_id) on delete cascade
);
create index warmup_ack_recipient_idx on public.warmup_acknowledgments(recipient_id, assignment_id);
alter table public.warmup_requests enable row level security;
alter table public.warmup_acknowledgments enable row level security;
revoke all on public.warmup_requests, public.warmup_acknowledgments from anon, authenticated;
grant select on public.warmup_requests, public.warmup_acknowledgments to authenticated;
create policy connection_request_read on public.warmup_requests for select to authenticated using(private.in_assignment(assignment_id));
create policy connection_ack_read on public.warmup_acknowledgments for select to authenticated using(private.in_assignment(assignment_id));
create function public.request_warmup(p_assignment uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_open_assignment(p_assignment);
    insert into public.warmup_requests(assignment_id, requester_id)
        values(p_assignment, auth.uid()) on conflict do nothing;
end;
$$;
create function public.acknowledge_warmup(p_assignment uuid, p_requester uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_open_assignment(p_assignment);
    insert into public.warmup_acknowledgments(assignment_id, requester_id, recipient_id)
        values(p_assignment, p_requester, auth.uid()) on conflict do nothing;
end;
$$;
revoke all on function public.request_warmup(uuid), public.acknowledge_warmup(uuid,uuid) from public, anon;
grant execute on function public.request_warmup(uuid), public.acknowledge_warmup(uuid,uuid) to authenticated;
