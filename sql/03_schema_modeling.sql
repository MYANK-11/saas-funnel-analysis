--  Stage 4 :- Schema Modeling

--creating  a dim_users
DROP TABLE IF EXISTS dim_users;

CREATE TABLE dim_users AS
SELECT DISTINCT
    user_id,
    country,
    device_type,
    MIN(event_ts_utc) AS first_seen_at,
    MAX(event_ts_utc) AS last_seen_at
FROM stg_events
GROUP BY user_id, country, device_type;


--What the above code will do :- 
--One row = one user
--Stores:-
--Where they’re from
--What device they use
--When they first appeared
--When they were last active





DROP TABLE IF EXISTS fact_events;

CREATE TABLE fact_events AS
SELECT
    event_id,
    user_id,
    event_name,
    event_ts_utc,
    device_type,
    country,
    plan_type
FROM stg_events;


--What this means (simple):
--One row = one event
--This is your main analytics table
--Funnel, retention, churn → ALL run from this table



-- Sanity Checks (MANDATORY)

SELECT COUNT(*) FROM dim_users;
SELECT COUNT(*) FROM fact_events;

SELECT * FROM dim_users LIMIT 5;
SELECT * FROM fact_events LIMIT 5;
