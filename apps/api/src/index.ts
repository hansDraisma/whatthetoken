import { NeonSnapshotRepository } from "./repository.js";
import { makeServer } from "./server.js";

const databaseURL = process.env.DATABASE_URL;
if (!databaseURL) throw new Error("DATABASE_URL is required");

const port = Number(process.env.PORT ?? "4318");
const host = process.env.HOST ?? "127.0.0.1";
const server = makeServer(new NeonSnapshotRepository(databaseURL));

server.listen(port, host, () => {
  console.log(`WhatTheToken sync API listening at http://${host}:${port}`);
});
