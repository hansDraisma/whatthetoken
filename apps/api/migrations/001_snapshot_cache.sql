CREATE TABLE IF NOT EXISTS snapshot_cache (
    owner_key text PRIMARY KEY CHECK (length(owner_key) = 64),
    payload jsonb NOT NULL CHECK (jsonb_typeof(payload) = 'object'),
    updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE snapshot_cache IS
    'Sanitized WhatTheToken snapshot caches, scoped by a SHA-256 sync-token digest.';
