defmodule MmentumWeb.LiveHelpers do
  alias Phoenix.LiveView.Socket

  def get_current_user(%Socket{assigns: %{current_user: user}} = _socket), do: user
end
