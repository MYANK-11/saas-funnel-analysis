--Funnel Analysis :- 

-- 1) Basic funnel counts by user (how many users reached each stage)
WITH funnel AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'signup'       THEN event_ts_utc END) AS signup_time,
    MIN(CASE WHEN event_name = 'verify_email' THEN event_ts_utc END) AS verify_time,
    MIN(CASE WHEN event_name = 'start_trial'  THEN event_ts_utc END) AS trial_time,
    MIN(CASE WHEN event_name = 'subscribe'    THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
)
SELECT
  COUNT(landing_time)   AS landing_users,
  COUNT(signup_time)    AS signed_up_users,
  COUNT(verify_time)    AS verified_users,
  COUNT(trial_time)     AS trial_users,
  COUNT(subscribe_time) AS subscribed_users
FROM funnel;




-- 2) Funnel conversion percentages (step-to-step conversion)
WITH funnel AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'signup'       THEN event_ts_utc END) AS signup_time,
    MIN(CASE WHEN event_name = 'verify_email' THEN event_ts_utc END) AS verify_time,
    MIN(CASE WHEN event_name = 'start_trial'  THEN event_ts_utc END) AS trial_time,
    MIN(CASE WHEN event_name = 'subscribe'    THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
),
counts AS (
  SELECT
    COUNT(landing_time)   AS landing_users,
    COUNT(signup_time)    AS signup_users,
    COUNT(verify_time)    AS verify_users,
    COUNT(trial_time)     AS trial_users,
    COUNT(subscribe_time) AS subscribed_users
  FROM funnel
)
SELECT
  landing_users,
  signup_users,
  ROUND(signup_users * 100.0 / NULLIF(landing_users,0), 2) AS landing_to_signup_pct,
  verify_users,
  ROUND(verify_users * 100.0 / NULLIF(signup_users,0), 2) AS signup_to_verify_pct,
  trial_users,
  ROUND(trial_users * 100.0 / NULLIF(verify_users,0), 2) AS verify_to_trial_pct,
  subscribed_users,
  ROUND(subscribed_users * 100.0 / NULLIF(trial_users,0), 2) AS trial_to_subscribe_pct
FROM counts;


-- 3) Step-by-step dropoff counts (how many drop between consecutive steps)
WITH funnel AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'signup'       THEN event_ts_utc END) AS signup_time,
    MIN(CASE WHEN event_name = 'verify_email' THEN event_ts_utc END) AS verify_time,
    MIN(CASE WHEN event_name = 'start_trial'  THEN event_ts_utc END) AS trial_time,
    MIN(CASE WHEN event_name = 'subscribe'    THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
)
SELECT
  SUM(CASE WHEN landing_time IS NOT NULL AND signup_time IS NULL THEN 1 ELSE 0 END) AS dropped_after_landing,
  SUM(CASE WHEN signup_time IS NOT NULL AND verify_time IS NULL THEN 1 ELSE 0 END) AS dropped_after_signup,
  SUM(CASE WHEN verify_time IS NOT NULL AND trial_time IS NULL THEN 1 ELSE 0 END) AS dropped_after_verify,
  SUM(CASE WHEN trial_time IS NOT NULL AND subscribe_time IS NULL THEN 1 ELSE 0 END) AS dropped_after_trial
FROM funnel;


-- 4) Median time (hours) between steps for users who progressed (time-to-convert)
WITH per_user AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END) AS signup_time,
    MIN(CASE WHEN event_name = 'verify_email' THEN event_ts_utc END) AS verify_time,
    MIN(CASE WHEN event_name = 'start_trial' THEN event_ts_utc END) AS trial_time,
    MIN(CASE WHEN event_name = 'subscribe' THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
),
times AS (
  SELECT
    user_id,
    (EXTRACT(EPOCH FROM (signup_time - landing_time)) / 3600.0) AS hours_land_to_signup,
    (EXTRACT(EPOCH FROM (verify_time - signup_time)) / 3600.0) AS hours_signup_to_verify,
    (EXTRACT(EPOCH FROM (trial_time - verify_time)) / 3600.0) AS hours_verify_to_trial,
    (EXTRACT(EPOCH FROM (subscribe_time - trial_time)) / 3600.0) AS hours_trial_to_subscribe
  FROM per_user
)
SELECT
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_land_to_signup))::numeric, 2) AS med_land_to_signup_hrs,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_signup_to_verify))::numeric, 2) AS med_signup_to_verify_hrs,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_verify_to_trial))::numeric, 2) AS med_verify_to_trial_hrs,
  ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hours_trial_to_subscribe))::numeric, 2) AS med_trial_to_subscribe_hrs
FROM times;




-- 5) Top 5 countries by conversion (landing -> subscribe %) to find best/worst markets
WITH funnel AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'subscribe' THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
),
user_country AS (
  SELECT u.user_id, u.country
  FROM dim_users u
)
SELECT
  uc.country,
  COUNT(f.landing_time) AS landing_users,
  COUNT(f.subscribe_time) AS subscribed_users,
  ROUND(COUNT(f.subscribe_time)*100.0/NULLIF(COUNT(f.landing_time),0),2) AS landing_to_subscribe_pct
FROM funnel f
JOIN user_country uc ON f.user_id = uc.user_id
GROUP BY uc.country
ORDER BY landing_to_subscribe_pct DESC
LIMIT 5;


-- 6) Funnel by device_type (web vs mobile) — see channel performance
WITH funnel AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'landing_page' THEN event_ts_utc END) AS landing_time,
    MIN(CASE WHEN event_name = 'subscribe' THEN event_ts_utc END) AS subscribe_time
  FROM fact_events
  GROUP BY user_id
)
SELECT
  du.device_type,
  COUNT(f.landing_time) AS landing_users,
  COUNT(f.subscribe_time) AS subscribed_users,
  ROUND(COUNT(f.subscribe_time)*100.0/NULLIF(COUNT(f.landing_time),0),2) AS landing_to_subscribe_pct
FROM funnel f
JOIN dim_users du ON f.user_id = du.user_id
GROUP BY du.device_type
ORDER BY landing_to_subscribe_pct DESC;


-- 7) Cohort-based funnel conversion: signup-month cohorts conversion to subscribe within 30 days
WITH per_user AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END) AS signup_time
  FROM fact_events
  GROUP BY user_id
  -- only keep users who actually signed up
  HAVING MIN(CASE WHEN event_name = 'signup' THEN event_ts_utc END) IS NOT NULL
),

subscribe_within_30d AS (
  SELECT
    p.user_id,
    p.signup_time,
    MIN(f.event_ts_utc) AS first_subscribe_time
  FROM per_user p
  JOIN fact_events f
    ON f.user_id = p.user_id
   AND f.event_name = 'subscribe'
   AND f.event_ts_utc <= p.signup_time + INTERVAL '30 days'
  GROUP BY p.user_id, p.signup_time
)

SELECT
  DATE_TRUNC('month', p.signup_time) AS signup_month,
  COUNT(DISTINCT p.user_id) AS signed_users,
  COUNT(DISTINCT s.user_id) AS subscribed_within_30d,
  ROUND(COUNT(DISTINCT s.user_id) * 100.0 / NULLIF(COUNT(DISTINCT p.user_id),0), 2) AS pct_subscribed_within_30d
FROM per_user p
LEFT JOIN subscribe_within_30d s ON p.user_id = s.user_id
GROUP BY signup_month
ORDER BY signup_month DESC
LIMIT 12;

-- 8) Users who reached signup but never used feature (candidate for activation improvements)
WITH user_steps AS (
  SELECT
    user_id,
    MIN(CASE WHEN event_name='signup' THEN event_ts_utc END) AS signup_time,
    MIN(CASE WHEN event_name='feature_use' THEN event_ts_utc END) AS first_feature_time
  FROM fact_events
  GROUP BY user_id
)
SELECT
  COUNT(*) AS signed_no_feature
FROM user_steps
WHERE signup_time IS NOT NULL
  AND first_feature_time IS NULL;