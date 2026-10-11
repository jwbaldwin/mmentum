defmodule MmentumWeb.MCPSetupLive do
  @moduledoc false
  use MmentumWeb, :live_view

  import MmentumWeb.MCPComponents

  alias Mmentum.OAuth
  alias MmentumWeb.MCPClientGuides

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Connect an AI app",
       clients: MCPClientGuides.list(),
       server_url: OAuth.config().audience
     )}
  end

  def handle_params(params, _uri, socket) do
    key = Map.get(params, "client", "cursor")

    case MCPClientGuides.find(key) do
      nil ->
        {:noreply, push_patch(socket, to: ~p"/users/connections/new", replace: true)}

      client ->
        registration =
          Enum.find(Application.fetch_env!(:mmentum, :oauth_clients), &(Map.get(&1, "setup_client") == key))

        {:noreply,
         assign(socket,
           client: client,
           guide: MCPClientGuides.build(client, socket.assigns.server_url, registration)
         )}
    end
  end

  def handle_event("choose_client", %{"client" => key}, socket) do
    if Enum.any?(socket.assigns.clients, &(&1.key == key)) do
      {:noreply, push_patch(socket, to: ~p"/users/connections/new?client=#{key}")}
    else
      {:noreply, socket}
    end
  end
end
