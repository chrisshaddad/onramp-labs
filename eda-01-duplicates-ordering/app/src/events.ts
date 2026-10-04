// The event contract: the envelope from "The event envelope", the schema from
// "A contract you can enforce" (Zod 4). The producer and every consumer validate with it.
//
// data.orderVersion is new to this lab and optional, so the schema is still v1: an additive
// change ("Versioning - What breaks a consumer?"). Old events don't have it; old consumers ignore it.
import { randomUUID } from 'node:crypto';
import { z } from 'zod';

export const OrderPlacedV1 = z.object({
  id: z.uuid(), type: z.literal('order.placed'), version: z.literal(1),
  occurredAt: z.iso.datetime(), tenantId: z.string(), correlationId: z.string().optional(),
  data: z.object({ orderId: z.string(), totalCents: z.number().int(), currency: z.string(),
                   orderVersion: z.number().int().optional() }),
});

export const OrderCancelledV1 = z.object({
  id: z.uuid(), type: z.literal('order.cancelled'), version: z.literal(1),
  occurredAt: z.iso.datetime(), tenantId: z.string(), correlationId: z.string().optional(),
  data: z.object({ orderId: z.string(), orderVersion: z.number().int().optional() }),
});

export const OrderEvent = z.discriminatedUnion('type', [OrderPlacedV1, OrderCancelledV1]);
export type OrderEvent = z.infer<typeof OrderEvent>;

const TENANT = 'acme';

export function orderPlaced(orderId: string, orderVersion: number): OrderEvent {
  return OrderPlacedV1.parse({
    id: randomUUID(), type: 'order.placed', version: 1,
    occurredAt: new Date().toISOString(), tenantId: TENANT,
    data: { orderId, totalCents: 4200, currency: 'EUR', orderVersion },
  });
}

export function orderCancelled(orderId: string, orderVersion: number): OrderEvent {
  return OrderCancelledV1.parse({
    id: randomUUID(), type: 'order.cancelled', version: 1,
    occurredAt: new Date().toISOString(), tenantId: TENANT,
    data: { orderId, orderVersion },
  });
}

// On receipt: JSON, then the schema. An invalid event is logged and skipped by the consumer.
export function parseEvent(value: Buffer | null): { event: OrderEvent } | { error: string } {
  try {
    const result = OrderEvent.safeParse(JSON.parse(value?.toString() ?? ''));
    if (result.success) return { event: result.data };
    return { error: result.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ') };
  } catch (err) {
    return { error: `not JSON: ${(err as Error).message}` };
  }
}

// What the logs show: the first 8 characters of the event id.
export const shortId = (id: string) => id.slice(0, 8);
