import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import random
import uuid
import sys

fake = Faker()

# PASTE YOUR SUPABASE URI HERE
DB_URI = "postgresql://postgres:e75?ZbRh-_2Tp8i@db.budvbwngkpnrboyxnoql.supabase.co:5432/postgres"

try:
    print("Connecting to Supabase...")
    conn = psycopg2.connect(DB_URI)
    cursor = conn.cursor()
except Exception as e:
    print(f"Connection failed: {e}")
    sys.exit(1)

# 1. Generate 1,000 Tenants
print("Generating 1,000 tenants...")
tenant_ids = [str(uuid.uuid4()) for _ in range(1000)]
tenant_data = [(t_id, fake.company()) for t_id in tenant_ids]
execute_values(cursor, "INSERT INTO tenants (id, company_name) VALUES %s", tenant_data)
conn.commit()

# 2. Generate 1,000,000 Tickets in chunks to balance network latency
print("Generating 1,000,000 tickets. Uploading in chunks...")
statuses = ['open', 'in_progress', 'resolved', 'closed']
priorities = ['low', 'medium', 'high', 'critical']

# Using 50 blocks of 20,000 items is optimal for cloud transfers
total_chunks = 5
rows_per_chunk = 20000

for chunk in range(total_chunks):
    tickets = []
    for _ in range(rows_per_chunk):
        tickets.append((
            str(uuid.uuid4()),
            random.choice(tenant_ids),
            random.choice(statuses),
            random.choice(priorities),
            fake.date_time_between(start_date='-2y', end_date='now').strftime('%Y-%m-%d %H:%M:%S'),
            psycopg2.extras.Json({"browser": fake.chrome(), "os": random.choice(["Linux", "Windows", "macOS", "iOS"]), "tags": [fake.word(), fake.word()]}),
            fake.paragraph(nb_sentences=4)
        ))
    
    execute_values(
        cursor,
        "INSERT INTO tickets (id, tenant_id, status, priority, created_at, metadata, description) VALUES %s",
        tickets
    )
    conn.commit()
    print(f"Successfully uploaded chunk {chunk + 1}/{total_chunks} ({((chunk + 1) * rows_per_chunk):,} rows total)")

print("\nIngestion complete! 1 Million rows successfully pushed to Supabase.")
cursor.close()
conn.close()