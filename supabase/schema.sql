-- Flox database schema.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Safe to re-run: every statement is idempotent.
--
-- Every table has Row Level Security enabled and only lets a signed-in user
-- see and change their own rows. Money is stored as whole paise (bigint).

-- ─── Friends ────────────────────────────────────────────────────────────────
create table if not exists public.friends (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null check (length(trim(name)) between 1 and 100),
  phone       text check (phone is null or length(phone) <= 32),
  archived    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (id, user_id)
);
create index if not exists friends_user_idx on public.friends (user_id);

-- ─── Splits (one expense or settlement) ─────────────────────────────────────
create table if not exists public.split_items (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title            text not null check (length(title) between 1 and 200),
  total_paise      bigint not null check (total_paise >= 0),
  -- null = the signed-in user paid
  payer_friend_id  uuid,
  created_at       timestamptz not null default now(),
  unique (id, user_id),
  foreign key (payer_friend_id, user_id) references public.friends (id, user_id)
);
create index if not exists split_items_user_idx on public.split_items (user_id, created_at desc);

-- ─── Debts inside a split: "debtor owes creditor amount" ────────────────────
-- null debtor/creditor = the signed-in user.
create table if not exists public.split_debts (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  split_id            uuid not null,
  debtor_friend_id    uuid,
  creditor_friend_id  uuid,
  amount_paise        bigint not null check (amount_paise > 0),
  check (debtor_friend_id is distinct from creditor_friend_id),
  foreign key (split_id, user_id) references public.split_items (id, user_id) on delete cascade,
  foreign key (debtor_friend_id, user_id) references public.friends (id, user_id),
  foreign key (creditor_friend_id, user_id) references public.friends (id, user_id)
);
create index if not exists split_debts_split_idx on public.split_debts (split_id);

-- ─── Row Level Security ─────────────────────────────────────────────────────
alter table public.friends     enable row level security;
alter table public.split_items enable row level security;
alter table public.split_debts enable row level security;

drop policy if exists "own friends" on public.friends;
create policy "own friends" on public.friends
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own splits" on public.split_items;
create policy "own splits" on public.split_items
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own debts" on public.split_debts;
create policy "own debts" on public.split_debts
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ─── Atomic insert of a split and its debts ─────────────────────────────────
-- security invoker: runs as the caller, so RLS still applies.
create or replace function public.create_split(
  p_title text,
  p_total_paise bigint,
  p_payer_friend_id uuid,
  p_created_at timestamptz,
  p_debts jsonb
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_split_id uuid;
  v_debt jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into split_items (title, total_paise, payer_friend_id, created_at)
  values (p_title, p_total_paise, p_payer_friend_id, coalesce(p_created_at, now()))
  returning id into v_split_id;

  for v_debt in select * from jsonb_array_elements(coalesce(p_debts, '[]'::jsonb)) loop
    insert into split_debts (split_id, debtor_friend_id, creditor_friend_id, amount_paise)
    values (
      v_split_id,
      nullif(v_debt->>'debtor_friend_id', '')::uuid,
      nullif(v_debt->>'creditor_friend_id', '')::uuid,
      (v_debt->>'amount_paise')::bigint
    );
  end loop;

  return v_split_id;
end;
$$;

revoke all on function public.create_split(text, bigint, uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.create_split(text, bigint, uuid, timestamptz, jsonb) to authenticated;

-- ─── API access ─────────────────────────────────────────────────────────────
-- Newer Supabase projects may not expose new tables automatically. Signed-in
-- users get table access here; RLS above still limits them to their own rows.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.friends, public.split_items, public.split_debts to authenticated;
revoke all on public.friends, public.split_items, public.split_debts from anon;

-- Make the API notice the new tables right away.
notify pgrst, 'reload schema';
