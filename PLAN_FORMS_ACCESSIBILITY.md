# Forms And Accessibility

## Goal

Make correct keyboard, screen-reader, and form behavior the default provided by shared components.

## Shared Focus Treatment

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Replace `focus:ring-0` defaults with a visible `focus-visible` treatment.
- [ ] Apply the same focus language to text inputs, textareas, selects, checkboxes, buttons, and links.
- [ ] Preserve distinct error styling while focused.
- [ ] Ensure disabled controls remain legible and visibly noninteractive.

Acceptance criteria:

- Every interactive element has a visible keyboard focus state with sufficient contrast.

## Icon-Only Controls

- [ ] Require an accessible name for every icon-only button.
- [ ] Add concise tooltips only where the icon remains ambiguous after naming.
- [ ] Ensure tooltips are not the sole source of an accessible name.
- [ ] Keep touch targets at least 44px square.

Acceptance criteria:

- Automated and manual inspection finds no unnamed interactive controls.

## Modal Naming

Target file:

- `lib/mmentum_web/components/core_components.ex`

- [ ] Connect `aria-labelledby` to a real modal heading ID.
- [ ] Connect `aria-describedby` only when a real description exists.
- [ ] Make title and description behavior part of the modal API.
- [ ] Preserve focus trapping, Escape, click-away, focus restoration, and scroll locking.

Acceptance criteria:

- Each modal announces a useful name when opened with a screen reader.

## Authentication Form Labels

Target files:

- `lib/mmentum_web/live/user_forgot_password_live.ex`
- `lib/mmentum_web/live/user_confirmation_instructions_live.ex`
- Registration, login, and reset-password LiveViews.

- [ ] Add persistent visible labels to every field.
- [ ] Use `autocomplete="name"` for full name.
- [ ] Use `autocomplete="email"` for email fields.
- [ ] Use `autocomplete="current-password"` for login and current-password fields.
- [ ] Use `autocomplete="new-password"` for registration and reset fields.
- [ ] Show the 12-character password requirement before validation fails.

Acceptance criteria:

- Password managers and browser autofill identify every authentication field correctly.

## Heading Structure

Target files:

- `lib/mmentum_web/components/core_components.ex`
- Dashboard and settings templates.

- [ ] Ensure each page renders exactly one `<h1>`.
- [ ] Add shared page-title size variants instead of nesting another heading inside the header component.
- [ ] Use section headings in settings and activity.

Acceptance criteria:

- Heading levels form a logical document outline on every route.

## Settings Structure

Target file:

- `lib/mmentum_web/live/user_settings_live.ex`

- [ ] Add Time zone, Email address, and Password section headings.
- [ ] Add concise descriptions of what each setting affects.
- [ ] Keep timezone editing simple and show the currently saved value.
- [ ] Confirm timezone changes inline or with a restrained success notification.
- [ ] Update the current user assign immediately after saving.

Acceptance criteria:

- Users can scan the settings page and know whether each save succeeded.

## Error And Recovery Pages

Target file:

- `lib/mmentum_web/controllers/error_html.ex`

- [ ] Replace plain 404 text with a branded explanation and dashboard action.
- [ ] Replace plain 500 text with a concise recovery message and retry/dashboard action.
- [ ] Preserve correct status codes.

Acceptance criteria:

- Error pages maintain orientation and provide a next action.
