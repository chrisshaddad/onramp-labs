// Part 1, before the fix: one invoice per message. Group "invoicing".
// The work happens first, the offset commit (ack) second. A crash in between means the
// restarted consumer gets the same message again, and inserts a second invoice.
import { pool } from '../db.ts';
import { shortId } from '../events.ts';
import { runConsumer } from '../kafka.ts';

export default (crash: boolean) =>
  runConsumer('naive', 'invoicing', crash, async (event, { offset, log, ack }) => {
    if (event.type !== 'order.placed') return ack();
    const { orderId, totalCents } = event.data;

    await pool.query(
      `INSERT INTO invoices (order_id, total_cents)
         VALUES ($1, $2)`, [orderId, totalCents]);
    log(`${orderId} ${event.type} id=${shortId(event.id)} offset=${offset} -> invoice inserted`);

    await ack();   // offset commit. With --crash, the process dies here.
  });
