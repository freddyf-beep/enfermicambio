# Health Permissions and Visual System Design

**Status:** Accepted
**Date:** 2026-08-11
**Scope:** Flutter mobile app, iOS HealthKit, Android Health Connect

## Context

The app has a health domain and a `HealthSetupScreen`, but the permission flow
is not discoverable during first use and is only reachable from an icon in
`NOSOTROS`. The Android integration is incomplete for `health 13.3.1`: the
manifest declares only step access, `MainActivity` extends `FlutterActivity`,
and the runtime Activity Recognition permission is not requested. On iOS,
HealthKit usage strings and the entitlement are already present, but the UI
currently treats an indeterminate read-permission result as simply not granted.

The current UI changes also use a blue theme while the approved product
direction is the dark charcoal, lime, and orange sports-club scoreboard shown
in the supplied references.

## Goals

- Make health connection visible from `HOY` and during first authenticated use.
- Make read permissions work on both iOS and Android within the current
  platform-agnostic health boundary.
- Represent platform-specific permission knowledge honestly, especially iOS's
  privacy-preserving indeterminate read status.
- Apply one shared visual language to the five product tabs without rewriting
  feature data flows.
- Provide recoverable states for unavailable services, denied permissions,
  partial grants, no data, and retryable failures.
- Add deterministic unit and widget coverage before physical device validation.

## Non-goals

- No new Supabase tables or changes to ranking/points calculations.
- No manual step-entry path.
- No background location permission as part of health setup.
- No native rewrite of HealthKit or Health Connect.
- No push notification implementation in this slice.
- No claim that simulator tests prove HealthKit or Health Connect behavior.

## Design

### Visual system

The visual north star is **The Club Scoreboard**. The app is dark-first, uses a
near-black canvas and layered charcoal surfaces, and reserves electric lime for
primary actions, selected navigation, progress, and live competition. Orange is
limited to calories, duels, workouts, and warnings. Primary values use strong
type with tabular figures; supporting copy remains quiet and readable.

The five tabs share an app header with avatar, wordmark, and notification
action. The bottom navigation uses a lime pill for the active destination and
quiet gray inactive destinations. Cards use 12-16px corners, a one-pixel
graphite border, and no permanent shadow. A small lime glow is allowed only on
active or live states. The full token contract is in `DESIGN.md`.

Shared presentation primitives are introduced only where they remove visible
inconsistency: app header, bottom navigation, section heading, score card,
status pill, and health connection card. Existing feature-specific cards keep
their data and callbacks.

### Health entry points

`HOY` renders a `HealthConnectionCard` when the current user's daily aggregate
is absent or the last health read is unavailable. The card includes the detected
platform, a short explanation of automatic data, and one primary `Conectar
salud` action. It does not open a system prompt without an explicit tap.

`NOSOTROS` keeps a health settings action for later review. Both entry points
navigate to the same `HealthSetupScreen`, so the permission logic has one
presentation surface and one recovery vocabulary.

### Permission state contract

The current boolean `healthAvailable` and `grantedTypes` fields are extended so
the UI can distinguish the following states without guessing:

| State | Meaning | Recovery |
| --- | --- | --- |
| `available` | Platform health service can be queried | Request the selected read permissions |
| `unavailable` | Health Connect is missing/unsupported or HealthKit is unavailable | Install/open the platform service or use a supported device |
| `notGranted` | Android reports one or more requested read permissions missing | Request permissions again or open settings |
| `partial` | Android reports some requested types granted | Request the remaining types |
| `requested` | iOS authorization request completed, but Apple does not disclose read status | Run a real read and explain the privacy limitation |
| `connected` | A permitted read completed and data state is known | Show last sync and allow refresh |
| `noData` | Permission path is usable but no accepted records exist | Explain that activity will appear after the source records it |
| `retryable` | A transient plugin or platform failure occurred | Retry and preserve the previous visible state |

On iOS, `Health.hasPermissions` may return `null` for read access by design.
The app must not render that as a denial. A successful authorization call moves
the screen to `requested`; a successful subsequent read moves it to `connected`
or `noData`. On Android, `hasPermissions` is used per metric with explicit
read access and can render `notGranted` or `partial`.

### Android flow

The Android manifest declares the platform permissions required by the current
read set:

- `android.permission.ACTIVITY_RECOGNITION`
- `android.permission.health.READ_STEPS`
- `android.permission.health.READ_ACTIVE_CALORIES_BURNED`
- `android.permission.health.READ_DISTANCE`
- `android.permission.health.READ_EXERCISE`

The manifest also declares Health Connect package visibility and the rationale
intent required by the plugin integration. The main activity changes to
`FlutterFragmentActivity` so `health 13.3.1` can register its activity-result
permission launcher on Android 14.

The request sequence is:

1. Check whether Health Connect is available.
2. Request `ACTIVITY_RECOGNITION` if the OS reports it as not granted.
3. Request the four Health Connect read permissions through the `health`
   plugin.
4. Refresh status and run one foreground sync.

If Health Connect is unavailable, the screen offers installation/opening of the
service. Location is intentionally not part of this flow; route permissions
remain tied to explicit workout-route behavior.

### iOS flow

The existing HealthKit entitlement and `NSHealthShareUsageDescription` are kept.
The app requests only read access for the current metric set. Availability is
checked before request/read operations. The UI uses the privacy-aware state
contract above and never claims that Apple has denied a read permission merely
because the API returned `null`.

After returning from the system sheet, the app refreshes the setup snapshot and
performs one read. An unlocked physical device is required because protected
HealthKit data can be inaccessible while the device is locked.

### Data flow and boundaries

`HealthSetupScreen` depends only on `HealthRepository`. The repository owns
platform checks, permission calls, timeouts, and plugin errors. The health sync
service remains responsible for filtering manual records, segmenting accepted
records by `competition_timezone`, and upserting the daily aggregate. No UI
component writes health data or talks directly to HealthKit/Health Connect.

The connection card receives a callback or repository-backed coordinator from
the feature container. It does not duplicate sync logic or infer permission
state from whether a number happens to be zero.

### Error and recovery behavior

Every async path maps to a visible status and an action:

- Missing service: explain the platform dependency and provide install/open.
- Permission denied: explain that rankings need automatic read access and offer
  retry/settings.
- Partial access: list the missing metric groups and request only what remains.
- No data: explain that no accepted automatic records were found; never offer
  manual steps.
- Timeout/backend failure: preserve the last known state, show retry, and avoid
  blanking the screen.
- iOS indeterminate read status: say that Apple protects read-permission details
  and verify via a real sync instead of showing a false denial.

Error text stays Spanish at the UI boundary. Domain statuses and diagnostic
event names remain English according to `CODESTYLE.md`.

### Testing and verification

Add repository tests with a fake `Health` adapter or repository boundary for:

- Android availability and missing Health Connect.
- Android all, partial, and denied read permissions.
- iOS indeterminate read permission after authorization.
- Successful read followed by `connected`/`noData` state.
- Timeout and retryable failure mapping.

Add widget tests for:

- `HOY` health card when no aggregate exists.
- Navigation to the setup screen from `HOY`.
- Permission state labels and recovery actions.
- The `NOSOTROS` settings entry remaining available.

Before implementation commits, run `flutter analyze` and `flutter test` serially
using the SDK at `C:\src\flutter\bin\flutter.bat`. Existing compile errors in
`test/mocks/user_mocks.dart` must be fixed as a separate small increment. Device
acceptance requires one physical iPhone and one physical Android phone with
Health Connect, plus the four-user test matrix later in the roadmap.

## Alternatives Considered

### Keep the existing settings-only button

Rejected because the permission flow is undiscoverable during onboarding and
the `HOY` empty state cannot recover itself. It also leaves platform setup
failures hidden behind a generic snackbar.

### Replace `health` with separate native implementations

Rejected for this slice. The current package already provides the required
metric types, recording metadata, and permission APIs. A native rewrite would
increase platform-specific code before physical evidence proves a package gap.

### Request all permissions automatically on app launch

Rejected for privacy and user control. The system sheet should follow an
explicit, contextual action explaining what the group will see and why the
permission is needed.

## Consequences

The app gains a discoverable first-run path and honest cross-platform status
language. Android receives the native setup required for its permission launcher;
iOS avoids false permission-denied messaging. The visual system becomes more
consistent, but the five existing tabs need a focused component/token pass.

Physical device validation remains a release dependency and cannot be replaced
by Flutter widget tests or Windows builds.

## References

- `DESIGN.md`
- `PRODUCT.md`
- `CODESTYLE.md`
- `ROADMAP.md`, Phases 0, 1, 2, and 7
- `https://pub.dev/packages/health/versions/13.3.1`
- `https://developer.apple.com/tutorials/data/documentation/healthkit/setting-up-healthkit.md`
- `https://developer.android.com/health-and-fitness/guides/health-connect/plan/data-types#permissions`
