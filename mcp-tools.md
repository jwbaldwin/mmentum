# MCP Tools

- `list_habits` (implemented): List every habit owned by the authenticated user with current progress. No arguments; requires `mmentum:read`.
- `get_habit` (implemented): Get a habit's definition, current progress, and completions from its current and previous local periods. Requires `habit_id` and `mmentum:read`. Use `history: "all"` for a page of complete history, with `limit` (default 50, maximum 100) and `cursor`.
- `create_habit` (implemented): Create a habit from validated fields. Requires `name`, `min_completions`, and `mmentum:write`; periodicity defaults to week. Repeating the call creates another habit.
- `update_habit` (implemented): Update supplied `fields` on an owned `habit_id`. Omission preserves stored fields; null clears optional fields. Requires `mmentum:write`.
- `manage_habit_completions` (implemented): Add completions, remove mistakes by completion ID, or do both. Saves all changes or none. Requires `mmentum:write`. Omitted times use now; repeating additions creates more entries.

Completion history comes from `get_habit`, not a separate tool. Each recent period has `starts_at`, `ends_before`, and `completions`. Boundaries and completion times are UTC timestamps; `time_zone` names the local calendar used. An empty period still appears with an empty list. Recent periods are returned in full and do not change `list_habits`.

Complete history is newest first. Pass `history.next_cursor` unchanged as `cursor`, keeping `history: "all"`, to get the next page. A null cursor means there are no more entries. Supplying `limit` or `cursor` without `history: "all"` returns an argument error.
