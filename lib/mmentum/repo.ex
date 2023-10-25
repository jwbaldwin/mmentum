defmodule Mmentum.Repo do
  use Ecto.Repo,
    otp_app: :mmentum,
    adapter: Ecto.Adapters.Postgres
end
