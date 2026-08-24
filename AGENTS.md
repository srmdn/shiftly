# Shiftly agent guide

## Project overview

Shiftly is a local-first shift scheduler for small teams. The working browser
application is a static site built with HTML and JavaScript. Tailwind CSS and
htmx load from CDNs, and schedule data stays in browser `localStorage`.

The hosted foundation lives in `backend/`. It is a separate Go module with a
SQLite database and an HTTP API. The browser application isn't connected to the
hosted API yet.

## Repository map

- `index.html`: Application markup, styles, browser state, and UI behavior.
- `shiftly-core.js`: Pure schedule, rotation, migration, and coverage logic.
- `tests/shiftly-core.test.js`: Node.js tests for the core scheduling engine.
- `backend/cmd/server/`: Go API entry point and graceful shutdown.
- `backend/internal/config/`: Environment configuration.
- `backend/internal/httpapi/`: HTTP routes and handlers.
- `backend/internal/storage/`: SQLite setup, migrations, and persistence code.
- `README.md`: Public product and usage documentation.
- `HANDOFF.md`: Portable checkpoint for continuing work in a fresh session.
- `.local/`: Private development notes. Git must never track this directory.

## Development workflow

1. Read `README.md` and the relevant files in `.local/` before making product or
   architecture changes.
2. Inspect the working tree and preserve unrelated user changes.
3. Keep scheduling calculations in `shiftly-core.js` when they don't require the
   DOM.
4. Keep browser-specific rendering and interaction code in `index.html`.
5. Keep hosted configuration, HTTP, and storage code in their existing backend
   packages. Keep domain calculations independent from HTTP handlers.
6. Run the relevant JavaScript and Go tests after changing scheduling,
   migration, storage, authorization, or coverage logic.
7. Manually verify affected interactions in both light and dark themes when the
   change affects the UI.
8. Update `.local/DECISIONS.md`, `.local/ROADMAP.md`, or `.local/DEVLOG.md`
   when a change affects product direction or architecture.

## Commands

Run the browser-independent scheduling tests:

```sh
node --test
```

Run the backend tests:

```sh
cd backend
go test ./...
```

Run backend static analysis:

```sh
cd backend
go vet ./...
```

Serve the site locally when browser testing needs an HTTP origin:

```sh
python3 -m http.server 8000
```

Run the local API from a second terminal:

```sh
cd backend
go run ./cmd/server
```

## Engineering rules

- Preserve support for schedules with two or more people.
- Treat rotation intervals as half-open ranges: the start is inclusive, and the
  end is exclusive.
- Keep the baseline rotation unchanged when applying leave or replacement
  exceptions.
- Preserve existing `localStorage` data and migration behavior unless a change
  includes an explicit migration path.
- Preserve local date and time semantics in the browser scheduling engine. Don't
  introduce implicit UTC conversion into `shiftly-core.js`.
- Store concrete hosted instants in UTC. Interpret clock and prayer boundaries
  using each schedule's IANA timezone.
- Keep the frontend free of frameworks and build steps. Prefer small, focused
  backend dependencies with pinned versions.
- Don't add a framework, build step, backend dependency, or external service
  without recording the decision in `.local/DECISIONS.md`.
- Keep SQLite migrations forward-only. Never edit an applied migration; add a
  new version instead.
- Enable SQLite foreign keys and WAL mode on every database connection.
- Scope every hosted query and mutation through the team authorization boundary.
- Keep secrets out of the repository and out of `.local/`, even though `.local/`
  is ignored by Git.

## Documentation rules

- Keep public documentation in `README.md` accurate for released behavior.
- Keep private plans, rough notes, and commercial ideas in `.local/`.
- Write documentation in clear English and wrap prose near 80 characters.
- Don't publish details from `.local/` unless the user explicitly requests it.
