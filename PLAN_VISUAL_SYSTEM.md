# Visual System And Feedback

## Goal

Make every page feel like one coherent product through a small set of deliberate defaults.

## Semantic Color

Target files:

- `assets/css/app.css`
- Shared components and layout templates.

- [x] Define semantic colors for brand, primary action, focus, success, warning, danger, and muted content.
- [x] Keep primary actions neutral black and reserve brand orange for links, focus, and loading.
- [x] Align links, loading, notifications, and focus treatment with that decision.
- [x] Replace the unrelated blue LiveView loading bar.
- [x] Remove invalid or undefined color classes such as `border-zinc-150`.

Acceptance criteria:

- Color consistently communicates hierarchy and state across all routes.

## Typography

- [x] Define styles for page title, section title, card/habit title, body, label, and metadata.
- [x] Move those defaults into shared components rather than repeating arbitrary classes.
- [x] Keep one page-level `<h1>` per route.
- [x] Preserve the dashboard's stronger hierarchy through an explicit header variant.
- [x] Request only used Poppins weights: 400, 500, and 600.
- [x] Add `display=swap` to the selected font request.

Acceptance criteria:

- Typography reflects information meaning rather than which template rendered it.

## Shape And Depth

- [x] Define a compact radius scale for controls, grouped panels, and modals.
- [x] Reconcile `rounded-md`, `rounded-xl`, `rounded-2xl`, and `rounded-3xl` usage.
- [x] Define restrained shadow levels for controls, floating surfaces, and modals.
- [x] Avoid combining large radii, heavy shadows, and lift motion on the same element.

Acceptance criteria:

- Authentication, settings, dashboard, and habit modal look like one system.

## Spacing

- [x] Define page, section, form, field, and action-group spacing defaults.
- [x] Reduce compounded settings spacing caused by nested `mt-10`, `space-y-8`, and `space-y-12` values.
- [x] Preserve comfortable modal form density.
- [x] Ensure small-screen page padding leaves enough room for content.

Acceptance criteria:

- Similar content types use consistent spacing across routes.

## Shared Buttons And Fields

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [x] Define primary and destructive variants where real usage exists; defer unused secondary and subtle variants.
- [x] Standardize height, radius, typography, focus, disabled, loading, hover, and active states.
- [x] Standardize field height, padding, radius, background, border, focus, disabled, and error states.
- [x] Preserve caller customization without replacing essential accessibility defaults.

Acceptance criteria:

- A new form receives polished defaults without a large class override at each call site.

## Notifications

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [x] Make notifications fit within `100vw - 2rem` on mobile.
- [x] Use one neutral surface and distinguish severity with monochrome icons.
- [x] Render the message without a generated severity title.
- [x] Restrict dismissal to the close button unless whole-card dismissal is intentionally signaled.
- [x] Auto-dismiss app notifications after three seconds.
- [x] Keep manual dismissal available while a notification is visible.

Acceptance criteria:

- Notifications never clip, and each severity remains identifiable by its icon.

## Loading And Perceived Performance

- [x] Align the global loading bar with product color.
- [x] Keep its existing delayed appearance for fast transitions.
- [x] Show local pending state on the control that initiated a mutation.
- [x] Reserve global loading UI for navigation and use local feedback for mutations.
- [x] Delay nonessential third-party analytics work until the app is interactive and the browser is idle.

Acceptance criteria:

- Users can identify what is loading without unnecessary visual noise.

## Copy Consistency

- [x] Remove remaining generated Phoenix language from user-facing routes.
- [x] Use habit, completion, activity, progress, and momentum terminology consistently.
- [x] Use sentence case for action labels, including "New habit."
- [x] Keep aspirational copy concise and subordinate to task clarity.

Acceptance criteria:

- Every user-facing phrase sounds like Mmentum rather than framework scaffolding.
