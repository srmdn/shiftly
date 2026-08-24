# Shiftly

Local-first shift scheduler for small teams. Use manual assignments or generate
a fixed round-robin rotation with temporary coverage exceptions.

## Features

- Manual schedules with single-click and bulk assignment
- Rotation schedules with a fixed anchor, starting person, handover time, and
  equal shift duration
- Dynamic people list with configurable round-robin order and color labels
- Current-duty status with the next handover time and rotation rule
- Temporary exceptions that keep the baseline rotation unchanged
- Scheduled and actual assignment details for covered shifts
- Coverage totals based on baseline overlap instead of leave duration
- Configurable person names and dark/light theme
- Notes per date, visible in a list below the calendar
- Month navigation with arrows, keyboard shortcuts, and swipe
- Month summary with clear day units for every person
- Export month as plain text for sharing
- All data stored in your browser (`localStorage`). Nothing leaves your device.

## Usage

Open [Shiftly](https://srmdn.github.io/shiftly/) and choose a schedule mode.

### Manual schedules

- Click a date to assign it. Add a note if needed.
- Shift+click to select multiple dates for bulk assignment.
- Use arrow keys or swipe the calendar to change months.
- Open **Schedule settings** to add, rename, remove, or reorder people.

### Rotation schedules

1. Open **Schedule settings** from the mode label or gear icon.
2. Select **Rotation**.
3. Add at least two people and arrange them in round-robin order.
4. Enter the starting date and time, starting person, equal shift duration, and
   handover label.
5. Select a calendar date to inspect its complete shift interval.
6. Select **Add leave / replacement** when another person covers the scheduled
   person.

Shiftly derives rotation dates from the saved rule. An exception changes the
actual assignment only while the unavailable person owns the baseline shift. It
doesn't restart or move future rotation dates.

## Data migration

Shiftly migrates the legacy `shiftly_data` and `shiftly_config` keys to a
version 2 schedule document in `shiftly_schedule_v2`. The migration creates a
Manual schedule and leaves both legacy keys untouched as recovery data.

## Tests

Run the browser-independent scheduling tests with:

```sh
node --test
```

The hosted backend foundation lives in `backend/`. Run its tests with:

```sh
cd backend
go test ./...
```

Start the local API with:

```sh
cd backend
go run ./cmd/server
```

The default API listens on `127.0.0.1:8080`, stores its development database at
`backend/var/shiftly.db`, and exposes `GET /api/health`. Override the defaults
with `SHIFTLY_LISTEN_ADDRESS`, `SHIFTLY_DATABASE_PATH`, and
`SHIFTLY_SHUTDOWN_TIMEOUT_SECONDS`.

## Stack

The working application remains static HTML and JavaScript. Tailwind CSS and
htmx load from CDNs, and the browser continues to use `localStorage`. The hosted
foundation adds a small Go API and SQLite migrations under `backend/`;
the browser UI isn't connected to that API yet.

## License

Copyright (C) 2026 srmdn.

Shiftly is licensed under the
[GNU Affero General Public License v3.0 only](LICENSE) (`AGPL-3.0-only`).
