defmodule Mmentum.ToolsTest do
  use ExUnit.Case, async: true

  alias Mmentum.TestTools.GreetingTool
  alias Mmentum.Tools

  test "the registered catalog starts empty" do
    assert Tools.modules() == []
    assert Tools.definitions() == []
    assert Tools.execute("missing_tool", %{}, %{}) == {:error, :tool_not_found}
  end

  test "definitions/1 describes each conforming tool" do
    assert Tools.definitions([GreetingTool]) == [
             %{
               "name" => "greet_user",
               "description" => "Greets the authenticated user",
               "inputSchema" => %{
                 "type" => "object",
                 "properties" => %{"greeting" => %{"type" => "string"}},
                 "required" => ["greeting"]
               },
               "outputSchema" => %{
                 "type" => "object",
                 "properties" => %{"message" => %{"type" => "string"}},
                 "required" => ["message"]
               }
             }
           ]
  end

  test "execute/4 invokes a conforming tool with server context" do
    context = %{user: %{name: "James"}}

    assert Tools.execute([GreetingTool], "greet_user", context, %{"greeting" => "Hello"}) ==
             {:ok, %{"message" => "Hello, James"}}
  end

  test "execute/4 rejects names outside the explicit catalog" do
    assert Tools.execute([GreetingTool], "missing_tool", %{}, %{}) ==
             {:error, :tool_not_found}
  end
end
