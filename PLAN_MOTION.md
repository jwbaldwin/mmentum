# Motion And Interaction Feedback

## Goal

Use motion only to explain state or acknowledge interaction. Keep the product crisp, quiet, and fast.

## Motion Tokens

Target files:

- `assets/css/app.css`
- `lib/mmentum_web/components/core_components.ex`

- [ ] Define a strong UI ease-out: `cubic-bezier(0.23, 1, 0.32, 1)`.
- [ ] Define a strong ease-in-out for genuine on-screen movement: `cubic-bezier(0.77, 0, 0.175, 1)`.
- [ ] Use 100–160ms for press feedback.
- [ ] Use 150–220ms for small entrances and modal transitions.
- [ ] Keep UI transitions below 300ms.

Acceptance criteria:

- Shared components use the same timing and easing vocabulary.

## Remove Broad Transitions

- [ ] Replace every relevant `transition-all` with explicit properties.
- [ ] Animate only transform and opacity for movement.
- [ ] Use color, border-color, and box-shadow transitions only for visual-state changes.
- [ ] Avoid animating dimensions, padding, and margins.

Acceptance criteria:

- No user-interface transition accidentally animates layout properties.

## Button Feedback

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Add subtle `active:scale-[0.98]` feedback to primary pressables.
- [ ] Use an explicit transform transition around 120–160ms.
- [ ] Preserve disabled and submitting states without press motion.
- [ ] Prefer restrained color/shadow hover over upward translation.
- [ ] Gate hover-only movement behind `(hover: hover) and (pointer: fine)` if any remains.

Acceptance criteria:

- Buttons acknowledge presses immediately without feeling bouncy or decorative.

## Habit List Motion

Target file:

- `lib/mmentum_web/live/habit_live/index.html.heex`

- [ ] Remove title translation on hover.
- [ ] Remove pulse animation from noninteractive completion nodes.
- [ ] Animate only actual completion state changes.
- [ ] Keep completion transitions under 200ms.
- [ ] Do not stagger frequently rendered dashboard items.

Acceptance criteria:

- Motion communicates a real state change and never implies false interactivity.

## Modal Motion

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Use opacity plus a subtle scale or short vertical offset for entry.
- [ ] Never animate from `scale(0)`.
- [ ] Keep modal transform origin centered.
- [ ] Use ease-out for both entry and exit, with exit faster than entry.
- [ ] Ensure rapid open/close interactions can reverse cleanly.

Suggested behavior:

- Enter: 200ms from `opacity: 0; transform: scale(0.98)`.
- Exit: 140ms to `opacity: 0; transform: scale(0.98)`.

## Toast Motion

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Use interruptible transitions rather than entrance keyframes.
- [ ] Enter from its dismissal direction with opacity and a short percentage-based translation.
- [ ] Exit faster than entry.
- [ ] Keep close-button interaction independent from whole-card dismissal.

Acceptance criteria:

- Rapidly replaced notifications retarget smoothly without restarting a keyframe.

## Reduced Motion

Target file:

- `assets/css/app.css`

- [ ] Add a `prefers-reduced-motion: reduce` policy.
- [ ] Remove positional and scale movement under reduced motion.
- [ ] Preserve short opacity and color transitions that aid comprehension.
- [ ] Disable decorative pulse, lift, and spin where not required for status.

Acceptance criteria:

- All core flows remain clear without spatial animation.

## Motion Verification

- [ ] Inspect modal, toast, completion, and button transitions in browser slow-motion tools.
- [ ] Confirm easing starts responsively and settles without abrupt stops.
- [ ] Test hover behavior on a touch device.
- [ ] Test rapid repeated interaction for interruption artifacts.
