import pandas as pd
import random
from datetime import datetime, timedelta
import os

NUM_USERS = 5000
START_DATE = datetime(2024, 1, 1)

DEVICES = ["web", "android", "ios"]
COUNTRIES = ["IN", "US", "UK", "CA", "AU"]

FUNNEL_FLOW = [
    "landing_page",
    "signup",
    "verify_email",
    "login",
    "start_trial",
    "subscribe",
    "cancel"
]

USER_TYPES = [
    ("bounce", 0.15),
    ("signup_drop", 0.20),
    ("trial_only", 0.25),
    ("subscriber_active", 0.25),
    ("subscriber_churn", 0.15)
]

def choose_user_type():
    r = random.random()
    cumulative = 0.0
    for t, p in USER_TYPES:
        cumulative += p
        if r <= cumulative:
            return t
    return USER_TYPES[-1][0]

all_events = []
event_id = 1

for user_id in range(1, NUM_USERS + 1):
    user_type = choose_user_type()
    device = random.choice(DEVICES)
    country = random.choice(COUNTRIES)

    current_time = START_DATE + timedelta(days=random.randint(0, 300),
                                          hours=random.randint(0, 23),
                                          minutes=random.randint(0, 59))

    current_plan = None
    events_for_user = []

    events_for_user.append("landing_page")

    if user_type in ["signup_drop", "trial_only", "subscriber_active", "subscriber_churn"]:
        events_for_user.append("signup")

    if user_type in ["trial_only", "subscriber_active", "subscriber_churn"]:
        events_for_user.append("verify_email")
        events_for_user.append("login")
        events_for_user.append("start_trial")

    if user_type in ["subscriber_active", "subscriber_churn"]:
        events_for_user.append("subscribe")

    extra_feature_events = 0
    if user_type in ["trial_only", "subscriber_active", "subscriber_churn"]:
        extra_feature_events = random.randint(3, 20)

    for ev in events_for_user:
        if ev == "signup":
            current_plan = "free"
        elif ev == "start_trial":
            current_plan = "basic"
        elif ev == "subscribe":
            current_plan = "pro"

        all_events.append({
            "event_id": event_id,
            "user_id": user_id,
            "event_name": ev,
            "event_timestamp": current_time.strftime("%Y-%m-%d %H:%M:%S"),
            "device_type": device,
            "country": country,
            "plan_type": current_plan
        })
        event_id += 1
        current_time += timedelta(minutes=random.randint(5, 60))

    for _ in range(extra_feature_events):
        ev = random.choice(["feature_use", "login"])
        all_events.append({
            "event_id": event_id,
            "user_id": user_id,
            "event_name": ev,
            "event_timestamp": current_time.strftime("%Y-%m-%d %H:%M:%S"),
            "device_type": device,
            "country": country,
            "plan_type": current_plan
        })
        event_id += 1
        current_time += timedelta(days=random.randint(0, 5),
                                  minutes=random.randint(10, 120))

    if user_type == "subscriber_churn":
        ev = "cancel"
        all_events.append({
            "event_id": event_id,
            "user_id": user_id,
            "event_name": ev,
            "event_timestamp": current_time.strftime("%Y-%m-%d %H:%M:%S"),
            "device_type": device,
            "country": country,
            "plan_type": current_plan
        })
        event_id += 1

os.makedirs("data/raw", exist_ok=True)

df = pd.DataFrame(all_events)
df = df.sort_values(["user_id", "event_timestamp", "event_id"])

df.to_csv("data/raw/events_raw.csv", index=False)

print("✅ events_raw.csv created successfully.")
print("✅ Total rows:", len(df))
print("✅ Total users:", df["user_id"].nunique())
print("✅ Example event_names:", df["event_name"].unique())
