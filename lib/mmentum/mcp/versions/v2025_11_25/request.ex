defmodule Mmentum.MCP.Versions.V2025_11_25.Request do
  @moduledoc """
  Parses MCP 2025-11-25 messages and checks their protocol version header

  Supplies omitted tool arguments as an empty object before Server dispatches
  Response formats validation failures
  """

  alias Mmentum.MCP.Versions.V2025_11_25.Response
  alias Mmentum.MCP.Versions.V2025_11_25.Server

  def parse(request, headers) do
    with :ok <- validate_message(request),
         :ok <- validate_metadata(request),
         :ok <- validate_params(request),
         :ok <- validate_version(request, headers) do
      request =
        case request do
          %{"method" => "tools/call", "params" => params} ->
            Map.put(request, "params", Map.put_new(params, "arguments", %{}))

          _request ->
            request
        end

      {:ok, request}
    end
  end

  defp validate_message(%{"jsonrpc" => "2.0", "method" => method} = request) when is_binary(method) do
    cond do
      Map.has_key?(request, "id") and is_nil(Response.request_id(request)) ->
        error(request, :invalid_request, "Request ID must be a string or integer")

      not is_map(Map.get(request, "params", %{})) ->
        error(request, :invalid_params, "params must be an object")

      true ->
        :ok
    end
  end

  defp validate_message(request), do: error(request, :invalid_request, "Invalid Request")

  defp validate_params(%{"method" => method} = request) do
    case method do
      "initialize" -> validate_initialize(request)
      "tools/call" -> validate_tool_call(request)
      "tools/list" -> validate_tools_list(request)
      _ -> :ok
    end
  end

  defp validate_initialize(request) do
    case request do
      %{
        "id" => _id,
        "params" => %{"protocolVersion" => version, "capabilities" => capabilities, "clientInfo" => info}
      }
      when is_binary(version) and is_map(capabilities) ->
        if valid_client_info?(info) and valid_capabilities?(capabilities),
          do: :ok,
          else: error(request, :invalid_params, "Invalid initialization parameters")

      _invalid ->
        error(request, :invalid_params, "Missing initialization parameters")
    end
  end

  defp validate_tool_call(request) do
    case request do
      %{"params" => %{"name" => name} = params} when is_binary(name) ->
        if optional_field?(params, "arguments", &is_map/1),
          do: :ok,
          else: error(request, :invalid_params, "arguments must be an object")

      _invalid ->
        error(request, :invalid_params, "Tool name must be a string")
    end
  end

  defp validate_tools_list(request) do
    params = Map.get(request, "params", %{})

    if optional_field?(params, "cursor", &is_binary/1),
      do: :ok,
      else: error(request, :invalid_params, "cursor must be a string")
  end

  defp validate_metadata(request) do
    if optional_field?(Map.get(request, "params", %{}), "_meta", &is_map/1),
      do: :ok,
      else: error(request, :invalid_params, "_meta must be an object")
  end

  defp validate_version(request, headers) do
    versions = for {"mcp-protocol-version", version} <- headers, do: version

    case {request, versions} do
      {%{"method" => "initialize"}, []} ->
        :ok

      {%{"method" => "initialize", "params" => %{"protocolVersion" => version}}, [version]} ->
        :ok

      {%{"method" => "initialize"}, _versions} ->
        error(request, :invalid_request, "Conflicting initialization version")

      {_request, [version]} ->
        if version == Server.protocol_version(),
          do: :ok,
          else: error(request, :invalid_request, "Unsupported protocol version")

      _missing_or_repeated ->
        error(request, :invalid_request, "Missing or repeated protocol version header")
    end
  end

  defp valid_client_info?(%{"name" => name, "version" => version} = info) when is_binary(name) and is_binary(version) do
    Enum.all?(~w(title description), &optional_field?(info, &1, fn value -> is_binary(value) end)) and
      optional_field?(info, "websiteUrl", &absolute_uri?/1) and
      optional_field?(info, "icons", fn icons -> is_list(icons) and Enum.all?(icons, &valid_icon?/1) end)
  end

  defp valid_client_info?(_info), do: false

  defp valid_icon?(%{"src" => src} = icon) do
    absolute_uri?(src) and optional_field?(icon, "mimeType", &is_binary/1) and
      optional_field?(icon, "theme", &(&1 in ["light", "dark"])) and
      optional_field?(icon, "sizes", fn sizes -> is_list(sizes) and Enum.all?(sizes, &is_binary/1) end)
  end

  defp valid_icon?(_icon), do: false

  defp absolute_uri?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) -> true
      _invalid -> false
    end
  end

  defp absolute_uri?(_value), do: false

  defp valid_capabilities?(capabilities) do
    optional_field?(capabilities, "roots", fn roots ->
      is_map(roots) and optional_field?(roots, "listChanged", &is_boolean/1)
    end) and
      optional_field?(capabilities, "sampling", &object_fields?(&1, ~w(context tools))) and
      optional_field?(capabilities, "elicitation", &object_fields?(&1, ~w(form url))) and
      optional_field?(capabilities, "experimental", fn settings ->
        is_map(settings) and Enum.all?(settings, fn {_name, options} -> is_map(options) end)
      end) and optional_field?(capabilities, "tasks", &valid_tasks?/1)
  end

  defp valid_tasks?(tasks) do
    object_fields?(tasks, ~w(list cancel)) and
      optional_field?(tasks, "requests", fn requests ->
        is_map(requests) and
          optional_field?(requests, "sampling", &object_fields?(&1, ["createMessage"])) and
          optional_field?(requests, "elicitation", &object_fields?(&1, ["create"]))
      end)
  end

  defp object_fields?(object, fields) do
    is_map(object) and Enum.all?(fields, &optional_field?(object, &1, fn value -> is_map(value) end))
  end

  defp optional_field?(object, key, valid?) do
    case Map.fetch(object, key) do
      :error -> true
      {:ok, value} -> valid?.(value)
    end
  end

  defp error(request, reason, message), do: {:error, 400, Response.error(Response.request_id(request), reason, message)}
end
