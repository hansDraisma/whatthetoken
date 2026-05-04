import { createClaudeCodeFixtureSnapshot } from "./fixtures";

export const claudeCodeFixtureSnapshotJson = JSON.stringify(
  createClaudeCodeFixtureSnapshot(),
  null,
  2
);
