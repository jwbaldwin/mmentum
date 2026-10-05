# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :attesto_phoenix, otp_app: :mmentum

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.28.1",
  default: [
    args:
      ~w(js/app.js js/theme.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :excellent_migrations, start_after: "20260906023636"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :mmentum, AttestoPhoenix.Config,
  keystore: Attesto.Keystore.Static,
  repo: Mmentum.Repo,
  load_client: {Mmentum.OAuth, :load_client},
  client_id: {Mmentum.OAuth, :client_id},
  client_redirect_uris: {Mmentum.OAuth, :client_redirect_uris},
  client_public?: {Mmentum.OAuth, :client_public?},
  verify_client_secret: {Mmentum.OAuth, :verify_client_secret},
  load_principal: {Mmentum.OAuth, :load_principal},
  build_principal: {Mmentum.OAuth, :build_principal},
  authorize_scope: {Mmentum.OAuth, :authorize_scope},
  authenticate_resource_owner: {MmentumWeb.OAuthController, :authenticate_resource_owner},
  consent: {MmentumWeb.OAuthController, :consent},
  authorization_code_private_context: {Mmentum.OAuth, :create_connection},
  authorization_code_completion: {Mmentum.OAuth, :complete_authorization},
  authorization_grant_id_claim: "mmentum_grant_id",
  issue_refresh_token?: {Mmentum.OAuth, :issue_refresh_token?},
  code_store: AttestoPhoenix.Store.EctoCodeStore,
  refresh_store: AttestoPhoenix.Store.EctoRefreshStore,
  scopes_supported: ["mmentum:read", "mmentum:write"],
  grant_types_supported: ["authorization_code", "refresh_token"],
  token_endpoint_auth_methods_supported: ["none"],
  access_token_ttl: 300,
  refresh_token_ttl: 2_592_000,
  refresh_token_rotation_grace_seconds: 0,
  sweep_interval_ms: 60_000,
  dpop_enabled: false

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :mmentum, Mmentum.Mailer, adapter: Swoosh.Adapters.Local

# Configures the endpoint
config :mmentum, MmentumWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: MmentumWeb.ErrorHTML, json: MmentumWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Mmentum.PubSub,
  live_view: [signing_salt: "Yi2QGI4t"]

config :mmentum, :oauth_consent, salt: "oauth-consent-request", max_age: 300

config :mmentum,
  ecto_repos: [Mmentum.Repo]

config :phoenix, :filter_parameters, ["password", "secret", "token", "code", "request"]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.2",
  default: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
