defmodule Mmentum do
  @moduledoc """
  Mmentum keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others
  """
  use Boundary,
    deps: [],
    exports: [
      Accounts,
      Accounts.User,
      Habits,
      Habits.Habit,
      Habits.Values.MomentumSeries,
      Logs,
      MCP.Transport.StreamableHTTP,
      OAuth,
      Repo,
      Time
    ]
end
