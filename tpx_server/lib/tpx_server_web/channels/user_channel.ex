defmodule TpxServerWeb.UserChannel do
  use Phoenix.Channel
  alias TpxServerWeb.Presence

  def join("user:" <> uid, _payload, socket) do
    case socket.assigns[:user_id] do
      nil -> {:error, %{reason: "unauthorized"}}
      user_id ->
        if user_id == uid do
          send(self(), :after_join)
          {:ok, socket}
        else
          {:error, %{reason: "forbidden"}}
        end
    end
  end

  def handle_info(:after_join, socket) do
    uid = socket.assigns[:user_id] || "anon"
    Presence.track(socket, uid, %{online_at: System.system_time(:second)})
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}
end
