// Part 2, before the fix: one email per event, in arrival order. Group "notify-naive".
// When cancelled #2 arrives before placed #1, the customer's last email says "confirmed".
import { pool, sendEmail, SUBJECT } from '../db.ts';
import { runConsumer } from '../kafka.ts';

export default (crash: boolean) =>
  runConsumer('notify-naive', 'notify-naive', crash, async (event, { log, ack }) => {
    const { orderId, orderVersion } = event.data;
    const subject = SUBJECT[event.type];

    await sendEmail(pool, 'notify-naive', orderId, subject);
    log(`${orderId} ${event.type} #${orderVersion} -> email: "${subject}"`);

    await ack();
  });
