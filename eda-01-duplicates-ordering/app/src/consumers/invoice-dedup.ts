// Part 1, the fix: save the event id in the same transaction as the effect. Group "invoicing".
// A crash after COMMIT and before the ack still redelivers the message, but the redelivery
// finds its event id already saved and skips: no second invoice.
import { pool, sharedParams } from '../db.ts';
import { shortId } from '../events.ts';
import { runConsumer } from '../kafka.ts';

export default async (crash: boolean) => {
  const db = await pool.connect();
  try {
    await runConsumer('dedup', 'invoicing', crash, async (event, { offset, log, ack }) => {
      if (event.type !== 'order.placed') return ack();
      const { orderId, totalCents } = event.data;
      const line = `${orderId} ${event.type} id=${shortId(event.id)} offset=${offset} ->`;

      // The SQL from "Duplicates are normal", word for word. As on the slide, one parameter
      // list for the whole transaction: $1 event id, $2 order id, $3 total.
      const sql = sharedParams(db, [event.id, orderId, totalCents], ['uuid', 'text', 'int']);

      await db.query('BEGIN');
      const first = await sql(`
        INSERT INTO processed_events (event_id)
          VALUES ($1) ON CONFLICT DO NOTHING`);
      if (first.rowCount === 0) {
        // 0 rows: a duplicate. ROLLBACK, ack, skip.
        await db.query('ROLLBACK');
        log(`${line} duplicate, skipped`);
        return ack();
      }
      // 1 row: the first time. Apply the effect.
      await sql(`
        INSERT INTO invoices (order_id, total_cents)
          VALUES ($2, $3)`);
      await db.query('COMMIT');
      log(`${line} invoice inserted, transaction committed`);

      await ack();   // then ack (the offset commit). With --crash, the process dies here.
    });
  } finally {
    db.release();
  }
};
