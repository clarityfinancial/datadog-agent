#!/bin/bash
set -e

# Parse DATABASE_URL into components for Datadog DBM
# Expected format: postgresql://user:password@host:port/dbname or postgres://user:password@host:port/dbname
if [ -n "$DATABASE_URL" ]; then
  # Strip protocol
  url="${DATABASE_URL#*://}"

  # Extract user:password (use %@* to handle passwords containing @)
  userpass="${url%@*}"
  DB_USER="${userpass%%:*}"
  DB_PASS="${userpass#*:}"

  # Extract host:port/dbname (use ##*@ to grab everything after the last @)
  hostportdb="${url##*@}"
  hostport="${hostportdb%%/*}"
  DB_HOST="${hostport%%:*}"
  DB_PORT="${hostport#*:}"
  DB_NAME="${hostportdb#*/}"

  # Strip any query params from dbname
  DB_NAME="${DB_NAME%%\?*}"

  # Default port if not specified or if host had no port separator
  if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT=5432
  fi

  echo "Configuring Datadog DBM for host: ${DB_HOST}:${DB_PORT}/${DB_NAME}"

  mkdir -p /etc/datadog-agent/conf.d/postgres.d

  cat > /etc/datadog-agent/conf.d/postgres.d/conf.yaml <<EOF
init_config:

instances:
  - dbm: true
    host: ${DB_HOST}
    port: ${DB_PORT}
    username: ${DB_USER}
    password: ${DB_PASS}
    dbname: ${DB_NAME}
    ssl: require
    reported_hostname: ${DB_HOST}
    tags:
      - "env:${DD_ENV:-production}"
      - "service:${DD_SERVICE:-clarity-db}"
    query_samples:
      enabled: true
    query_metrics:
      enabled: true
    query_activity:
      enabled: true
EOF

  echo "Datadog DBM configuration written successfully."
else
  echo "WARNING: DATABASE_URL not set — skipping DBM configuration."
fi

# Hand off to the default Datadog agent entrypoint
exec /bin/entrypoint.sh "$@"
