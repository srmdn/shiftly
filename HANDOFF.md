# CURRENT STATE

- Checkpoint: 2026-08-24T08:01:00+07:00
- Project root: `/Users/said/Developer/projects/github/shiftly`
- Repository: `srmdn/shiftly`; branch: `main`; hosted foundation committed
- Goal: Build the hosted Shiftly foundation while preserving the working
  local-first application and its browser-data import path.
- Status: Ready for next step. The hosted model is accepted, its initial SQLite
  migration is tested, and the Go API foundation runs locally.

## Verified project state

- The hosted foundation and this checkpoint are tracked on `main`.
- The browser application remains local-first and continues to store version 2
  schedules in `shiftly_schedule_v2`.
- The hosted backend is a separate Go module under `backend/` using Go 1.25 or
  newer and `modernc.org/sqlite` `v1.57.0`.
- Migration `0001_hosted_schema.sql` creates users, teams, members, schedules,
  manual assignments, effective rotation rules, ordered rule members,
  replacements, and local import records.
- SQLite initialization enables foreign keys, WAL mode, and a five-second busy
  timeout on every connection.
- `GET /api/health` checks database connectivity. The server handles SIGINT and
  SIGTERM with a bounded graceful shutdown.
- `.local/` remains ignored and contains accepted private product and
  architecture decisions.

## Task context and assumptions

- Production VPS OS and architecture are not documented in this repository.
  The pure-Go SQLite driver avoids making a CGO or cross-toolchain assumption.
- Prayer handovers must remain disabled until calculated results pass fixtures
  from published Kemenag schedules within a documented rounding tolerance.
- The browser UI is not connected to the hosted API yet.

## Completed work

- Verified the prior handoff against the repository, branch, tests, README,
  private decisions, hosted model, roadmap, backlog, and development log.
- Accepted the hosted data model and recorded driver, prayer-library,
  invitation-scope, and account-deletion decisions.
- Added a checksum-protected, forward-only migration runner and the initial
  hosted schema with tenant, membership, interval, and overlap constraints.
- Added migration tests for idempotence, SQLite pragmas, cross-team rejection,
  half-open adjacency, and overlap rejection.
- Added environment configuration, SQLite opening and migration, a health
  endpoint, HTTP timeouts, signal handling, and graceful shutdown.
- Updated public run and test instructions and private project records.

## Important decisions

- Keep the current browser application usable until one-time import is ready.
- Keep the frontend static; use one Go API and SQLite in WAL mode.
- Use `modernc.org/sqlite` `v1.57.0` through `database/sql`.
- Use `github.com/hablullah/go-prayer` `v1.1.1` behind a Shiftly-owned
  interface; don't expose library constants in stored data.
- Defer invitations from the first authenticated release.
- Account deletion deactivates and unlinks member rows, redacts the login
  identity, and retains team-owned scheduling history.
- Derive baseline rotations from effective rules. Replacements never rewrite or
  restart the baseline.

## Files changed

- `.gitignore` — ignores local backend runtime databases under `backend/var/`.
- `README.md` — documents backend tests, local startup, configuration, and the
  current frontend/backend boundary.
- `backend/go.mod`, `backend/go.sum` — add the hosted Go module and pinned
  SQLite dependency.
- `backend/cmd/server/main.go` — adds server startup and graceful shutdown.
- `backend/internal/config/` — adds environment configuration and tests.
- `backend/internal/httpapi/` — adds the health endpoint and tests.
- `backend/internal/storage/` — adds SQLite setup, the migration runner, the
  initial hosted schema, and tests.
- `.local/DECISIONS.md`, `.local/DATA-MODEL.md`, `.local/ROADMAP.md`,
  `.local/BACKLOG.md`, `.local/DEVLOG.md` — ignored private records updated
  for the accepted choices and completed foundation work.
- `HANDOFF.md` — tracked portable checkpoint refreshed after implementation.

## Unresolved problems

- Implement team-scoped repositories and APIs for users, teams, members, and
  schedules before rotation and replacement endpoints.
- Validate the prayer calculator against published Kemenag fixtures.
- Add Google OAuth, server-side sessions, CSRF protection, and account recovery
  after repository and authorization boundaries have tests.
- Design and test one-time `shiftly_schedule_v2` import.
- Enforce service-level invariants that SQLite can't express cleanly, including
  at least one active team owner and at least two members per active rotation
  rule.

## Failed approaches

- The first sandboxed live-server smoke test couldn't bind a localhost port.
  Running the test with explicit local-process permission succeeded.
- `go test ./...` initially used the sandboxed default Go build cache. Setting
  `GOCACHE=/tmp/shiftly-gocache` resolved the environment-only failure.

## Checks

- `node --test` — PASS — 7 tests passed and 0 failed.
- `go test ./...` in `backend/` — PASS — config, HTTP, storage, and
  migration packages passed.
- `go vet ./...` in `backend/` — PASS — no findings.
- `git diff --check` — PASS — no whitespace errors in tracked changes.
- Direct compiled-server smoke test — PASS — `GET /api/health` returned HTTP
  200 with `{"status":"ok"}`, and SIGINT exited with status 0.

## Blockers

- None recorded.

## Next steps

1. Define repository interfaces and authorization inputs for team-scoped users,
   teams, members, and schedules.
2. Implement those repositories with transaction and cross-team isolation tests.
3. Expose the first authenticated-resource API shapes only after repository
   authorization boundaries pass.
4. Add the prayer calculator adapter and Kemenag reference fixtures separately;
   don't enable prayer handovers until validation passes.

## Resume

Read HANDOFF.md, verify its current-state claims against the repository, and
continue from the next unfinished step.
