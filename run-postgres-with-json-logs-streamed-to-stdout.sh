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

# Start Postgres in the background using the official entrypoint.
# This handles database initialization and config automatically.
docker-entrypoint.sh postgres &
pid=$!

# Wait until Postgres accepts connections (needed for pg_rotate_logfile)
for i in {1..60}; do
  if psql "$DATABASE_URL" -qAt -c "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

LOG_FILE="$PGDATA/log/postgresql.json"

# Backup original log file
mv -f "$LOG_FILE" "$LOG_FILE.prev"

# Create a named pipe (FIFO) for Postgres to write its JSON logs into
mkfifo "$LOG_FILE"
chown postgres:postgres "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Relay: read JSON logs from the FIFO, send them both to a file
# and to stdout (for Railway logs). "tee" duplicates the stream.
# Each line has "error_severity" renamed to "level" for nicer JSON.
cat "$LOG_FILE" | tee /tmp/pglog.raw | \
while IFS= read -r line; do
  # Replace "error_severity" key with "level"
  line=${line//error_severity/level}
  # Print each line to container stdout (Railway log collector)
  printf "%s\n" "$line" > /proc/1/fd/1 || true
done &

# Force logger to close/reopen -> it will attach to the FIFO now
psql "$DATABASE_URL" -qAt -c "SELECT pg_rotate_logfile();"

# Wait for the Postgres process to exit, keeping the container alive
wait $pid
