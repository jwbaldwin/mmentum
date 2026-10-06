defmodule Mmentum.Checks.EntityValue do
  @moduledoc "Checks the source-level contract shared by entity Values and their Ecto schemas"
  use Credo.Check,
    category: :design,
    base_priority: :high,
    run_on_all: true,
    explanations: [check: "Entity Values own their Zoi schema, generated type, and typed builders"]

  @impl true
  def run_on_all_source_files(exec, source_files, params) do
    modules =
      source_files
      |> Enum.filter(&String.starts_with?(Path.relative_to_cwd(&1.filename), "lib/"))
      |> Enum.flat_map(&modules/1)

    schemas = Map.new(Enum.filter(modules, &ecto_schema?/1), &{&1.name, &1})

    for value <- modules, :Values in value.name do
      schema = Map.get(schemas, List.delete(value.name, :Values))

      for message <- entity_violations(value, schema) do
        issue = format_issue(IssueMeta.for(value.source, params), message: message, line_no: value.line)
        Credo.Execution.ExecutionIssues.append(exec, value.source, issue)
      end
    end

    :ok
  end

  defp modules(source) do
    {_ast, modules} =
      Macro.prewalk(Credo.SourceFile.ast(source), [], fn
        {:defmodule, meta, [{:__aliases__, _, name}, [do: body]]} = ast, modules ->
          module = %{name: name, line: meta[:line], source: source, forms: expand_aliases(forms(body))}
          {ast, [module | modules]}

        ast, modules ->
          {ast, modules}
      end)

    modules
  end

  defp forms({:__block__, _, forms}), do: forms
  defp forms(form), do: [form]

  defp expand_aliases(forms) do
    aliases =
      Map.new(
        for {:alias, _, [{:__aliases__, _, name} | options]} <- forms do
          short =
            case Keyword.get(List.flatten(options), :as) do
              {:__aliases__, _, short} -> short
              nil -> [List.last(name)]
            end

          {short, name}
        end
      )

    Macro.prewalk(forms, fn
      {:__aliases__, meta, name} -> {:__aliases__, meta, Map.get(aliases, name, name)}
      ast -> ast
    end)
  end

  defp ecto_schema?(module) do
    Enum.any?(module.forms, fn
      {:use, _, [{:__aliases__, _, [:Ecto, :Schema]} | _]} -> true
      _ -> false
    end)
  end

  defp entity_violations(_value, nil), do: []

  defp entity_violations(value, schema) do
    schema_attribute = generated_schema_attribute(value.forms)
    specs = for {:@, _, [{:spec, _, [spec]}]} <- value.forms, do: Macro.to_string(spec)
    schema_name = Enum.join(schema.name, ".")
    builders = for {:def, _, [head | _]} <- value.forms, build_head?(head), do: head

    requirements = [
      {schema_attribute != nil, "Generate the Value's t() with Zoi.type_spec/1 from its schema attribute"},
      {owns_schema?(value.forms, schema_attribute), "Define the Zoi schema in this Value and return it from schema/0"},
      {builders != [], "Expose a public build/1 for this entity Value"},
      {"build(#{schema_name}.t()) :: t()" in specs, "Spec build/1 from #{schema_name}.t() to the Value's t()"},
      {not Enum.any?(builders, &list_builder?/1) or "build([#{schema_name}.t()]) :: [t()]" in specs,
       "Spec the list builder from [#{schema_name}.t()] to [t()]"},
      {has_type?(schema.forms), "Define the stored record's t() on #{schema_name}"}
    ]

    for {false, message} <- requirements, do: message
  end

  defp generated_schema_attribute(forms) do
    Enum.find_value(forms, fn
      {:@, _, [{:type, _, [{:"::", _, [{:t, _, _}, {:unquote, _, [call]}]}]}]} ->
        case call do
          {{:., _, [{:__aliases__, _, [:Zoi]}, :type_spec]}, _, [{:@, _, [{attribute, _, _}]}]} -> attribute
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  defp owns_schema?(_forms, nil), do: false

  defp owns_schema?(forms, attribute) do
    defined? =
      Enum.any?(forms, fn
        {:@, _, [{^attribute, _, [{{:., _, [{:__aliases__, _, [:Zoi]}, _]}, _, _}]}]} -> true
        _ -> false
      end)

    exposed? =
      Enum.any?(forms, fn
        {:def, _, [{:schema, _, args}, [do: {:@, _, [{^attribute, _, _}]}]]} when args in [nil, []] -> true
        _ -> false
      end)

    defined? and exposed?
  end

  defp build_head?({:when, _, [head | _]}), do: build_head?(head)
  defp build_head?({:build, _, [_]}), do: true
  defp build_head?(_head), do: false

  defp list_builder?({:when, _, [{:build, _, [{name, _, context}]}, {:is_list, _, [{name, _, context}]}]}), do: true
  defp list_builder?({:build, _, [argument]}) when is_list(argument), do: true
  defp list_builder?(_head), do: false

  defp has_type?(forms) do
    Enum.any?(forms, fn
      {:@, _, [{:type, _, [{:"::", _, [{:t, _, _}, _]}]}]} -> true
      _ -> false
    end)
  end
end
