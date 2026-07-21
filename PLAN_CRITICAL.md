# Critical Product Fixes

## Goal

Protect user trust, remove broken product surfaces, and prevent ordinary user data from crashing the primary experience.

## User-Scoped Habit Access

Target files:

- `lib/mmentum/habits.ex`
- `lib/mmentum_web/live/habit_live/index.ex`
- `lib/mmentum_web/live/habit_live/show.ex`

- [ ] Replace global habit lookups with functions that require the current user.
- [ ] Scope habit show, edit, delete, add-completion, and remove-completion operations to the current user.
- [ ] Ensure a user cannot access or mutate another user's habit by changing a URL or event ID.
- [ ] Return a deliberate not-found response when a habit is unavailable to the current user.
- [ ] Add tests covering cross-user show, edit, delete, and completion attempts.

Acceptance criteria:

- Every habit lookup used by a user-facing route includes the current user's ID.
- Cross-user access never reveals whether the target habit exists.

## User-Scoped Log Access

Target files:

- `lib/mmentum/logs.ex`
- `lib/mmentum_web/live/log_live/index.ex`
- `lib/mmentum_web/live/log_live/show.ex`
- Habit completion handlers that create or delete logs.

- [ ] Require the current user for every user-facing log lookup and mutation.
- [ ] Verify that a log belongs to one of the current user's habits.
- [ ] Scope deletion of the most recent completion to both user and habit.
- [ ] Add tests covering cross-user log access and deletion attempts.

Acceptance criteria:

- A user cannot inspect, edit, or delete another user's activity record.

## Remove Broken Log Administration

Target files:

- `lib/mmentum_web/router.ex`
- `lib/mmentum_web/live/log_live/*`
- Navigation or links that expose log administration.

- [ ] Remove `/logs/new` and log edit routes.
- [ ] Remove the empty log form component.
- [ ] Decide whether `/logs` and `/logs/:id` should also be removed in favor of habit activity.
- [ ] Remove generated copy such as "Listing Logs" and "record from your database" from all remaining user-facing surfaces.

Acceptance criteria:

- No reachable user flow presents an empty or nonfunctional form.
- No user-facing screen exposes raw database administration concepts.

## Correct Authentication Redirects

Target files:

- `lib/mmentum_web/user_auth.ex`
- `lib/mmentum_web/live/user_forgot_password_live.ex`
- `lib/mmentum_web/live/user_confirmation_instructions_live.ex`
- `lib/mmentum_web/live/user_confirmation_live.ex`

- [ ] Redirect logout directly to `/users/log_in`.
- [ ] Redirect unauthenticated confirmation and password-reset completion flows directly to `/users/log_in`.
- [ ] Preserve the intentional success message without adding "You must log in."
- [ ] Update redirect tests.

Acceptance criteria:

- Successful unauthenticated flows never produce an immediate access-denied flash.

## Make Names Safe

Target files:

- `lib/mmentum/accounts/user.ex`
- `lib/mmentum_web/live/habit_live/index.ex`
- Registration tests.

- [ ] Require `full_name` during registration.
- [ ] Trim surrounding whitespace.
- [ ] Derive the greeting name from the first non-empty segment rather than matching exactly two segments.
- [ ] Cover blank, one-word, multi-part, and whitespace-heavy names in tests.

Acceptance criteria:

- Any accepted registration name renders safely on the dashboard.
