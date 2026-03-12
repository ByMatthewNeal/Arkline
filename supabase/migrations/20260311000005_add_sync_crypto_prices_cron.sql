-- Crypto prices sync cron job (every 5 minutes)
--
-- Fetches CoinGecko market data server-side and caches in market_data_cache.
-- Eliminates per-device CoinGecko API calls.

-- Remove old schedule if it existed
DO $$
BEGIN
    PERFORM cron.unschedule('sync-crypto-prices-5m');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Schedule every 5 minutes
DO $outer$
BEGIN
    PERFORM cron.schedule(
        'sync-crypto-prices-5m',
        '*/5 * * * *',
        $$
        SELECT net.http_post(
            url := current_setting('app.supabase_url') || '/functions/v1/sync-crypto-prices',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', current_setting('app.cron_secret')
            ),
            body := '{}'::jsonb
        );
        $$
    );
END $outer$;
