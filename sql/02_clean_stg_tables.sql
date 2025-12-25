-- Data Cleaning Stage :- 


-- Drop if exists (safe re-run)
DROP TABLE IF EXISTS stg_events;

-- Create staging table with cleaned / normalized columns
CREATE TABLE stg_events AS
SELECT
    event_id,
    user_id,
    LOWER(TRIM(event_name))      AS event_name,
    event_timestamp              AS event_ts_utc,
    LOWER(TRIM(device_type))     AS device_type,
    UPPER(TRIM(country))         AS country,
    NULLIF(TRIM(plan_type), '')  AS plan_type
FROM raw_events
WHERE user_id IS NOT NULL
  AND event_timestamp IS NOT NULL
  -- keep only known event names, avoid garbage
  AND LOWER(TRIM(event_name)) IN (
        'landing_page',
        'signup',
        'verify_email',
        'login',
        'start_trial',
        'feature_use',
        'subscribe',
        'cancel'
  );



--After Cleaning Check the event names , counting DISTINCT user_id, and counting other things.

SELECT COUNT(*) FROM stg_events;

SELECT COUNT(DISTINCT user_id) FROM stg_events;

SELECT DISTINCT event_name FROM stg_events ORDER BY event_name;


