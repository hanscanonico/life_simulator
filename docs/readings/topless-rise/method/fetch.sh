#!/bin/bash
# Fetch the three stored worlds (FIRST FIFTH LAST from worlds.csv) of one child, SELECT only.
set -euo pipefail
RUN=$1; FIRST=$2; FIFTH=$3; LAST=$4
mkdir -p worlds/$RUN
ssh mini-pc-lan 'docker exec -i life-simulator-db-1 psql -U life_simulator -d life_simulator_production -At -F "|"' <<SQL \
  | while IFS='|' read -r EPOCH HEX; do printf '%s' "$HEX" | xxd -r -p > worlds/$RUN/e$EPOCH.lsnp; done
SELECT epoch, encode(blob, 'hex') FROM snapshots
WHERE run_id = $RUN AND epoch IN ($FIRST, $FIFTH, $LAST) AND blob IS NOT NULL ORDER BY epoch;
SQL
for E in $FIRST $FIFTH $LAST; do test -s worlds/$RUN/e$E.lsnp || { echo "missing $RUN e$E" >&2; exit 1; }; done
