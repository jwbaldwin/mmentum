# MCP Tools

- `list_habits` (implemented): List every habit owned by the authenticated user with current progress. No arguments; requires `mmentum:read`.
- `get_habit` (implemented): Get one owned habit with its full definition and current progress. Requires `habit_id` and `mmentum:read`.
- `create_habit` (implemented): Create a habit from validated fields. Requires `name`, `min_completions`, and `mmentum:write`; periodicity defaults to week. Repeating the call creates another habit.
- `update_habit` (implemented): Update supplied `fields` on an owned `habit_id`. Omission preserves stored fields; null clears optional fields. Requires `mmentum:write`.
- `record_habit_completions`: Record one or more dated completions across the user's owned habits.
- `list_habit_history`: List paginated completion history for one owned habit within optional dates.
- `remove_habit_completion`: Remove one mistaken completion from a habit owned by the user.
