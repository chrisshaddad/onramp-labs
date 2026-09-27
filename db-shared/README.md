# db-shared

The Postgres setup and data every database lab uses.

| File | What it is |
|---|---|
| `compose.yaml` | Two containers on `postgres:18.6-trixie`: `onramp-db` (pg_stat_statements preloaded) and `onramp-pitr` (WAL archiving on, for db-02). Both mount the repo read-only at `/labs`. Parallel query is off (`max_parallel_workers_per_gather = 0`) so plans stay readable; production keeps the default of 2. |
| `psqlrc` | Turns off the pager so output scrolls in the terminal. |
| `sql/schema.sql` | The deck's shared tables: `users`, `orders` (with `org_id`), `sessions`. |
| `sql/seed.sql` | Deterministic data, about 20 s to load. |

The lab reset scripts run `schema.sql` and `seed.sql`. Nothing is loaded automatically at container start.

## Data

- 200 tenants: `acme`, `globex`, `initech`, `org-004` to `org-200`. Tenant ids are readable slugs so plans and chat answers stay readable; production would use uuid.
- 200,000 users. Users 1 to 80,000 belong to `acme`.
- 2,000,000 orders over the last two years, in time order. `acme` has about 800,000 (40%); every other tenant has about 6,000.
- Indexes: `orders_pkey`, `idx_orders_org_created (org_id, created_at)`, `idx_users_email_lower`, `idx_sessions_token` (hash).
- No foreign key on `orders.customer_id`, on purpose: db-01 measures index write cost, and a per-row FK check would hide it.
- Fixed ids the labs use: customer 4242 (acme, 8 orders) and customer 80641 (org-045, 6 orders).

## Connecting a GUI client

Host `localhost`, port `5432` (or `DB_PORT`), user `postgres`, password `onramp`, database `onramp`. This connects to `onramp-db` only.
