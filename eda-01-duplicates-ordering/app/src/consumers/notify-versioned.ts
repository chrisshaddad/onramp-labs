// Part 2, the fix: keep one row per order with the highest version seen, and act only when
// an event moves it forward. Group "notify-versioned". Whatever order the broker delivers,
// placed #1 after cancelled #2 is skipped.
import { pool, sendEmail, SUBJECT } from '../db.ts';
import { runConsumer } from '../kafka.ts';

const STATUS = { 'order.placed': 'placed', 'order.cancelled': 'cancelled' } as const;

export default async (crash: boolean) => {
  const db = await pool.connect();
  try {
    await runConsumer('notify-versioned', 'notify-versioned', crash, async (event, { log, ack }) => {
      const { orderId } = event.data;
      const version = event.data.orderVersion ?? 0;   // events from before orderVersion count as 0
      const line = `${orderId} ${event.type} #${version} ->`;

      await db.query('BEGIN');
      // The SQL from "Scenario - The fix", word for word.
      const written = await db.query(`
        -- one row per order
        INSERT INTO order_state AS s
        VALUES ($1, $2, $3)
        ON CONFLICT (order_id) DO UPDATE
          SET version = $2, status = $3
          WHERE s.version < $2;
        -- 0 rows: older event, skip it
      `, [orderId, version, STATUS[event.type]]);

      if (written.rowCount === 0) {
        const { rows } = await db.query('SELECT version FROM order_state WHERE order_id = $1', [orderId]);
        await db.query('COMMIT');
        log(`${line} skipped (have #${rows[0].version})`);
      } else {
        // 1 row: the state moved forward. Send the email in the same transaction.
        const subject = SUBJECT[event.type];
        await sendEmail(db, 'notify-versioned', orderId, subject);
        await db.query('COMMIT');
        log(`${line} email: "${subject}"`);
      }

      await ack();   // then the offset commit
    });
  } finally {
    db.release();
  }
};
