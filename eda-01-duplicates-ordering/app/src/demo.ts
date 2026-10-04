// The demo CLI: `demo <command>`. Every command prints a few plain lines and finishes on its own.
import { applySchema, ensureSchema, pool } from './db.ts';
import { orderCancelled, orderPlaced, shortId } from './events.ts';
import { deleteGroups, publish, recreateTopic, TOPIC, withAdmin, type Sent } from './kafka.ts';
import invoiceNaive from './consumers/invoice-naive.ts';
import invoiceDedup from './consumers/invoice-dedup.ts';
import notifyNaive from './consumers/notify-naive.ts';
import notifyVersioned from './consumers/notify-versioned.ts';

const CONSUMERS: Record<string, (crash: boolean) => Promise<void>> = {
  'naive': invoiceNaive,
  'dedup': invoiceDedup,
  'notify-naive': notifyNaive,
  'notify-versioned': notifyVersioned,
};
const GROUPS = { dup: ['invoicing'], order: ['notify-naive', 'notify-versioned'] };

const USAGE = `usage: demo <command>
  reset                          drop and recreate everything (before the session)
  setup dup | setup order        fresh start for part 1 (duplicates) or part 2 (out of order)
  send <orderId>                 publish order.placed #1
  send-out-of-order <orderId>    publish order.cancelled #2, then order.placed #1
  consume naive|dedup [--crash]  group invoicing
  consume notify-naive           group notify-naive
  consume notify-versioned       group notify-versioned
  invoices <orderId>             invoices for the order
  state <orderId>                the order_state row
  emails <orderId>               emails sent for the order`;

function printSent(sent: Sent[]) {
  for (const { event, partition, offset } of sent) {
    console.log(`sent ${event.data.orderId} ${event.type} #${event.data.orderVersion} ` +
      `id=${shortId(event.id)} partition=${partition} offset=${offset}`);
  }
}

async function main(argv: string[]) {
  const [cmd, arg, ...rest] = argv;
  const needId = () => {
    if (!arg) throw new Error(`demo ${cmd} needs an order id, e.g. demo ${cmd} o_42`);
    return arg;
  };

  switch (cmd) {
    case 'reset': {
      await applySchema();
      console.log('tables dropped and recreated: invoices, processed_events, order_state, sent_emails');
      await withAdmin(async (admin) => {
        await recreateTopic(admin);
        console.log(`topic ${TOPIC} recreated (1 partition)`);
        const groups = [...GROUPS.dup, ...GROUPS.order];
        await deleteGroups(admin, groups);
        console.log(`consumer groups deleted: ${groups.join(', ')}`);
      });
      console.log('eda-01 ready');
      return;
    }

    case 'setup': {
      if (arg !== 'dup' && arg !== 'order') throw new Error('usage: demo setup dup | demo setup order');
      await ensureSchema();
      const tables = arg === 'dup' ? 'invoices, processed_events' : 'order_state, sent_emails';
      await pool.query(`TRUNCATE ${tables} RESTART IDENTITY`);
      await withAdmin(async (admin) => {
        await recreateTopic(admin);
        await deleteGroups(admin, GROUPS[arg]);
      });
      console.log(`emptied ${tables}; topic ${TOPIC} recreated (1 partition); deleted group ${GROUPS[arg].join(', ')}`);
      console.log(arg === 'dup' ? 'part 1 ready' : 'part 2 ready');
      return;
    }

    case 'send':
      printSent(await publish([orderPlaced(needId(), 1)]));
      return;

    case 'send-out-of-order':
      printSent(await publish([orderCancelled(needId(), 2), orderPlaced(needId(), 1)]));
      return;

    case 'consume': {
      const run = CONSUMERS[arg ?? ''];
      if (!run) throw new Error(`demo consume needs one of: ${Object.keys(CONSUMERS).join(', ')}`);
      await run(rest.includes('--crash'));
      return;
    }

    case 'invoices': {
      const { rows } = await pool.query(
        `SELECT id, to_char(created_at, 'YYYY-MM-DD HH24:MI:SS.MS') AS created_at
           FROM invoices WHERE order_id = $1 ORDER BY id`, [needId()]);
      console.log(`${arg}: ${rows.length} ${rows.length === 1 ? 'invoice' : 'invoices'}`);
      for (const r of rows) console.log(`  id=${r.id}  created_at=${r.created_at}`);
      return;
    }

    case 'state': {
      const { rows } = await pool.query('SELECT order_id, version, status FROM order_state WHERE order_id = $1', [needId()]);
      console.log(rows.length ? `${rows[0].order_id} | ${rows[0].version} | ${rows[0].status}` : `${arg}: no row in order_state`);
      return;
    }

    case 'emails': {
      const { rows } = await pool.query('SELECT consumer, subject FROM sent_emails WHERE order_id = $1 ORDER BY id', [needId()]);
      console.log(`${arg}: ${rows.length} ${rows.length === 1 ? 'email' : 'emails'}`);
      for (const r of rows) console.log(`  ${r.consumer.padEnd(17)} "${r.subject}"`);
      return;
    }

    default:
      console.log(USAGE);
      if (cmd && cmd !== 'help' && cmd !== '--help') process.exitCode = 1;
  }
}

try {
  await main(process.argv.slice(2));
} catch (err) {
  console.error(`error: ${(err as Error).message}`);
  process.exitCode = 1;
} finally {
  await pool.end();
}
process.exit();
