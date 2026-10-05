defmodule Mmentum.MixProject do
  use Mix.Project

  def project do
    [
      app: :mmentum,
      version: "0.1.0",
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:boundary] ++ unused_compiler(Mix.env()) ++ Mix.compilers(),
      unused: [
        severity: :hint,
        ignore: [
          {:_, ~r/^__.*__\??$/, :_},
          {:_, :child_spec, 1},
          {Mmentum.Mailer, :deliver, 2},
          {Mmentum.Mailer, :deliver!, 2},
          {Mmentum.Mailer, :deliver_many, 2},
          {Mmentum.Mailer, :validate_dependency, 0},
          {Mmentum.Repo, ~r/^(disconnect_all|explain|query!?|query_many!?|to_sql)$/, :_},
          {Mmentum.Release, :migrate, 0},
          {Mmentum.Release, :rollback, 2},
          {~r/^Mmentum\.MCP\.Versions\.V\d+_\d+_\d+\.Server$/, :handle, 3},
          {~r/^Mmentum\.MCP\.Versions\.V\d+_\d+_\d+\.Response$/, :error, 4},
          {Mmentum.OAuth, :load_client, 1},
          {Mmentum.OAuth, :client_id, 1},
          {Mmentum.OAuth, :client_redirect_uris, 1},
          {Mmentum.OAuth, :client_public?, 1},
          {Mmentum.OAuth, :verify_client_secret, 2},
          {Mmentum.OAuth, :issue_refresh_token?, 2},
          {Mmentum.OAuth, :authorize_scope, 2},
          {Mmentum.OAuth, :load_principal, 1},
          {Mmentum.OAuth, :build_principal, 3},
          {Mmentum.OAuth, :create_connection, 1},
          {Mmentum.OAuth, :complete_authorization, 2},
          MmentumWeb,
          {~r/^MmentumWeb\..*Controller$/, :_, 2},
          {MmentumWeb.OAuthController, :authenticate_resource_owner, 3},
          {MmentumWeb.OAuthController, :consent, 3},
          {MmentumWeb.ErrorHTML, :render, 2},
          {MmentumWeb.ErrorJSON, :render, 2},
          {MmentumWeb.Layouts, :app, 1},
          {MmentumWeb.Layouts, :root, 1},
          {MmentumWeb.OAuthHTML, :connections, 1},
          {MmentumWeb.OAuthHTML, :consent, 1},
          {MmentumWeb.CoreComponents, :toast_group_class, 1},
          {MmentumWeb.CoreComponents, :toast_class, 1},
          {MmentumWeb.Endpoint, :socket_dispatch, 2},
          {MmentumWeb.Router, :browser, 2},
          {MmentumWeb.Router, :oauth, 2},
          {MmentumWeb.Router, :mcp_authentication, 2},
          {MmentumWeb.Router, :oauth_consent, 2},
          {MmentumWeb.Telemetry, :start_link, 1},
          {MmentumWeb.Telemetry, :metrics, 0},
          fn _mfa, metadata -> String.contains?(metadata.file, "/test/support/") end
        ]
      ],
      listeners: [Phoenix.CodeReloader],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Mmentum.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [preferred_envs: [check: :test]]
  end

  defp unused_compiler(env) when env in [:dev, :test], do: [:unused]
  defp unused_compiler(_env), do: []

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:boundary, "~> 0.11", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.17", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:excellent_migrations, "~> 0.1", only: [:dev, :test], runtime: false},
      {:jump_credo_checks, "~> 0.5", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:mix_unused, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.8", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.16", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.12", only: [:dev, :test], runtime: false},
      {:attesto_phoenix, "~> 3.2"},
      {:zoi, "~> 0.18.11"},
      {:attesto_mcp, "~> 1.3"},
      {:bcrypt_elixir, "~> 3.2"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.7"},
      {:ecto_sql, "~> 3.14"},
      {:postgrex, "~> 0.22"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.6", only: :dev},
      {:phoenix_live_view, "~> 1.2"},
      {:floki, "~> 0.38", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:live_toast, "~> 0.8.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.26"},
      {:finch, "~> 0.23"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.3"},
      {:tz, "~> 0.28"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.12"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd --cd assets npm ci"
      ],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
