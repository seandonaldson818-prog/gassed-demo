-- Gassed: Admin panel + Plug application approval — run this once in the
-- Supabase SQL editor (Project -> SQL Editor -> New query -> paste all of
-- this -> Run). Combines the two migrations already scoped together in the
-- concept doc ("Admin account management" + "Plug application approval"),
-- since they share the same is_admin/status mechanism.
--
-- IMPORTANT — before running: find and replace YOUR_EMAIL_HERE below (near
-- the bottom) with the email you actually log into the real Gassed dashboard
-- with. That one line is what makes your own account an admin.

-- 1. Add is_admin (defaults false for everyone, including existing rows).
alter table public.promoters
  add column if not exists is_admin boolean not null default false;

-- 2. Add status. Existing accounts are backfilled to 'active' first (so
--    nobody who's already using the app gets locked out), THEN the column
--    default is set to 'pending' — meaning every NEW signup from this point
--    forward starts pending review, without needing any app-code change,
--    since the promoters row is created automatically when someone signs up.
alter table public.promoters
  add column if not exists status text;

update public.promoters set status = 'active' where status is null;

alter table public.promoters
  alter column status set default 'pending';

alter table public.promoters
  alter column status set not null;

-- 3. Make your own account an admin and make sure it stays active.
--    Replace YOUR_EMAIL_HERE with your real login email before running.
update public.promoters
set is_admin = true, status = 'active'
where id = (select id from auth.users where email = 'YOUR_EMAIL_HERE');

-- 4. RLS — enforcement for the approval gate. Only a promoter whose own
--    status = 'active' can create events or lineup items. Written AS
--    RESTRICTIVE so it ANDs together with whatever "own row" insert policy
--    already exists on these tables, rather than trying to guess/replace
--    that policy's exact name — this only narrows access, never widens it.
drop policy if exists "only active promoters can create events" on public.events;
create policy "only active promoters can create events"
  as restrictive
  on public.events for insert
  to authenticated
  with check (
    exists (
      select 1 from public.promoters p
      where p.id = auth.uid() and p.status = 'active'
    )
  );

drop policy if exists "only active promoters can create lineup items" on public.lineup_items;
create policy "only active promoters can create lineup items"
  as restrictive
  on public.lineup_items for insert
  to authenticated
  with check (
    exists (
      select 1 from public.promoters p
      join public.events e on e.promoter_id = p.id
      where p.id = auth.uid() and p.status = 'active' and e.id = lineup_items.event_id
    )
  );

-- 5. RLS — admin visibility. Additive SELECT policies (they only ever grant
--    MORE access, never take any away) letting an is_admin promoter read
--    every row on these four tables, for the /app/admin/ list + detail view.
drop policy if exists "admins can read all promoters" on public.promoters;
create policy "admins can read all promoters"
  on public.promoters for select
  using (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  );

drop policy if exists "admins can read all events" on public.events;
create policy "admins can read all events"
  on public.events for select
  using (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  );

drop policy if exists "admins can read all lineup items" on public.lineup_items;
create policy "admins can read all lineup items"
  on public.lineup_items for select
  using (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  );

drop policy if exists "admins can read all signups" on public.signups;
create policy "admins can read all signups"
  on public.signups for select
  using (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  );

-- 6. RLS — the actual approve/reject/suspend/reactivate action. An is_admin
--    promoter can update ANY promoter row's status (and is_admin itself, so
--    a future admin could be designated the same way without a manual SQL
--    step). This is additive alongside whatever "update my own profile"
--    policy already exists for the dashboard's Save Profile button.
drop policy if exists "admins can update any promoter" on public.promoters;
create policy "admins can update any promoter"
  on public.promoters for update
  using (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  )
  with check (
    exists (select 1 from public.promoters me where me.id = auth.uid() and me.is_admin = true)
  );
