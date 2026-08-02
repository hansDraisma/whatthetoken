import { once } from "node:events";
import type { AddressInfo } from "node:net";
import type { SnapshotCache } from "@whatthetoken/core";
import { afterEach, describe, expect, it } from "vitest";
import type { SnapshotRepository } from "./repository.js";
import { makeServer } from "./server.js";

const token = "synthetic-local-sync-token-32-characters";
const emptyCache: SnapshotCache = {
  schemaVersion: 1,
  snapshots: [],
  updatedAtByProvider: {},
  lastSuccessfulRefreshAtByProvider: {},
  lastErrorByProvider: {}
};

class MemoryRepository implements SnapshotRepository {
  rows = new Map<string, SnapshotCache>();
  async health() {}
  async get(ownerKey: string) { return this.rows.get(ownerKey); }
  async put(ownerKey: string, cache: SnapshotCache) { this.rows.set(ownerKey, cache); }
}

const servers: ReturnType<typeof makeServer>[] = [];

async function start(repository: SnapshotRepository) {
  const server = makeServer(repository);
  servers.push(server);
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const port = (server.address() as AddressInfo).port;
  return `http://127.0.0.1:${port}`;
}

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => new Promise<void>((resolve) => server.close(() => resolve()))));
});

describe("snapshot sync API", () => {
  it("checks the live repository on health", async () => {
    const baseURL = await start(new MemoryRepository());
    const response = await fetch(`${baseURL}/health`);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: "ok", database: "neon" });
  });

  it("requires a bearer token", async () => {
    const baseURL = await start(new MemoryRepository());
    const response = await fetch(`${baseURL}/v1/snapshot-cache`);
    expect(response.status).toBe(401);
  });

  it("round-trips a validated sanitized cache", async () => {
    const baseURL = await start(new MemoryRepository());
    const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };

    const put = await fetch(`${baseURL}/v1/snapshot-cache`, {
      method: "PUT",
      headers,
      body: JSON.stringify(emptyCache)
    });
    expect(put.status).toBe(204);

    const get = await fetch(`${baseURL}/v1/snapshot-cache`, { headers });
    expect(get.status).toBe(200);
    expect(await get.json()).toEqual(emptyCache);
  });

  it("rejects fields outside the privacy-safe cache contract", async () => {
    const baseURL = await start(new MemoryRepository());
    const response = await fetch(`${baseURL}/v1/snapshot-cache`, {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ ...emptyCache, prompt: "must not sync" })
    });
    expect(response.status).toBe(422);
  });
});
