import { createClaudeCodeFixtureSnapshot } from "./fixtures.js";

export const claudeCodeFixtureSnapshotJson = JSON.stringify(
  createClaudeCodeFixtureSnapshot(),
  null,
  2
);
