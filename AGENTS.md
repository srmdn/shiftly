# Shiftly agent guide

## Project overview

Shiftly is a local-first shift scheduler for small teams. The current application
is a static site built with HTML and JavaScript. Tailwind CSS and htmx load from
CDNs, and schedule data stays in browser `localStorage`.

## Repository map

- `index.html`: Application markup, styles, browser state, and UI behavior.
- `shiftly-core.js`: Pure schedule, rotation, migration, and coverage logic.
- `tests/shiftly-core.test.js`: Node.js tests for the core scheduling engine.
- `README.md`: Public product and usage documentation.
- `.local/`: Private development notes. Git must never track this directory.

## Development workflow

1. Read `README.md` and the relevant files in `.local/` before making product or
   architecture changes.
2. Inspect the working tree and preserve unrelated user changes.
3. Keep scheduling calculations in `shiftly-core.js` when they don't require the
   DOM.
4. Keep browser-specific rendering and interaction code in `index.html`.
5. Run the test suite after changing scheduling, migration, or coverage logic.
6. Manually verify affected interactions in both light and dark themes when the
   change affects the UI.
7. Update `.local/DECISIONS.md`, `.local/ROADMAP.md`, or `.local/DEVLOG.md` when a
   change affects product direction or architecture.

## Commands

Run all automated tests:

```sh
node --test
```

Serve the site locally when browser testing needs an HTTP origin:

```sh
python3 -m http.server 8000
```

## Engineering rules

- Preserve support for schedules with two or more people.
- Treat rotation intervals as half-open ranges: the start is inclusive, and the
  end is exclusive.
- Keep the baseline rotation unchanged when applying leave or replacement
  exceptions.
- Preserve existing `localStorage` data and migration behavior unless a change
  includes an explicit migration path.
- Use local date and time semantics consistently. Don't introduce implicit UTC
  conversion into the scheduling engine.
- Prefer small, dependency-free changes while Shiftly remains a static app.
- Don't add a framework, build step, backend dependency, or external service
  without recording the decision in `.local/DECISIONS.md`.
- Keep secrets out of the repository and out of `.local/`, even though `.local/`
  is ignored by Git.

## Documentation rules

- Keep public documentation in `README.md` accurate for released behavior.
- Keep private plans, rough notes, and commercial ideas in `.local/`.
- Write documentation in clear English and wrap prose near 80 characters.
- Don't publish details from `.local/` unless the user explicitly requests it.
