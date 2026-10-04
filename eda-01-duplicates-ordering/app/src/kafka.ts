// Kafka: the producer, the consumer loop every consumer shares, and the admin steps for setup.
// Client: @confluentinc/kafka-javascript, KafkaJS-compatible API on top of librdkafka.
import { KafkaJS } from '@confluentinc/kafka-javascript';
import { parseEvent, type OrderEvent } from './events.ts';

export const TOPIC = 'orders';
const IDLE_MS = 3000;              // a consumer stops after 3 s with no new messages
const SESSION_TIMEOUT_MS = 6000;   // the broker minimum; the default is 45 s (see README)

const kafka = new KafkaJS.Kafka({
  kafkaJS: {
    clientId: 'eda-01',
    brokers: (process.env.KAFKA_BROKERS ?? 'kafka:9092').split(','),
    logLevel: KafkaJS.logLevel.ERROR,
  },
});

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// ---------------------------------------------------------------- producer

export type Sent = { event: OrderEvent; partition: number; offset: string };

// Sends one at a time, in order, keyed by orderId: same key, same partition, same order.
export async function publish(events: OrderEvent[]): Promise<Sent[]> {
  const producer = kafka.producer({ kafkaJS: { acks: -1 } });
  await producer.connect();
  try {
    const sent: Sent[] = [];
    for (const event of events) {
      const [meta] = await producer.send({
        topic: TOPIC,
        messages: [{ key: event.data.orderId, value: JSON.stringify(event) }],
      });
      sent.push({ event, partition: meta.partition, offset: String(meta.baseOffset ?? meta.offset) });
    }
    return sent;
  } finally {
    await producer.disconnect();
  }
}

// ---------------------------------------------------------------- consumer

export type Ctx = {
  offset: string;
  log: (line: string) => void;
  ack: () => Promise<void>;     // the offset commit; with --crash, the process dies here instead
};
export type Handler = (event: OrderEvent, ctx: Ctx) => Promise<void>;

export async function runConsumer(name: string, groupId: string, crash: boolean, handle: Handler) {
  const log = (line: string) => console.log(`[${name}] ${line}`);
  const consumer = kafka.consumer({
    kafkaJS: {
      groupId,
      fromBeginning: true,          // a new group starts at offset 0
      autoCommit: false,            // commit only after a message is fully handled
      sessionTimeout: SESSION_TIMEOUT_MS,
      heartbeatInterval: 2000,
    },
    // Static membership: a restarted consumer with the same instance id takes back its
    // partition at once, instead of waiting for the dead member's session to time out.
    'group.instance.id': `${groupId}-1`,
  });

  await consumer.connect();
  await consumer.subscribe({ topics: [TOPIC] });

  let lastActivity = 0;   // set once the partition is assigned, then after every message
  let busy = false;
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      busy = true;
      const ack = async () => {
        if (crash) {
          log('CRASH before offset commit');
          process.exit(1);          // no commit, no LeaveGroup: like a killed process
        }
        await consumer.commitOffsets([{ topic, partition, offset: (BigInt(message.offset) + 1n).toString() }]);
      };
      try {
        const parsed = parseEvent(message.value);
        if ('error' in parsed) {
          log(`offset=${message.offset} invalid event, skipped: ${parsed.error}`);
          await ack();
        } else {
          await handle(parsed.event, { offset: message.offset, log, ack });
        }
      } catch (err) {
        log(`ERROR at offset=${message.offset}, not committed: ${(err as Error).message}`);
        process.exit(2);
      }
      lastActivity = Date.now();
      busy = false;
    },
  });

  await new Promise<void>((resolve) => {
    const timer = setInterval(() => {
      if (lastActivity === 0 && consumer.assignment().length > 0) lastActivity = Date.now();
      if (lastActivity > 0 && !busy && Date.now() - lastActivity >= IDLE_MS) {
        clearInterval(timer);
        resolve();
      }
    }, 100);
  });
  log('idle, exiting');
  await consumer.disconnect();
}

// ---------------------------------------------------------------- admin (demo reset / setup)

type Admin = ReturnType<typeof kafka.admin>;

export async function withAdmin<T>(fn: (admin: Admin) => Promise<T>): Promise<T> {
  const admin = kafka.admin();
  await admin.connect();
  try {
    return await fn(admin);
  } finally {
    await admin.disconnect();
  }
}

// Delete and create topic orders with 1 partition. Deletion finishes in the background,
// so creating it again can fail for a moment: retry for up to 15 s.
export async function recreateTopic(admin: Admin) {
  try {
    await admin.deleteTopics({ topics: [TOPIC], timeout: 10000 });
  } catch (err) {
    if (!/UNKNOWN_TOPIC/.test(String((err as any).type ?? err))) throw err;
  }
  const deadline = Date.now() + 15000;
  for (;;) {
    let created = false;
    let error: unknown;
    try {
      created = await admin.createTopics({ topics: [{ topic: TOPIC, numPartitions: 1, replicationFactor: 1 }] });
    } catch (err) {
      error = err;
    }
    if (created) return;
    if (Date.now() > deadline) throw error ?? new Error(`topic ${TOPIC} still exists after 15 s`);
    await sleep(250);
  }
}

// Kafka protocol error codes
const GROUP_ID_NOT_FOUND = 69, NON_EMPTY_GROUP = 68;
const RETRY = [14, 15, 16, NON_EMPTY_GROUP];   // coordinator loading / not available / moved, group not empty

// Delete consumer groups (and their committed offsets). A group that still holds a member
// can't be deleted: after a crash, or any clean exit, a static member stays registered until
// its session times out (6 s here). Wait for that, then delete. On a fresh broker the first
// call also waits for the offsets topic (the group coordinator) to be created.
export async function deleteGroups(admin: Admin, groups: string[]) {
  const deadline = Date.now() + 2 * SESSION_TIMEOUT_MS + 3000;
  let pending = groups;
  let announced = false;
  for (;;) {
    let failed: { groupId: string; code: number; message: string }[];
    try {
      await admin.deleteGroups(pending);
      return;
    } catch (err: any) {
      if (!Array.isArray(err.groups)) throw err;
      failed = err.groups.filter((r: any) => r.error)
        .map((r: any) => ({ groupId: r.groupId, code: r.errorCode, message: r.error.message }));
    }
    failed = failed.filter((f) => f.code !== GROUP_ID_NOT_FOUND);
    if (failed.length === 0) return;
    const fatal = failed.find((f) => !RETRY.includes(f.code)) ?? (Date.now() > deadline && failed[0]);
    if (fatal) throw new Error(`deleting group ${fatal.groupId}: ${fatal.message}`);
    const busy = failed.filter((f) => f.code === NON_EMPTY_GROUP).map((f) => f.groupId);
    if (busy.length && !announced) {
      console.log(`waiting for ${busy.join(', ')}: the last consumer's session is still open (up to ${SESSION_TIMEOUT_MS / 1000} s)`);
      announced = true;
    }
    pending = failed.map((f) => f.groupId);
    await sleep(500);
  }
}
