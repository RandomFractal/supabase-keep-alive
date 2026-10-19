#!/usr/bin/env bash
# Send one GET request to the Supabase REST endpoint, retrying on failure.
#
# Required env: SUPABASE_URL, SUPABASE_ANON_KEY, PING_PATH
# Optional env: PING_QUERY, ATTEMPTS, TIMEOUT
#
# The response body is never echoed on success -- it contains table rows, and
# this repo's Actions logs are public.
set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"
: "${PING_PATH:?PING_PATH is required}"

ping_query="${PING_QUERY:-select=*&limit=1}"
attempts="${ATTEMPTS:-5}"
timeout="${TIMEOUT:-30}"

url="${SUPABASE_URL%/}${PING_PATH}?${ping_query}"
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

for attempt in $(seq 1 "$attempts"); do
  status="$(curl -sS -o "$body" -w '%{http_code}' \
    --max-time "$timeout" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    -H 'Accept: application/json' \
    "$url" || echo 000)"

  if [[ "$status" =~ ^2 ]]; then
    echo "ok: HTTP $status on attempt $attempt ($(wc -c < "$body") bytes)"
    exit 0
  fi

  echo "attempt $attempt/$attempts failed: HTTP $status" >&2

  # A 4xx is a configuration problem (bad key, wrong path) -- retrying will not
  # fix it, so show the error and fail fast. PostgREST error bodies carry a
  # message and hint, not row data, so they are safe to log.
  if [[ "$status" =~ ^4 ]]; then
    head -c 300 "$body" >&2
    echo >&2
    echo 'client error -- not retrying' >&2
    exit 1
  fi

  [[ "$attempt" -lt "$attempts" ]] && sleep $(( attempt * 15 ))
done

echo "all $attempts attempts failed" >&2
exit 1
