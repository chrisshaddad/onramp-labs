-- Remove every index on orders the lab added (including INVALID ones from a failed CONCURRENTLY).
DO $$
DECLARE idx regclass;
BEGIN
  FOR idx IN SELECT indexrelid::regclass FROM pg_index
             WHERE indrelid = 'orders'::regclass
               AND indexrelid::regclass::text NOT IN ('orders_pkey', 'idx_orders_org_created')
  LOOP
    EXECUTE format('DROP INDEX %s', idx);
    RAISE NOTICE 'dropped %', idx;
  END LOOP;
END $$;
