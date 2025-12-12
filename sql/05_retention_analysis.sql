-- 1) Daily active users per user_id (base for retention)
DROP TABLE IF EXISTS daily_activity;

CREATE TABLE daily_activity AS
SELECT
    user_id,
    DATE(event_ts_utc) AS activity_date
FROM fact_events
GROUP BY user_id, DATE(event_ts_utc);


-- 2) 

DROP TABLE IF EXISTS signup_cohort;

CREATE TABLE signup_cohort AS
SELECT
    user_id,
    DATE(MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END)) AS signup_date
FROM fact_events
GROUP BY user_id
HAVING MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END) IS NOT NULL;



-- 3) Build Retention Matrix

WITH base AS (
    SELECT
        sc.user_id,
        sc.signup_date,
        da.activity_date,
        (da.activity_date - sc.signup_date) AS day_number
    FROM signup_cohort sc
    JOIN daily_activity da USING (user_id)
)
SELECT
    signup_date,
    COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END) AS d0_users,
    COUNT(DISTINCT CASE WHEN day_number = 1 THEN user_id END) AS d1_retained,
    COUNT(DISTINCT CASE WHEN day_number = 7 THEN user_id END) AS d7_retained,
    COUNT(DISTINCT CASE WHEN day_number = 30 THEN user_id END) AS d30_retained,
    ROUND(
        COUNT(DISTINCT CASE WHEN day_number = 1 THEN user_id END)::numeric 
        * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END), 0),
        2
    ) AS d1_retention_pct,
    ROUND(
        COUNT(DISTINCT CASE WHEN day_number = 7 THEN user_id END)::numeric
        * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END), 0),
        2
    ) AS d7_retention_pct,
    ROUND(
        COUNT(DISTINCT CASE WHEN day_number = 30 THEN user_id END)::numeric
        * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END), 0),
        2
    ) AS d30_retention_pct
FROM base
GROUP BY signup_date
ORDER BY signup_date DESC
LIMIT 30;



-- Retention by Device or Country

WITH base AS (
    SELECT
        du.device_type,
        sc.user_id,
        sc.signup_date,
        da.activity_date,
        (da.activity_date - sc.signup_date) AS day_number
    FROM signup_cohort sc
    JOIN daily_activity da USING (user_id)
    JOIN dim_users du ON sc.user_id = du.user_id
)
SELECT
    device_type,
    ROUND(
      COUNT(DISTINCT CASE WHEN day_number = 1 THEN user_id END)::numeric
      * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END),0), 2
    ) AS d1_retention_pct,
    ROUND(
      COUNT(DISTINCT CASE WHEN day_number = 7 THEN user_id END)::numeric
      * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END),0), 2
    ) AS d7_retention_pct,
    ROUND(
      COUNT(DISTINCT CASE WHEN day_number = 30 THEN user_id END)::numeric
      * 100.0 / NULLIF(COUNT(DISTINCT CASE WHEN day_number = 0 THEN user_id END),0), 2
    ) AS d30_retention_pct
FROM base
GROUP BY device_type
ORDER BY device_type;


