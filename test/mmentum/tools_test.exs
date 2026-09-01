defmodule Mmentum.ToolsTest do
  use ExUnit.Case, async: true

  alias Mmentum.Tools

  test "the registered catalog starts empty" do
    assert Tools.tool_modules() == []
    assert Tools.definitions() == []
    assert Tools.execute("missing_tool", %{}, %{}) == {:error, :tool_not_found}
  end
end
