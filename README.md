# supabase-keep-alive

Keeps a free-tier Supabase project from being paused for inactivity by sending
one authenticated `GET` to its REST API every day, at a different time each day.

The project URL and the table path are kept in repository secrets rather than
committed here, so this public repo names neither.

## How the random timing works

The workflow wakes up hourly at `:07`. On each wake-up it hashes the current UTC
date (plus `PING_SEED`, if set) and derives:

- an **hour** — uniform over `0`–`23`
- a **jitter** — `0`–`JITTER_MINUTES` seconds past the cron tick

If the current hour is not the chosen hour, the run exits immediately having done
nothing. So exactly one ping lands per day, at an hour that moves around the
clock, and no state has to be stored anywhere.

Set a `PING_SEED` secret to make the schedule unguessable from the outside —
without it the slot is derivable from the date alone. Nothing breaks if you skip
it; it only matters if you care that the timing not be reproducible by someone
reading this repo.

Check the schedule yourself:

```sh
./scripts/slot.sh              # today
./scripts/slot.sh 2026-12-25   # any date
```

## Setup

1. Push this repo to GitHub.
2. Add these repository secrets (Settings → Secrets and variables → Actions):

   | Secret | Value |
   | --- | --- |
   | `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
   | `PING_PATH` | `/rest/v1/<table>` |
   | `SUPABASE_ANON_KEY` | the project's **anon / public** key, from Project Settings → API Keys — *not* `service_role` |
   | `PING_SEED` | any random string (optional) |

3. Nothing else needs editing; the workflow reads all of it from secrets.
4. Run it once by hand: Actions → *Supabase keep-alive* → **Run workflow**.
   The `force` input pings immediately regardless of today's slot.

## Running it locally

```sh
export SUPABASE_URL=https://<project-ref>.supabase.co
export PING_PATH=/rest/v1/<table>
export SUPABASE_ANON_KEY=...
./scripts/ping.sh
```

## Things worth knowing

**Actions minutes.** Public repos get unlimited minutes, so this is free. On a
private repo, the hourly wake-ups cost ~720 billed minutes/month and the jitter
sleep adds ~5 more, against a 2000-minute free allowance.

**The 60-day trap.** GitHub disables scheduled workflows in repositories with no
activity for 60 days — which would silently stop the pinger. Each successful
ping therefore commits a line to `log/pings.log`, which keeps the repo active and
gives you a visible record of what fired and when.

**Missed days are fine.** GitHub drops scheduled runs under load, and a dropped
run means no ping that day. Supabase pauses after ~7 consecutive inactive days,
so a single miss is harmless.

**Logs stay clean.** This repo is public, so its Actions logs are public too.
The ping prints a status code and a byte count, never the response body.

**Failures are loud.** A non-2xx response fails the job, so GitHub emails you.
A `4xx` (expired or wrong key, renamed table) fails fast without retrying; `5xx`
and network errors retry five times with backoff.

**This cannot un-pause a project.** It only prevents the pause. If the project is
already paused, resume it from the dashboard first.
