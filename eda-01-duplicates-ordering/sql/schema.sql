-- eda-01: consumer state for the duplicates and out-of-order demos.
-- Applied by `demo reset` (drop and recreate). `demo setup dup|order` only empties its own tables.
DROP TABLE IF EXISTS invoices, processed_events, order_state, sent_emails;

-- invoices has no unique constraint on order_id on purpose: the demo shows a duplicate effect.
CREATE TABLE invoices (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id    text        NOT NULL,
  total_cents int         NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE processed_events (
  event_id     uuid PRIMARY KEY,
  processed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE order_state (          -- one row per order (Scenario - The fix)
  order_id text PRIMARY KEY,
  version  int  NOT NULL,
  status   text NOT NULL
);
CREATE TABLE sent_emails (          -- stands in for the email provider
  id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  consumer text NOT NULL,
  order_id text NOT NULL,
  subject  text NOT NULL,
  sent_at  timestamptz NOT NULL DEFAULT now()
);
