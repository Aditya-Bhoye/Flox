-- Monthly summary email schedule.
-- Run once in the Supabase SQL Editor AFTER deploying the monthly-summary
-- Edge Function. Replace PASTE_CRON_SECRET_HERE with the same value you set
-- as the CRON_SECRET Edge Function secret.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Store the shared secret in Vault instead of in the job text.
select vault.create_secret('PASTE_CRON_SECRET_HERE', 'flox_cron_secret')
where not exists (select 1 from vault.secrets where name = 'flox_cron_secret');

-- 03:30 UTC on the 1st = 9:00 AM India time; covers the month that just ended.
select cron.schedule(
  'flox-monthly-summary',
  '30 3 1 * *',
  $$
  select net.http_post(
    url := 'https://yomyhrmbniiexwwweuwk.supabase.co/functions/v1/monthly-summary',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'flox_cron_secret')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

-- ─── Test now (optional) ────────────────────────────────────────────────────
-- Sends this month's summary to one address only. Change the email, run just
-- this statement, then check the inbox (and Spam).
--
-- select net.http_post(
--   url := 'https://yomyhrmbniiexwwweuwk.supabase.co/functions/v1/monthly-summary',
--   headers := jsonb_build_object(
--     'Content-Type', 'application/json',
--     'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'flox_cron_secret')
--   ),
--   body := jsonb_build_object('month', to_char(now() at time zone 'Asia/Kolkata', 'YYYY-MM'), 'only', 'you@gmail.com'),
--   timeout_milliseconds := 120000
-- );
