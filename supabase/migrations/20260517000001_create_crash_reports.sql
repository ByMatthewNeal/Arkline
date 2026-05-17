-- MetricKit crash diagnostics from real users
-- Captures crashes, hangs, and CPU/disk exceptions delivered by Apple MetricKit
create table public.crash_reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete set null,
    app_version text,
    build_number text,
    os_version text,
    device_model text,
    diagnostic_type text,  -- 'crash' | 'hang' | 'cpu' | 'disk' | 'unknown'
    payload jsonb not null,
    received_at timestamptz default now() not null
);

-- Indexes for the queries we'll actually run
create index idx_crash_reports_received_at on public.crash_reports (received_at desc);
create index idx_crash_reports_diagnostic_type on public.crash_reports (diagnostic_type);
create index idx_crash_reports_app_version on public.crash_reports (app_version);
create index idx_crash_reports_user_id on public.crash_reports (user_id) where user_id is not null;

-- RLS: authenticated users can insert their own reports; admins can read all
alter table public.crash_reports enable row level security;

create policy "Authenticated users can insert their own crash reports"
on public.crash_reports for insert
to authenticated
with check (user_id = auth.uid() or user_id is null);

create policy "Admins can read all crash reports"
on public.crash_reports for select
to authenticated
using (
    exists (
        select 1 from public.profiles
        where profiles.id = auth.uid()
        and profiles.role = 'admin'
    )
);

-- Nobody can update or delete (immutable audit log)
create policy "No updates allowed"
on public.crash_reports for update
to authenticated
using (false);

create policy "No deletes allowed"
on public.crash_reports for delete
to authenticated
using (false);
