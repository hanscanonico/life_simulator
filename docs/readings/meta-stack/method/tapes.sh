#!/bin/bash
# DOMINANT: the first row of "commonest metabolism tapes" on the pre-deep world; DEEP: the
# "commonest deep solver" on the first stored world after the deep rung's first epoch.
set -euo pipefail
O="$1"; L="$O/target/release/landscape"; D="$O/data"
while read -r run pre post; do
  dom=$(awk '/^commonest metabolism tapes/{f=1;next} f && /hex:/{print $1; exit}' "$O/census/$run-e$pre.txt")
  domrow=$(awk '/^commonest metabolism tapes/{f=1;next} f && /n=/{print; exit}' "$O/census/$run-e$pre.txt" | tr -s ' ')
  deep=$(grep '^commonest deep solver' "$O/census/$run-e$post.txt" | grep -o 'hex:[0-9a-f]*')
  deepn=$(grep '^commonest deep solver' "$O/census/$run-e$post.txt" | grep -o 'n=[0-9]*')
  echo "$run $pre $post $dom $deep |$domrow| $deepn"
  nice "$L" distance "$dom" "$deep" --params "$D/$run/child.json" > "$O/distance/$run.txt"
done <<LIST
4845 21000 22000
4862 21000 22000
4863 21000 23000
4871 22000 24000
4890 22000 23000
4952 23000 29000
4961 21000 22000
4979 40000 42000
4980 22000 23000
LIST
