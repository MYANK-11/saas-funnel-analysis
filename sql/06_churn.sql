-- 1.Last Active Date for Each User

DROP TABLE IF EXISTS user_last_activity;

CREATE TABLE user_last_activity AS
SELECT
    user_id,
    MAX(event_ts_utc)::date AS last_active_date
FROM fact_events
GROUP BY user_id;


--Note:- Determine CHURN (inactive 30 days)

--2.Simulated today (end of dataset period)
WITH today AS (SELECT DATE '2024-11-30' AS today_date)

SELECT
    ula.user_id,
    ula.last_active_date,
    CASE 
        WHEN ula.last_active_date <= (SELECT today_date FROM today) - INTERVAL '30 days'
        THEN 1
        ELSE 0
    END AS is_churned
FROM user_last_activity ula
ORDER BY last_active_date DESC
LIMIT 20;



--3.Churn Rate by Signup Cohort

WITH today AS (SELECT DATE '2024-11-30' AS today_date),

cohort AS (
    SELECT
        user_id,
        DATE(MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END)) AS signup_date
    FROM fact_events
    GROUP BY user_id
),

joined AS (
    SELECT
        c.signup_date,
        ula.user_id,
        ula.last_active_date,
        CASE 
            WHEN ula.last_active_date <= (SELECT today_date FROM today) - INTERVAL '30 days'
                 THEN 1 ELSE 0 END AS is_churned
    FROM cohort c
    JOIN user_last_activity ula USING (user_id)
    WHERE c.signup_date IS NOT NULL
)

SELECT
    signup_date,
    COUNT(*) AS total_users,
    SUM(is_churned) AS churned_users,
    ROUND(SUM(is_churned) * 100.0 / NULLIF(COUNT(*), 0), 2) AS churn_rate_pct
FROM joined
GROUP BY signup_date
ORDER BY signup_date DESC
LIMIT 30;


--4.Churn by Device Type

WITH today AS (SELECT DATE '2024-11-30' AS today_date),

joined AS (
    SELECT
        du.device_type,
        ula.user_id,
        ula.last_active_date,
        CASE 
            WHEN ula.last_active_date <= (SELECT today_date FROM today) - INTERVAL '30 days'
                 THEN 1 ELSE 0 END AS is_churned
    FROM user_last_activity ula
    JOIN dim_users du ON ula.user_id = du.user_id
)

SELECT
    device_type,
    COUNT(*) AS total_users,
    SUM(is_churned) AS churned_users,
    ROUND(SUM(is_churned) * 100.0 / NULLIF(COUNT(*), 0), 2) AS churn_rate_pct
FROM joined
GROUP BY device_type
ORDER BY device_type;
