# Code Style

Rules for every artifact in this repository: Dart code, SQL migrations, Edge Functions (Deno/TypeScript), tests, scripts, documentation, logs, and configuration examples.

## Language

- Code, comments, docs, test names, logs, commit messages, and error identifiers are written in English.
- Product-facing Spanish identifiers (`HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, `NOSOTROS`) and feed copy live only in a localization layer at the UI boundary. They never appear in domain logic, column names, function names, or test descriptions.
- ASCII by default in source. Non-ASCII appears only in localized string resources, emoji sets defined by the spec, and test fixtures that need them.

## Debuggability

- Structured logs with stable event names, never ad hoc string concatenation: `health.sync.completed`, `points.round.awarded`, `media.upload.failed`.
- Every async boundary logs enough context to diagnose: feature, operation, correlation ID, date/window, source, failure category.
- Never log passwords, tokens, signed URLs, raw health samples, full API payloads, captions, or precise location.
- Syncs, uploads, scheduled jobs, and point awards carry a correlation ID from start to finish.
- Expected states are distinguished from failures: `permission_denied`, `source_unavailable`, `no_data`, `stale_data`, `backend_unavailable`, `validation_failed`, `retryable_failure`.
- Every retryable failure has a user-visible recovery action.
- Idempotency is a debugging feature: retrying any operation must be safe and produce the same end state.

## Comments

- Comments exist only for non-obvious technical constraints, invariants, platform workarounds, and security decisions. They explain why, never what.
- No narration comments. If a name or structure can carry the meaning, it does.
- Stale comments are deleted in the same commit that changes the behavior.
- The following invariants get a short comment where they are enforced:
  - no manual step entry;
  - manual-entry filtering of health records;
  - `(user_id, date)` aggregate idempotency;
  - shared `competition_timezone`;
  - append-only season point ledger;
  - service-role-only writes for points and system posts.

## Formatting

- Dart: `dart format` with default line length; `flutter analyze` with zero warnings before commit.
- SQL: lowercase keywords, one clause per line, explicit column lists.
- TypeScript (Edge Functions): `deno fmt` and `deno lint`.
- Markdown: fenced code blocks carry a language tag; tables are aligned.
- Formatting runs before every commit. No hand-formatting around the formatter, no lint disables without an inline documented reason.
- Formatting-only changes never share a commit with behavior changes.

## Structure and Naming

- Feature-oriented modules: `auth`, `profiles`, `health`, `activity`, `ranking`, `nutrition`, `workouts`, `feed`, `game`, `notifications`, `shared`. Inside each feature: presentation, domain, data.
- Domain concepts use spec vocabulary: `daily_activity`, `morning_steps`, `competition_timezone`, `season_points`, `within_calorie_target`.
- Nouns for types and services, verbs for commands, `is`/`has`/`can` predicates for booleans.
- No `manager`, `helper`, `utils`, `misc`, `data`, or `temp` names when a domain name exists.
- Platform-specific health code lives behind one repository interface; UI and domain code never import HealthKit/Health Connect types directly.
- Value objects crossing feature or platform boundaries are immutable with explicit result/error types, not exceptions for expected failures.
- Configuration that tuning may change (windows, points, goals, cooldowns, season type) lives in `app_config`, never as literals in code.
- Migrations are forward-only. An applied migration is never edited; corrections are new migrations.

## Health and Data Integrity

- Health platforms are authoritative for automatic activity, subject to filtering and de-duplication rules.
- No manual step entry UI exists. Shared numeric input components must be designed so they cannot accidentally become one.
- Platform aggregation APIs are used before any raw-record summation. Phone + wearable overlap is never naively summed.
- Records flagged as manual are excluded; the filter decision is recorded with source metadata for diagnostics.
- Re-syncing a day recalculates the same `(user_id, date)` row.
- Workouts de-duplicate on `(source, external_id)`.
- Food entries store nutrition snapshots.
- Points are awarded only by backend code through the ledger function, with reason and reference.
- Achievements and missions evaluate idempotently; non-repeatable achievements have uniqueness enforcement.
- All round, daily, and season math uses `competition_timezone`.

## Tests

- Pure domain logic is tested without widgets: window segmentation, timezone boundaries, manual-record filtering, de-duplication, ranking ties, point rules, streak transitions, achievement operators, mission progress, season close, nutrition totals.
- Integration tests cover: idempotent upserts, RLS policies per table, storage access rules, ledger uniqueness, scheduled-job retries.
- Device tests cover HealthKit and Health Connect on physical hardware. Simulators and mocks do not prove permission, source, or aggregation behavior.
- Offline tests cover cached reads, queued writes, media retry, and Realtime reconnect.
- Negative tests cover: unknown user access, peer writes, public media fetch, manual step records, duplicate point awards, malformed external API responses, denied permissions.
- Tests are deterministic: fixed timestamps, explicit `competition_timezone`, no wall-clock or local-timezone dependence.
- Test names describe behavior and expectation: `rejects_manual_step_records_when_metadata_marks_manual`.
- Tests are never weakened to make code pass. Either the code is fixed or the platform limitation is documented and accepted by the product owner.

## Security and Privacy

- RLS on every table, tested with all four users plus an unknown authenticated identity plus anonymous.
- Shared read access never implies shared write access.
- Storage buckets are private; access via signed URLs or storage RLS.
- Points, standings, achievements, missions, season closure, and system posts are validated and written server-side only.
- User text, filenames, barcodes, and external API payloads are validated and constrained before persistence or rendering.
- Permissions are requested in context and only when the feature is used. Location only for explicit route/post actions.
- No live location tracking, public discovery, public profiles, or hidden registration paths.
- Third-party packages are reviewed for permissions, licensing, retention, and network behavior before adoption.

## Dependencies

- Maintained packages with iOS/Android parity and clear licenses. Evaluation criteria per area are in `ROADMAP.md` Phase 0.
- One Flutter health abstraction is preferred over native channels; native code only for a documented gap.
- Open Food Facts first, USDA fallback, no paid nutrition API without a proven coverage gap.
- No dependency for what the standard library does clearly.
- Versions are constrained; upgrades review changelogs, especially for health, camera, maps, auth, and storage.
- Unused dependencies are removed.
- No credentials, SDK paths, or keys are ever committed.

## Commits

- Conventional Commits, exactly:

```text
prefix: description
```

- Prefixes: `feat`, `fix`, `test`, `docs`, `refactor`, `chore`, `build`, `ci`.
- Imperative, lowercase, specific descriptions: `feat: sync daily HealthKit steps`, `fix: prevent duplicate season point awards`.
- One coherent change per commit.
- Before every commit: format, analyze, run focused tests, inspect the diff, confirm no secrets or unrelated files.
- Significant roadmap checkpoints are committed immediately after their evidence is recorded in `ROADMAP.md`.

## Review Checklist

- Stays within `SPECS.md` scope and the current roadmap phase?
- Domain names clear; no vague abstractions?
- Comments only where technically necessary?
- Formatter and analyzer clean?
- Focused tests added and passing; device/RLS/offline/retry tests where relevant?
- Can any retry duplicate activity, points, achievements, posts, or uploads?
- Can an unknown user, peer, public URL, log line, or error message expose sensitive data?
- Permissions and dependencies minimal?
- Checkpoint evidence recorded and reproducible?
