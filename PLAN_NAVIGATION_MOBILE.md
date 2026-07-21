# Navigation And Mobile

## Goal

Keep navigation focused and usable from 320px upward without introducing a large application shell.

## Semantic Header

Target file:

- `lib/mmentum_web/components/layouts/app.html.heex`

- [ ] Add a semantic, named `<nav>` region.
- [ ] Give the logo link an accessible name.
- [ ] Use meaningful image alternative text or mark the image decorative when the link supplies the name.
- [ ] Keep the dashboard reachable through the logo.

Acceptance criteria:

- Screen readers announce the logo link and navigation purpose clearly.

## Responsive Account Navigation

Target file:

- `lib/mmentum_web/components/layouts/app.html.heex`

- [ ] take a look at ~/repos/projects/arnor/assets/ for the account nav dropdown with the avatar and take as much of that as we can (i know we can't just copy bc that's react and we are liveview but we can do most of it I think?)

Acceptance criteria:

- Header items are collapsed and use the Arnor dropdown button style

## Product Information Architecture

- [ ] Keep the dashboard as the primary destination.
- [ ] Make habit activity discoverable through each habit.
- [ ] Keep editing secondary to viewing a habit.
- [ ] Do not add global Logs navigation.
- [ ] Decide whether any standalone activity route provides value beyond habit detail.

Acceptance criteria:

- Primary navigation reflects user goals rather than database entities.

## Responsive Dashboard Layout

Target file:

- `lib/mmentum_web/live/habit_live/index.html.heex`

- [ ] Stack habit title, cadence, progress, and controls intentionally on small screens.
- [ ] Avoid single-column grid allocations for multi-button control groups.
- [ ] Preserve clear separation between adjacent habits.
- [ ] Verify long habit names wrap without covering actions.

Acceptance criteria:

- Dashboard remains readable and operable at 320px, 390px, tablet, and desktop widths.

## Navigation Behavior

- [ ] Use LiveView `navigate` for destination changes and `patch` for modal/state changes within a LiveView.
- [ ] Avoid full reloads for internal product navigation without a concrete reason.
- [ ] Verify browser Back closes URL-addressable modals and restores the prior page state.

Acceptance criteria:

- Navigation behavior is spatially predictable and preserves browser history.
