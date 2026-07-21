# Visual System And Feedback

## Goal

Make every page feel like one coherent product through a small set of deliberate defaults.

## Semantic Color

Target files:

- `assets/css/app.css`
- Shared components and layout templates.

- [ ] Define semantic colors for brand, primary action, focus, success, warning, danger, and muted content.
- [ ] Decide whether primary actions remain neutral black or use brand orange.
- [ ] Align links, loading, notifications, and focus treatment with that decision.
- [ ] Replace the unrelated blue LiveView loading bar.
- [ ] Remove invalid or undefined color classes such as `border-zinc-150`.

Acceptance criteria:

- Color consistently communicates hierarchy and state across all routes.

## Typography

- [ ] Define styles for page title, section title, card/habit title, body, label, and metadata.
- [ ] Move those defaults into shared components rather than repeating arbitrary classes.
- [ ] Keep one page-level `<h1>` per route.
- [ ] Preserve the dashboard's stronger hierarchy through an explicit header variant.
- [ ] Request only used Poppins weights, likely 400, 500, and 600.
- [ ] Add `display=swap` or self-host the selected font files.

Acceptance criteria:

- Typography reflects information meaning rather than which template rendered it.

## Shape And Depth

- [ ] Define a compact radius scale for controls, grouped panels, and modals.
- [ ] Reconcile `rounded-md`, `rounded-xl`, `rounded-2xl`, and `rounded-3xl` usage.
- [ ] Define restrained shadow levels for controls, floating surfaces, and modals.
- [ ] Avoid combining large radii, heavy shadows, and lift motion on the same element.

Acceptance criteria:

- Authentication, settings, dashboard, and habit modal look like one system.

## Spacing

- [ ] Define page, section, form, field, and action-group spacing defaults.
- [ ] Reduce compounded settings spacing caused by nested `mt-10`, `space-y-8`, and `space-y-12` values.
- [ ] Preserve comfortable modal form density.
- [ ] Ensure small-screen page padding leaves enough room for content.

Acceptance criteria:

- Similar content types use consistent spacing across routes.

## Shared Buttons And Fields

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Define primary, secondary, subtle, and destructive button variants only where real usage exists.
- [ ] Standardize height, radius, typography, focus, disabled, loading, hover, and active states.
- [ ] Standardize field height, padding, radius, background, border, focus, disabled, and error states.
- [ ] Preserve caller customization without replacing essential accessibility defaults.

Acceptance criteria:

- A new form receives polished defaults without a large class override at each call site.

## Notifications

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Make notifications fit within `100vw - 2rem` on mobile.
- [ ] Give success, warning, error, and connectivity states distinct but restrained accents.
- [ ] Render a clear title and supporting message where both are supplied.
- [ ] Restrict dismissal to the close button unless whole-card dismissal is intentionally signaled.
- [ ] Decide and consistently apply auto-dismiss behavior.
- [ ] Pause auto-dismiss while the page is hidden or the toast is hovered/focused if timers are introduced.

Acceptance criteria:

- Notifications never clip and their status is identifiable without reading every word.

## Loading And Perceived Performance

- [ ] Align the global loading bar with product color.
- [ ] Keep its existing delayed appearance for fast transitions.
- [ ] Show local pending state on the control that initiated a mutation.
- [ ] Avoid global loading UI for operations that complete quickly and have clear local feedback.
- [ ] Delay or scope nonessential third-party analytics work if it competes with LiveView startup.

Acceptance criteria:

- Users can identify what is loading without unnecessary visual noise.

## Copy Consistency

- [ ] Remove remaining generated Phoenix language from user-facing routes.
- [ ] Use habit, completion, activity, progress, and momentum terminology consistently.
- [ ] Use sentence case for action labels, including "New habit."
- [ ] Keep aspirational copy concise and subordinate to task clarity.

Acceptance criteria:

- Every user-facing phrase sounds like Mmentum rather than framework scaffolding.
