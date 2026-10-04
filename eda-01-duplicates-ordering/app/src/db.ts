// Postgres: consumer state (invoices, processed_events, order_state, sent_emails).
import { readFileSync } from 'node:fs';
import pg from 'pg';

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL ?? 'postgres://postgres:onramp@db:5432/eda',
  max: 2,
});

const SCHEMA = '/lab/sql/schema.sql';

// Drop and recreate every table (demo reset).
export async function applySchema() {
  await pool.query(readFileSync(SCHEMA, 'utf8'));
}

// demo setup only empties tables; it creates them first if reset never ran.
export async function ensureSchema() {
  const { rows } = await pool.query(`SELECT to_regclass('public.sent_emails') IS NOT NULL AS ok`);
  if (!rows[0].ok) await applySchema();
}

// Run SQL that numbers its parameters across a whole transaction, as the slides do: $1, $2, $3
// mean the same values in every statement. "INSERT INTO invoices ... VALUES ($2, $3)" doesn't
// use $1, and Postgres must know the type of every parameter, so each statement goes out with
// all of them declared in an unused WITH clause in front of it. The statement itself is unchanged.
export function sharedParams(db: pg.PoolClient, values: unknown[], types: string[]) {
  const declare = `WITH params AS (SELECT ${types.map((t, i) => `$${i + 1}::${t}`).join(', ')})`;
  return (sql: string) => db.query(`${declare}\n${sql}`, values);
}

// Stands in for the email provider: one row per email "sent".
export const SUBJECT = {
  'order.placed': 'Your order is confirmed',
  'order.cancelled': 'Your order is cancelled',
} as const;

export async function sendEmail(db: pg.Pool | pg.PoolClient,consumer: string, orderId: string, subject: string) {
  await db.query('INSERT INTO sent_emails (consumer, order_id, subject) VALUES ($1, $2, $3)',
    [consumer, orderId, subject]);
}
