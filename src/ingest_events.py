import pandas as pd
from sqlalchemy import create_engine, text

# 1) Read the CSV generated in Step 1
df = pd.read_csv("data/raw/events_raw.csv")

# 2) Create DB engine (CHANGE PASSWORD ONLY)
engine = create_engine("postgresql://postgres:#PostgreSQL#@localhost:5432/saas_analytics")

# 3) Truncate before insert (SQLAlchemy 2.x compatible)
with engine.begin() as conn:
    conn.execute(text("TRUNCATE TABLE raw_events;"))

# 4) Load into raw_events table
df.to_sql("raw_events", engine, if_exists="append", index=False)

print("✅ Ingestion complete.")
print("✅ Rows loaded:", len(df))
