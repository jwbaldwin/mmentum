defmodule Mmentum.OAuthDisconnectLockingTest do
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Mmentum.AccountsFixtures
  alias Mmentum.OAuth
  alias Mmentum.OAuth.Connection
  alias Mmentum.Repo

  test "disconnect waits for in-flight authorization completion row lock" do
    parent = self()

    {user, connection} =
      unboxed(fn ->
        user = AccountsFixtures.user_fixture()
        connection = Repo.insert!(%Connection{id: Ecto.UUID.generate(), user_id: user.id, client_id: "oauth-test"})
        {user, connection}
      end)

    on_exit(fn -> cleanup_user(user.id) end)
    start_supervised!({Task.Supervisor, name: __MODULE__})

    {completion_pid, completion_monitor} =
      start_database_task(fn ->
        result =
          OAuth.complete_authorization(
            %{
              family_id: connection.id,
              private_context: %{"connection_id" => connection.id},
              subject: "user:#{user.id}",
              client_id: connection.client_id
            },
            fn ->
              send(parent, {:completion_holds_lock, self()})

              receive do
                :release_completion -> {:error, :stopped}
              end
            end
          )

        send(parent, {:completion_result, result})
      end)

    assert_receive {:completion_holds_lock, ^completion_pid}

    {disconnect_pid, disconnect_monitor} =
      start_database_task(fn ->
        backend_pid = Repo.query!("select pg_backend_pid()", []).rows |> hd() |> hd()
        send(parent, {:disconnect_backend_pid, backend_pid})
        send(parent, {:disconnect_result, OAuth.disconnect(user, connection.id)})
      end)

    assert_receive {:disconnect_backend_pid, backend_pid}
    assert_waiting_on_lock(backend_pid)
    refute_received {:disconnect_result, _result}

    send(completion_pid, :release_completion)

    assert_receive {:completion_result, {:error, :stopped}}
    assert_receive {:disconnect_result, {:ok, :ok}}

    assert unboxed(fn -> Repo.get!(Connection, connection.id).revoked_at end)

    assert_receive {:DOWN, ^completion_monitor, :process, ^completion_pid, :normal}
    assert_receive {:DOWN, ^disconnect_monitor, :process, ^disconnect_pid, :normal}
  end

  defp start_database_task(fun) do
    {:ok, pid} = Task.Supervisor.start_child(__MODULE__, fn -> unboxed(fun) end)
    {pid, Process.monitor(pid)}
  end

  defp unboxed(fun) do
    Sandbox.unboxed_run(Repo, fun)
  end

  defp assert_waiting_on_lock(backend_pid) do
    deadline = System.monotonic_time(:millisecond) + 1_000
    assert_waiting_on_lock(backend_pid, deadline)
  end

  defp assert_waiting_on_lock(backend_pid, deadline) do
    if lock_waiting?(backend_pid) do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("expected disconnect backend #{backend_pid} to wait on the connection row lock")
      end

      receive do
      after
        10 -> assert_waiting_on_lock(backend_pid, deadline)
      end
    end
  end

  defp lock_waiting?(backend_pid) do
    unboxed(fn ->
      Repo.one(
        from activity in "pg_stat_activity",
          where: activity.pid == ^backend_pid,
          select: activity.wait_event_type == "Lock"
      )
    end)
  end

  defp cleanup_user(user_id) do
    unboxed(fn ->
      Repo.delete_all(from connection in Connection, where: connection.user_id == ^user_id)
      Repo.delete_all(from token in "users_tokens", where: token.user_id == ^user_id)
      Repo.delete_all(from user in "users", where: user.id == ^user_id)
    end)
  end
end
