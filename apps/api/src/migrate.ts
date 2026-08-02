import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { neon } from "@neondatabase/serverless";

const databaseURL = process.env.DATABASE_URL;
if (!databaseURL) throw new Error("DATABASE_URL is required");

const migrationURL = new URL("../migrations/001_snapshot_cache.sql", import.meta.url);
const migration = await readFile(fileURLToPath(migrationURL), "utf8");
const sql = neon(databaseURL);
for (const statement of migration.split(/;\s*(?:\n|$)/).map((part) => part.trim()).filter(Boolean)) {
  await sql.query(statement);
}
console.log("Applied WhatTheToken Neon schema");
