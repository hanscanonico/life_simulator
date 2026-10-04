#!/bin/bash
# The locked H-rise-code reading of one child: its first settled, fifth-decile and last world.
set -euo pipefail
RUN=$1; FIRST=$2; FIFTH=$3; LAST=$4
./target/release/landscape loadbearing --first worlds/$RUN/e$FIRST.lsnp \
  --fifth worlds/$RUN/e$FIFTH.lsnp --last worlds/$RUN/e$LAST.lsnp \
  --params params/$RUN.json > out/$RUN.txt
