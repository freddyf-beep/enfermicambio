# Engineering and Documentation Style

These rules apply to production code, database migrations, tests, scripts, documentation, logs, configuration examples, and user-facing copy for Enfermicambio.

## Language and Product Copy

- Write code, comments, documentation, test names, logs, error messages, and developer-facing copy in English.
- Isolate intentional localized product strings in a dedicated localization layer or resource file. Do not mix localized strings into domain logic, database column names, test descriptions, or operational logs.
- Keep product identifiers such as `HOY`, `RANKING`, `REGISTRAR`, `JUEGO`, and `NOSOTROS` isolated at the UI boundary when they are required by the product language.
- Avoid medical claims. Use movement, activity, nutrition, goals, competition, and social language.
- Do not describe a configured calorie target as a measured metabolic deficit.
- Keep the tone playful and friend-oriented without shame, clinical advice, or corporate motivational language.
- Use ASCII by default in source and documentation. Add non-ASCII characters only when required by an intentional localized string, data fixture, or user-facing emoji set.

## Debuggability

- Every asynchronous boundary must expose enough context to diagnose failure: feature, operation, user-safe identifier, relevant date/window, source, and failure category.
- Never log passwords, access tokens, signed URLs, raw health samples, full food payloads, private captions, or unnecessary precise location.
- Use structured logs with stable event names rather than ad hoc concatenated messages.
- Include correlation or operation identifiers for syncs, uploads, scheduled jobs, point awards, and external API calls where the platform supports them.
- Distinguish expected states from failures:
  - permission denied;
  - source unavailable;
  - no data;
  - stale data;
  - backend unavailable;
  - validation failure;
  - retryable upload/API failure.
- Preserve source metadata needed to troubleshoot health discrepancies, but keep low-level metadata out of normal UI.
- Make synchronization and background-job operations idempotent so a retry is safe and diagnosable.
- Add user-visible recovery actions for retryable failures, especially media upload, barcode lookup, health permission, and backend-offline failures.
- Prefer errors that identify the next action without exposing implementation details or sensitive data.

## Comments

- Add comments only when they explain a non-obvious technical constraint, invariant, platform workaround, security decision, or intentionally unusual algorithm.
- Comments must be specific and current. Explain why the code is shaped this way, not what the next line does.
- Do not use comments to compensate for unclear names, oversized functions, or missing tests.
- Update or remove comments when behavior changes.
- Document important invariants near the code that enforces them:
  - no manual step entry;
  - `(user_id, date)` daily aggregate idempotency;
  - one shared `competition_timezone`;
  - immutable season point ledger;
  - protected system-generated posts;
  - owner-scoped writes under RLS.

## Formatting

- Use the formatter and linter selected by the repository. For Flutter/Dart, run `dart format` and `flutter analyze`.
- Keep formatting deterministic and run it before every commit.
- Do not hand-format around the formatter or disable a lint without a documented, local reason.
- Use one clear statement per line where the language and formatter support it.
- Keep Markdown headings, lists, code fences, and tables consistent. Use fenced code blocks with a language tag when the block contains code or commands.
- Prefer short paragraphs and focused sections over dense prose.
- Avoid unrelated whitespace, generated-file churn, or broad formatting changes in a feature commit.

## Structure and Naming

- Organize code by product capability and ownership boundary, not by arbitrary file type alone. Expected capabilities include auth/profiles, health, activity/rankings, nutrition, workouts/routes, feed, notifications, and game rules.
- Keep presentation, domain rules, data access, and platform integration separate enough to test independently.
- Name domain concepts after the specification: `daily_activity`, `competition_timezone`, `morning_steps`, `season_points`, `mission_progress`, and `within_calorie_target`.
- Use nouns for data types and services, verbs for commands, and predicates for booleans.
- Avoid vague names such as `data`, `manager`, `helper`, `misc`, or `temp` when a domain name is available.
- Keep public APIs small and explicit. Hide platform-specific implementation behind a health integration boundary.
- Prefer immutable value objects and explicit result/error types for data crossing feature or platform boundaries.
- Keep UI widgets/components focused. Split a component when it owns multiple independent states, workflows, or side effects.
- Keep database migrations forward-only and reviewable. Do not edit an applied migration to change production history.
- Keep configuration values that are expected to change, including round times and point values, in backend/app configuration rather than scattering literals through UI code.
- Never encode secrets, credentials, user passwords, or environment-specific tokens in code, fixtures, documentation, or test output.

## Health and Data Integrity

- Treat health-platform data as authoritative for automatic activity, subject to explicit filtering and de-duplication rules.
- Never add a manual step-entry form or reuse a generic numeric form in a way that creates one.
- Use platform aggregation semantics and source metadata before summing raw records.
- Reject detectable manual step records and record the filtering decision for diagnostics.
- Re-syncing the same day must replace or recalculate its aggregate, not append a duplicate.
- Use external source IDs to de-duplicate workouts when available.
- Store nutrition snapshots on entries so historical logs do not silently change when an external food record changes.
- Award points only through validated backend paths. Store point awards in the immutable season ledger with a reason and reference.
- Make achievements and mission completion idempotent. Non-repeatable achievements require uniqueness protection.
- Use the shared `competition_timezone` for all round, daily, and season calculations.

## Tests

- Every new rule or data transformation gets a focused automated test.
- Test pure domain logic without Flutter widgets where possible:
  - time-window segmentation;
  - timezone boundaries;
  - step filtering;
  - duplicate handling;
  - ranking ties and ordering;
  - point calculations;
  - streak transitions;
  - achievement operators;
  - mission progress;
  - season close behavior;
  - calorie and macro totals.
- Add integration tests for Supabase persistence, RLS, idempotent upserts, storage access, and scheduled-job retries.
- Add platform/device tests for HealthKit and Health Connect because simulators and mocks cannot prove permission, source, or aggregation behavior.
- Test offline and recovery paths for cached reads, pending food entries, pending posts, media uploads, health sync, and Realtime reconnect.
- Include negative tests for unknown users, peer writes to owner-scoped records, public media access, manual step records, duplicate awards, malformed external API responses, and denied permissions.
- Keep test data deterministic. Use fixed timestamps and an explicit `competition_timezone`; do not depend on the developer's local timezone or wall clock.
- Name tests after behavior and expected outcome, for example `rejects_manual_step_records_when_metadata_marks_manual`.
- Do not weaken tests to make an implementation pass. Fix the implementation or document an intentional platform limitation.

## Security and Privacy

- Apply row-level security to every table and test it with all four users plus an unknown authenticated identity.
- Shared readability does not imply unrestricted writes. Keep owner-scoped mutation rules explicit.
- Keep Supabase Storage buckets private. Use authenticated access or signed URLs with appropriate expiry.
- Request only permissions required by the current feature. Request location only after an explicit route or post-location action.
- Do not implement live location tracking, public discovery, public profiles, or a hidden registration path.
- Treat health, nutrition, route, photo, location, and authentication data as sensitive even though the four users intentionally share selected data.
- Validate server-side all values that affect points, rankings, achievements, mission completion, season closure, and system-generated events.
- Sanitize and constrain user text, filenames, barcode values, and external API data before persistence or rendering.
- Avoid leaking whether another user has data through unauthenticated error differences.
- Keep operational logs and analytics free of sensitive payloads and precise location unless specifically required for an approved diagnostic.
- Review third-party permissions, licensing, data retention, and network behavior before adoption.

## Dependency Discipline

- Prefer maintained, well-documented packages with iOS/Android parity and clear licensing.
- Evaluate dependencies against the actual requirement before adding them: HealthKit/Health Connect, interval queries, source metadata, manual filtering, workouts, nutrition, routes, background behavior, barcode scanning, maps, notifications, and Supabase compatibility.
- Prefer the existing Flutter health abstraction before writing native platform channels. Add native code only for a documented gap.
- Prefer Open Food Facts first and USDA FoodData Central as fallback. Avoid paid nutrition APIs unless coverage testing proves a real need.
- Do not add a dependency for a small utility that the standard library or existing code handles clearly.
- Pin or constrain versions according to the repository's package manager and update deliberately.
- Review changelogs and breaking changes before upgrades, especially for health, camera, map, authentication, and storage packages.
- Remove unused dependencies and transitive workarounds when the underlying issue is fixed.
- Record the reason for unusual or high-risk dependencies in the relevant technical documentation.
- Never commit generated credentials, local SDK paths, vendor secrets, or private API keys.

## Commits

- Use Conventional Commit style exactly:

```text
prefix: description
```

- Keep the `prefix` short and consistent with the repository convention. Typical prefixes are `feat`, `fix`, `test`, `docs`, `refactor`, `chore`, `build`, and `ci`.
- Use an imperative, specific description in lowercase unless a proper name requires otherwise.
- Examples:

```text
feat: sync daily HealthKit steps
fix: prevent duplicate season point awards
test: cover morning round boundary
docs: clarify private storage setup
```

- Keep one coherent change per commit. Do not mix unrelated formatting, generated files, or refactors with a feature.
- Run formatting, static analysis, focused tests, and relevant integration/device checks before committing.
- Inspect the final diff and confirm no secrets, unrelated files, debug bypasses, or accidental localized strings are included.

## Checkpoints

Every roadmap phase must end with an explicit checkpoint before the next phase starts.

- Record the acceptance criteria that passed, the commands and devices used, and any known limitations.
- Keep evidence for both iOS and Android whenever a platform integration is involved.
- For database changes, include migration status, RLS test results, idempotency tests, and rollback or recovery notes.
- For health changes, include sample source metadata, expected versus accepted totals, manual-entry behavior, and timezone/window results.
- For game changes, reconcile displayed standings with the immutable ledger and force retry/duplicate-event scenarios.
- For social and media changes, test privacy, upload retry, offline recovery, ordering, and event rate limits.
- For release readiness, verify backups/restores, configuration, permissions, logs, performance, and the complete core acceptance list in `SPECS.md`.
- Do not mark a phase complete because the UI exists. Mark it complete only when behavior, tests, security boundaries, and documented risks meet the phase acceptance criteria.

## Review Checklist

Before opening a review or merging:

- Does the change stay within `SPECS.md` and the current roadmap phase?
- Are names and domain boundaries clear?
- Are comments limited to technical necessity?
- Did formatting and static analysis run?
- Are focused tests present and passing?
- Were platform, RLS, storage, offline, or retry tests added when relevant?
- Could a retry duplicate activity, points, achievements, posts, or uploads?
- Could an unknown user, peer user, public URL, log, or error expose sensitive data?
- Were permissions and dependencies kept to the minimum required set?
- Is the checkpoint evidence complete and reproducible?
