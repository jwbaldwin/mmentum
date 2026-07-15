defmodule Mmentum.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mmentum.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      full_name: "Test User"
    })
  end

  def user_fixture(attrs \\ %{}) do
    time_zone = Map.get(attrs, :time_zone, "Etc/UTC")

    {:ok, user} =
      attrs
      |> Map.delete(:time_zone)
      |> valid_user_attributes()
      |> Mmentum.Accounts.register_user()

    {:ok, user} = Mmentum.Accounts.update_user_time_zone(user, time_zone)
    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
