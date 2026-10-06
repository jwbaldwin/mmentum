defmodule Mmentum.Checks.ModuleLocation do
  @moduledoc "Checks that module namespaces match paths beneath lib"
  use Credo.Check,
    category: :design,
    base_priority: :high,
    explanations: [check: "Module namespaces must match their paths beneath lib/"]

  @impl true
  def run(source_file, params \\ []) do
    path = Path.relative_to_cwd(source_file.filename)

    case Path.split(path) do
      ["lib" = root | _] ->
        Credo.Code.prewalk(source_file, &traverse(&1, &2, root, path, IssueMeta.for(source_file, params)))

      _ ->
        []
    end
  end

  defp traverse({:defmodule, meta, [{:__aliases__, _, name} | _]} = ast, issues, root, path, issue_meta) do
    module_path = name |> Enum.join(".") |> String.replace("OAuth", "Oauth") |> Macro.underscore()
    expected_path = root <> "/" <> module_path <> Path.extname(path)

    if namespace_path(path) == expected_path do
      {ast, issues}
    else
      issue = format_issue(issue_meta, message: "Place this module in #{expected_path}", line_no: meta[:line])
      {ast, [issue | issues]}
    end
  end

  defp traverse(ast, issues, _root, _path, _issue_meta), do: {ast, issues}

  defp namespace_path(path) do
    case Path.split(path) do
      ["lib", "mmentum_web", group | rest] when group in ["live", "controllers", "components"] ->
        Path.join(["lib", "mmentum_web" | rest])

      _ ->
        path
    end
  end
end
