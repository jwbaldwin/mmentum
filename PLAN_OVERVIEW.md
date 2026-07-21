# Mmentum UX Improvement Plan

This plan set is the source of truth for the next UX and design-engineering pass.

Edit, delete, or rewrite anything that should not be implemented. Once reviewed, the remaining unchecked items define the implementation scope.

## Product Direction

Keep Mmentum focused on two connected experiences:

1. The habit dashboard for seeing progress and recording completions.
2. Habit activity for understanding progress over time.

Generated administration surfaces should not remain user-facing unless they support one of those experiences.

## Plan Files

- `PLAN_CRITICAL.md`: trust, authorization, broken flows, and crash prevention.
- `PLAN_CORE_EXPERIENCE.md`: dashboard, habit progress, completion controls, and activity.
- `PLAN_NAVIGATION_MOBILE.md`: information architecture, header behavior, and responsive layout.
- `PLAN_FORMS_ACCESSIBILITY.md`: keyboard behavior, labels, dialogs, authentication, and settings.
- `PLAN_MOTION.md`: interaction feedback, transitions, timing, easing, and reduced motion.
- `PLAN_VISUAL_SYSTEM.md`: typography, color, shape, spacing, notifications, and loading polish.

## Execution Order

1. Complete `PLAN_CRITICAL.md`.
2. Complete the dashboard and activity work in `PLAN_CORE_EXPERIENCE.md`.
3. Complete `PLAN_NAVIGATION_MOBILE.md` and `PLAN_FORMS_ACCESSIBILITY.md` together.
4. Consolidate shared primitives in `PLAN_VISUAL_SYSTEM.md`.
5. Apply `PLAN_MOTION.md` after component structure and visual states are stable.
6. Run the final quality pass below.

## Existing Strengths To Preserve

- URL-addressable habit modals and browser history behavior.
- Modal focus trapping, Escape dismissal, click-away dismissal, scroll locking, and focus restoration.
- The product-oriented language and hierarchy in the habit form.
- The personalized, time-aware dashboard greeting.
- The time-specific empty-state illustration.
- Authentication responses that do not reveal whether an email exists.
- Delayed display of the global LiveView loading indicator.
- Stable scrollbar gutter that prevents horizontal layout shifts.

## Final Quality Pass

- [ ] Test every user-facing route at 320px, 390px, tablet, and desktop widths.
- [ ] Test all flows with keyboard-only navigation.
- [ ] Test visible focus, modal focus containment, and focus restoration.
- [ ] Test with `prefers-reduced-motion: reduce`.
- [ ] Test completion actions under simulated LiveView latency.
- [ ] Test empty, loading, success, validation-error, server-error, and disconnected states.
- [ ] Confirm all icon-only controls have accessible names.
- [ ] Confirm every page has one correctly structured `<h1>`.
- [ ] Confirm destructive actions name the affected object and consequence.
- [ ] Confirm activity timestamps and date boundaries use the user's timezone.
