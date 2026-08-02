import { neon } from "@neondatabase/serverless";
import type { SnapshotCache } from "@whatthetoken/core";

export interface SnapshotRepository {
  health(): Promise<void>;
  get(ownerKey: string): Promise<SnapshotCache | undefined>;
  put(ownerKey: string, cache: SnapshotCache): Promise<void>;
}

export class NeonSnapshotRepository implements SnapshotRepository {
  private readonly sql;

  constructor(databaseURL: string) {
    this.sql = neon(databaseURL);
  }

  async health(): Promise<void> {
    await this.sql`SELECT 1`;
  }

  async get(ownerKey: string): Promise<SnapshotCache | undefined> {
    const rows = await this.sql`
      SELECT payload
      FROM snapshot_cache
      WHERE owner_key = ${ownerKey}
    `;
    return rows[0]?.payload as SnapshotCache | undefined;
  }

  async put(ownerKey: string, cache: SnapshotCache): Promise<void> {
    await this.sql`
      INSERT INTO snapshot_cache (owner_key, payload, updated_at)
      VALUES (${ownerKey}, ${JSON.stringify(cache)}::jsonb, now())
      ON CONFLICT (owner_key) DO UPDATE
      SET payload = EXCLUDED.payload,
          updated_at = now()
    `;
  }
}
