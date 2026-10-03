#!/bin/bash
# SELECT-only export of each deep child's params and the stored worlds the readings need.
set -euo pipefail
D="$1"
PSQL='docker exec -i life-simulator-db-1 psql -At -U life_simulator -d life_simulator_production'
fetch() {
  echo "SELECT encode(blob, 'hex') FROM snapshots WHERE run_id = $1 AND epoch = $2" | ssh mini-pc-lan "$PSQL" | xxd -r -p > "$D/$1/e$2.lsnp"
}
while read -r run epochs; do
  mkdir -p "$D/$run"
  echo "SELECT params FROM runs WHERE id = $run" | ssh mini-pc-lan "$PSQL" > "$D/$run/child.json"
  for e in $epochs 60000; do fetch "$run" "$e"; done
done <<LIST
4845 21000 22000
4862 21000 22000
4863 21000 23000
4871 22000 24000
4890 22000 23000
4952 23000 29000 28000
4961 21000 22000
4979 40000 42000
4980 22000 23000
LIST
