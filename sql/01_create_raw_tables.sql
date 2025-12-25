CREATE TABLE raw_events (
    event_id        BIGINT PRIMARY KEY,
    user_id         BIGINT NOT NULL,
    event_name      TEXT   NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    device_type     TEXT   NOT NULL,
    country         TEXT   NOT NULL,
    plan_type       TEXT
);
