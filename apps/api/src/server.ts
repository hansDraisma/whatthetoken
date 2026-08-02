import { createHash } from "node:crypto";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { snapshotCacheSchema } from "@whatthetoken/core";
import type { SnapshotRepository } from "./repository.js";

const maximumBodyBytes = 1_000_000;

function send(response: ServerResponse, status: number, body?: unknown): void {
  response.statusCode = status;
  response.setHeader("Cache-Control", "no-store");
  if (body === undefined) {
    response.end();
    return;
  }
  response.setHeader("Content-Type", "application/json");
  response.end(JSON.stringify(body));
}

function ownerKey(request: IncomingMessage): string | undefined {
  const header = request.headers.authorization;
  if (!header?.startsWith("Bearer ")) return undefined;
  const token = header.slice("Bearer ".length);
  if (token.length < 32 || token.length > 512) return undefined;

  // The raw sync token is never logged or stored.
  return createHash("sha256").update(token).digest("hex");
}

async function readJSON(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.length;
    if (size > maximumBodyBytes) throw new Error("payload_too_large");
    chunks.push(buffer);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

export function makeServer(repository: SnapshotRepository) {
  return createServer(async (request, response) => {
    try {
      if (request.method === "GET" && request.url === "/health") {
        await repository.health();
        send(response, 200, { status: "ok", database: "neon" });
        return;
      }

      if (request.url !== "/v1/snapshot-cache") {
        send(response, 404, { error: "not_found" });
        return;
      }

      const key = ownerKey(request);
      if (!key) {
        send(response, 401, { error: "unauthorized" });
        return;
      }

      if (request.method === "GET") {
        const cache = await repository.get(key);
        if (!cache) {
          send(response, 404, { error: "cache_not_found" });
          return;
        }
        send(response, 200, cache);
        return;
      }

      if (request.method === "PUT") {
        const parsed = snapshotCacheSchema.safeParse(await readJSON(request));
        if (!parsed.success) {
          send(response, 422, { error: "invalid_snapshot_cache" });
          return;
        }
        await repository.put(key, parsed.data);
        send(response, 204);
        return;
      }

      response.setHeader("Allow", "GET, PUT");
      send(response, 405, { error: "method_not_allowed" });
    } catch (error) {
      const code = error instanceof Error && error.message === "payload_too_large" ? 413 : 500;
      send(response, code, { error: code === 413 ? "payload_too_large" : "internal_error" });
    }
  });
}
