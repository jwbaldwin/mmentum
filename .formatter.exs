[
  line_length: 120,
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  plugins: [Styler, Phoenix.LiveView.HTMLFormatter],
  inputs: [".*.exs", "*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
