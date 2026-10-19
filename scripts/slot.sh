#!/usr/bin/env bash
# Pick the deterministic-but-unpredictable ping slot for a given UTC date.
#
# Prints: "<hour> <jitter_seconds>"
#
# The slot is derived from a hash of the date (plus PING_SEED, if set), so every
# run on the same day agrees on the same slot without storing any state. The
# hour is uniform over 0-23; the jitter spreads the ping across the first
# JITTER_MINUTES of that hour so it does not land on the cron tick exactly.
set -euo pipefail

date_key="${1:-$(date -u +%F)}"
seed="${PING_SEED:-}"
jitter_minutes="${JITTER_MINUTES:-20}"

n=$((16#$(printf '%s' "${date_key}${seed}" | sha256sum | cut -c1-8)))

hour=$(( n % 24 ))
jitter=$(( (n / 24) % (jitter_minutes * 60 + 1) ))

echo "$hour $jitter"
