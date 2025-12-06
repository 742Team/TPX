defmodule TpxServerWeb.UserSocket do
  use Phoenix.Socket

  channel "group:*", TpxServerWeb.GroupChannel
  channel "dm:*", TpxServerWeb.DMChannel

  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(TpxServerWeb.Endpoint, "user_auth", token, max_age: 7 * 24 * 3600) do
      {:ok, user_id} -> {:ok, Phoenix.Socket.assign(socket, :user_id, user_id)}
      _ -> :error
    end
  end

  def connect(_params, socket, _connect_info), do: {:ok, socket}

  def id(_socket), do: nil
end
