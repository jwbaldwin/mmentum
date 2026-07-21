# Critical Product Fixes

## Goal

Protect user trust, remove broken product surfaces, and prevent ordinary user data from crashing the primary experience.

## User-Scoped Habit Access

Target files:

- `lib/mmentum/habits.ex`
- `lib/mmentum_web/live/habit_live/index.ex`
- `lib/mmentum_web/live/habit_live/show.ex`

- [x] Replace global habit lookups with functions that require the current user.
- [x] Scope habit show, edit, delete, add-completion, and remove-completion operations to the current user.
- [x] Ensure a user cannot access or mutate another user's habit by changing a URL or event ID.
- [x] Return a deliberate not-found response when a habit is unavailable to the current user.
- [x] Add tests covering cross-user show, edit, delete, and completion attempts.

Acceptance criteria:

- Every habit lookup used by a user-facing route includes the current user's ID.
- Cross-user access never reveals whether the target habit exists.

## User-Scoped Log Access

Target files:

- `lib/mmentum/logs.ex`
- `lib/mmentum_web/live/log_live/index.ex`
- `lib/mmentum_web/live/log_live/show.ex`
- Habit completion handlers that create or delete logs.

- [x] Require the current user for every user-facing log lookup and mutation.
- [x] Verify that a log belongs to one of the current user's habits.
- [x] Scope deletion of the most recent completion to both user and habit.
- [x] Add tests covering cross-user log access and deletion attempts.

Acceptance criteria:

- A user cannot inspect, edit, or delete another user's activity record.

## Remove Broken Log Administration

Target files:

- `lib/mmentum_web/router.ex`
- `lib/mmentum_web/live/log_live/*`
- Navigation or links that expose log administration.

- [x] Remove `/logs/new` and log edit routes.
- [x] Remove the empty log form component.
- [x] Remove `/logs` and `/logs/:id` in favor of habit activity.
- [x] Remove generated copy such as "Listing Logs" and "record from your database" from all remaining user-facing surfaces.

Acceptance criteria:

- No reachable user flow presents an empty or nonfunctional form.
- No user-facing screen exposes raw database administration concepts.

## Correct Authentication Redirects

Target files:

- `lib/mmentum_web/user_auth.ex`
- `lib/mmentum_web/live/user_forgot_password_live.ex`
- `lib/mmentum_web/live/user_confirmation_instructions_live.ex`
- `lib/mmentum_web/live/user_confirmation_live.ex`

- [x] Redirect logout directly to `/users/log_in`.
- [x] Redirect unauthenticated confirmation and password-reset completion flows directly to `/users/log_in`.
- [x] Preserve the intentional success message without adding "You must log in."
- [x] Update redirect tests.

Acceptance criteria:

- Successful unauthenticated flows never produce an immediate access-denied flash.

## Make Names Safe

Target files:

- `lib/mmentum/accounts/user.ex`
- `lib/mmentum_web/live/habit_live/index.ex`
- Registration tests.

- [x] Require `full_name` during registration.
- [x] Trim surrounding whitespace.
- [x] Derive the greeting name from the first non-empty segment rather than matching exactly two segments.
- [x] Cover blank, one-word, multi-part, and whitespace-heavy names in tests.

Acceptance criteria:

- Any accepted registration name renders safely on the dashboard.
