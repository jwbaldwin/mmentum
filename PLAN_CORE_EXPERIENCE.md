# Core Habit Experience

## Goal

Make the dashboard and habit activity clear, responsive, trustworthy, and satisfying without expanding product scope.


## Completion Controls

Target files:

- `lib/mmentum_web/live/habit_live/index.html.heex`
- `lib/mmentum_web/live/habit_live/index.ex`

- [ ] Prevent logging beyond the configured target.
- [ ] Prevent undo when no completion exists in the active period.
- [ ] Provide immediate pressed/loading feedback without optimistic data corruption.

## Habit Navigation And Editing

Target files:

- `lib/mmentum_web/live/habit_live/index.html.heex`
- `lib/mmentum_web/live/habit_live/show.html.heex`

- [ ] Make the habit title navigate to habit detail/activity.
- [ ] Expose edit as a separate secondary action.
- [ ] Keep the title stationary during hover and focus.
- [ ] Ensure edit remains discoverable on touch and keyboard, not only hover.

Acceptance criteria:

- Clicking a habit name opens the habit.
- Editing is available without causing text movement or requiring hover.

## Progress Language

Target files:

- `lib/mmentum_web/live/habit_live/index.html.heex`
- Momentum presentation code.

- [ ] Render "Once per day" instead of "1 times per day."
- [ ] Render plural cadence copy correctly for all values.
- [ ] For plurals and wording logic that depends on #'s create a module to handle this in one place
- [ ] Either explain momentum in user language or remove the raw decimal from the dashboard.

Acceptance criteria:

- Dashboard copy contains no grammatical errors or unexplained implementation values.

## Activity Experience

Target files:

- `lib/mmentum_web/live/habit_live/show.html.heex`
- `lib/mmentum/logs.ex`
- `lib/mmentum/time.ex`

- [ ] Treat habit detail as the activity/history destination.
- [ ] Sort activity explicitly, preferably newest first.
- [ ] should have a timline style log view
- [ ] Include useful markers like last week, last month, last year, and last 24 hours etc as part of the timeline, where helpful. Lots of timeline views do this
- [ ] Format absolute activity times in the current user's timezone. We eitehr have a shared helper for this in our Time module or we should create one

Acceptance criteria:

- Activity order is deterministic.
- Every displayed timestamp reflects the user's saved timezone.
- Components are created and re-used in a nice destructured way keeping all modules small and focused

## Destructive Actions

Target files:

- Habit deletion UI.
- Any remaining activity deletion UI.

- [ ] Replace generic "Are you sure?" prompts with record-specific language.
- [ ] State whether deleting a habit also deletes its activity history.
- [ ] Visually distinguish cancel and destructive actions.
- [ ] Remove an item only after the server confirms deletion, or provide a real undo mechanism.
- [ ] Show completion feedback after deletion.

Acceptance criteria:

- Destructive confirmation names the habit and consequence.
- Failed deletions do not make records disappear locally.

## Empty And Initial States

Target files:

- `lib/mmentum_web/live/habit_live/index.ex`
- `lib/mmentum_web/live/habit_live/index.html.heex`

- [ ] Replace the blank timezone-initialization render with a stable dashboard shell.
- [ ] Preserve the time-aware empty-state illustration after timezone initialization.
- [ ] Make the empty-state primary action create a habit.
- [ ] Avoid decorative loading animation for fast initialization.

Acceptance criteria:

- The first authenticated render never presents an unexplained blank main area.
