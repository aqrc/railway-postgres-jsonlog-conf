#!/bin/bash

# ──────────────────────────────────────────────────────────────
# PostgreSQL startup wrapper with real-time JSON log streaming.
# 
# This script replaces the default CMD ["postgres"] used in the
# official postgres image. It:
#   1. Prepares a FIFO for JSON logs inside $PGDATA/log/
#   2. Starts Postgres normally using docker-entrypoint.sh
#   3. Streams structured logs in real time to stdout (for Railway)
#   4. Renames "error_severity" → "level" in each JSON log line
#   5. Keeps the container alive until Postgres exits
# ──────────────────────────────────────────────────────────────

# Ensure the log directory exists
mkdir -p "$PGDATA/log"

# Remove any stale log FIFO from previous runs
rm -f "$PGDATA/log/postgresql.json"

# Create a named pipe (FIFO) for Postgres to write its JSON logs into
mkfifo "$PGDATA/log/postgresql.json"

# Relay: read JSON logs from the FIFO, send them both to a file
# and to stdout (for Railway logs). "tee" duplicates the stream.
# Each line has "error_severity" renamed to "level" for nicer JSON.
(cat "$PGDATA/log/postgresql.json" | tee /tmp/pglog.raw | \
while IFS= read -r line; do
  # Replace "error_severity" key with "level"
  line=${line//error_severity/level}
  # Print each line to container stdout (Railway log collector)
  printf "%s\n" "$line" > /proc/1/fd/1 || true
done) &


# Hand off control to the official entrypoint (foreground)
exec docker-entrypoint.sh postgres
