defmodule Mmentum.TestTools.GreetingTool do
  @behaviour Mmentum.Tools.Tool

  @impl true
  def name, do: "greet_user"

  @impl true
  def description, do: "Greets the authenticated user"

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{"greeting" => %{"type" => "string"}},
      "required" => ["greeting"]
    }
  end

  @impl true
  def output_schema do
    %{
      "type" => "object",
      "properties" => %{"message" => %{"type" => "string"}},
      "required" => ["message"]
    }
  end

  @impl true
  def required_scope, do: "mmentum:read"

  @impl true
  def execute(%{user: user}, %{"greeting" => greeting}) do
    {:ok, %{"message" => "#{greeting}, #{user.name}"}}
  end
end
