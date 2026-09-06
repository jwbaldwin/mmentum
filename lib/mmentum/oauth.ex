defmodule Mmentum.OAuth do
  @moduledoc """
  Connects OAuth clients to Mmentum users and lets users disconnect them

  Supplies Attesto with client and user lookups and tracks each approved connection
  """

  import Ecto.Query
  alias Mmentum.{Repo, OAuth.Connection}
  alias Mmentum.Accounts.User
  alias AttestoPhoenix.Config
  alias AttestoPhoenix.Store.{EctoCodeStore, EctoRefreshStore}
  alias AttestoPhoenix.Schema.RefreshFamilyRevocation

  def config, do: Config.from_otp_app(:mmentum)
  def token_config, do: Config.to_attesto_config(config())
  def issuer(_conn), do: config().issuer

  def load_client(id) do
    case Enum.find(Application.fetch_env!(:mmentum, :oauth_clients), &(&1["id"] == id)) do
      nil -> {:error, :not_found}
      client -> {:ok, client}
    end
  end

  def client_id(client), do: Map.fetch!(client, "id")
  def client_redirect_uris(client), do: Map.fetch!(client, "redirect_uris")
  def client_public?(_client), do: true
  def verify_client_secret(_client, _secret), do: false
  def issue_refresh_token?(_client, _scopes), do: true

  def authorize_scope(_client, requested) do
    supported = config().scopes_supported

    if requested != [] and Enum.all?(requested, &(&1 in supported)),
      do: {:ok, requested},
      else: {:error, :invalid_scope}
  end

  def load_principal("user:" <> id) do
    with {id, ""} when id > 0 <- Integer.parse(id),
         %User{} = user <- Repo.get(User, id) do
      {:ok, user}
    else
      _ -> {:error, :not_found}
    end
  end

  def load_principal(_subject), do: {:error, :not_found}

  def build_principal(_client, subject, scopes) do
    case load_principal(subject) do
      {:ok, _user} -> %{kind: "user", sub: subject, scopes: scopes}
      {:error, :not_found} -> nil
    end
  end

  def create_connection(%{subject: subject, client_id: client_id, family_id: grant_id}) do
    {:ok, user} = load_principal(subject)
    Repo.insert!(%Connection{id: grant_id, user_id: user.id, client_id: client_id})
    %{"connection_id" => grant_id}
  end

  @doc "Locks the connection against Disconnect until Attesto finishes issuing tokens"
  def complete_authorization(context, continuation) do
    Repo.transaction(fn ->
      connection =
        Repo.one(from connection in Connection, where: connection.id == ^context.family_id, lock: "FOR UPDATE")

      case connection do
        %Connection{revoked_at: nil} ->
          case continuation.() do
            {:ok, response, _events} = result ->
              {:ok, refresh} = EctoRefreshStore.get(Attesto.Secret.hash(response.refresh_token))

              connection
              |> Ecto.Changeset.change(refresh_family_id: refresh.family_id, scopes: refresh.data.scope)
              |> Repo.update!()

              result

            {:error, error} ->
              Repo.rollback(error)
          end

        _ ->
          Repo.rollback(:revoked_connection)
      end
    end)
  end

  def list_connections(user) do
    Repo.all(
      from connection in Connection,
        where: connection.user_id == ^user.id and is_nil(connection.revoked_at),
        order_by: [desc: connection.inserted_at]
    )
  end

  def disconnect(user, id) do
    Repo.transaction(fn ->
      case Repo.one(
             from connection in Connection,
               where: connection.id == ^id and connection.user_id == ^user.id,
               lock: "FOR UPDATE"
           ) do
        nil ->
          Repo.rollback(:not_found)

        connection ->
          connection |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update!()

          if connection.refresh_family_id do
            :ok = EctoRefreshStore.revoke_family(connection.refresh_family_id)
            :ok = EctoCodeStore.revoke_family_access_tokens(connection.refresh_family_id)
          end

          :ok
      end
    end)
  end

  def authenticate_token(%{"sub" => subject, "mmentum_grant_id" => grant_id, "jti" => jti}, _sender) do
    with {:ok, user} <- load_principal(subject),
         %Connection{revoked_at: nil, refresh_family_id: family_id} when not is_nil(family_id) <-
           Repo.get_by(Connection, id: grant_id, user_id: user.id),
         false <- Repo.exists?(from revocation in RefreshFamilyRevocation, where: revocation.family_id == ^family_id),
         false <- EctoCodeStore.access_token_revoked?(jti) do
      {:ok, user}
    else
      _ -> {:error, :revoked_connection}
    end
  end

  def authenticate_token(_claims, _sender), do: {:error, :invalid_connection}
end
