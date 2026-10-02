#!/bin/bash
# Heritability by planting, the locked rule (the landscape defaults: 4x4 centre block,
# seeds 2001-2003, 2 000 epochs, readings every 500), once per deep rung the first deep
# solver carries and the child reached; one extension row (4890 xor) plants that rung's
# own first solver, which the first deep solver does not carry.
set -uo pipefail
O="$1"; L="$O/target/release/landscape"; D="$O/data"; mkdir -p "$O/plant"
while read -r run rung source deep; do
  out="$O/plant/$run-$rung.txt"
  [ -s "$out" ] && grep -q '^verdict' "$out" && continue
  start=$(date +%s)
  nice -n 10 "$L" plant --snapshot "$D/$run/e60000.lsnp" --params "$D/$run/child.json" \
    --deep "$deep" --rung "$rung" --source "$D/$run/e$source.lsnp" > "$out.tmp" 2>&1 && mv "$out.tmp" "$out"
  echo "$run $rung $(( $(date +%s) - start ))s $(grep '^verdict' "$out" 2>/dev/null)"
done <<LIST
4845 xor 22000 hex:3c3e3c7b3c5b7e7b107e2e7d212b3e375d5b3e3c7d3c5b7e5b5b5b5d3c2e2b2d
4845 equ 22000 hex:3c3e3c7b3c5b7e7b107e2e7d212b3e375d5b3e3c7d3c5b7e5b5b5b5d3c2e2b2d
4862 equ 22000 hex:002e3c3c5b7b7e7e7e217b2c7b7e5d2b2c7e2c3e5b5b7b2b2e3c217e7e3e5b2c
4862 xor 22000 hex:002e3c3c5b7b7e7e7e217b2c7b7e5d2b2c7e2c3e5b5b7b2b2e3c217e7e3e5b2c
4863 equ 23000 hex:3c2e3c7e5b7e7b7e219b7b7e7b7b5d5b643c877d2dc12c7b5d777e2100f42e2e
4863 xor 23000 hex:3c2e3c7e5b7e7b7e219b7b7e7b7b5d5b643c877d2dc12c7b5d777e2100f42e2e
4871 xor 24000 hex:3c5b3c7b7e7e3e7e7b7e213e245d84002c2e2d5d852b3c5d003e7b002b977b7d
4871 equ 24000 hex:3c5b3c7b7e7e3e7e7b7e213e245d84002c2e2d5d852b3c5d003e7b002b977b7d
4890 equ 23000 hex:002d2c3e7b3e2c2e2c5b7b5b7e00217e7d5d215d5b5d7d2d3c2d2cd77e7e7e00
4952 equ 29000 hex:7b42063c3c5b7e7b7e212e3e7d5d5df37d3c2d2e212c2b2c2c7d2e213e2e5d21
4952 xor 29000 hex:7b42063c3c5b7e7b7e212e3e7d5d5df37d3c2d2e212c2b2c2c7d2e213e2e5d21
4961 xor 22000 hex:2e7b2b2c7e7d2c5b213c5b2e5b3e7e7b7e2e2c7d215d5b5b5d2c2d5d5d2e2e2e
4961 equ 22000 hex:2e7b2b2c7e7d2c5b213c5b2e5b3e7e7b7e2e2c7d215d5b5b5d2c2d5d5d2e2e2e
4979 equ 42000 hex:7b2c7e3c7e5b7e7b213c2c7b5d002b5b2d7e7b5d7b2d3e7d7b3e212c2c7d7d3e
4980 equ 23000 hex:3e7b2c5b3e2c7b7e005b7e7d215d2e7d7b2d3e3e003e2c2e7e3c2c2e002c5d2d
4890 xor 29000 hex:5b007b3e2b3e2c7b7e7e3c5b7e2e217d5d3e7e2d2b2d215b7d7d2e3e7d217d2b
LIST
