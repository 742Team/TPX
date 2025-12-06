defmodule TpxServerWeb.DMChannel do
  use Phoenix.Channel
  alias TpxServerWeb.Presence
  alias TpxServer.Repo
  alias TpxServer.Chat.DirectMessage

  def join("dm:" <> dm_id, _payload, socket) do
    case socket.assigns[:user_id] do
      nil ->
        {:error, %{reason: "unauthorized"}}

      user_id ->
        case Repo.get(DirectMessage, dm_id) do
          nil ->
            {:error, %{reason: "not_found"}}

          dm ->
            if user_id in [dm.user_a, dm.user_b] do
              send(self(), :after_join)
              {:ok, socket}
            else
              {:error, %{reason: "forbidden"}}
            end
        end
    end
  end

  def handle_info(:after_join, socket) do
    uid = socket.assigns[:user_id] || "anon"
    Presence.track(socket, uid, %{online_at: System.system_time(:second)})
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("msg", %{"text" => text} = payload, socket) when is_binary(text) do
    "dm:" <> dm_id = socket.topic

    case Repo.get(DirectMessage, dm_id) do
      nil ->
        {:noreply, socket}

      dm ->
        case TpxServer.Chat.dm_send_message(socket.assigns[:user_id], dm.id, %{
               type: "text",
               content: %{"text" => text}
             }) do
          {:ok, msg} ->
            broadcast(
              socket,
              "msg",
              Map.merge(payload, %{"at" => System.system_time(:millisecond), "id" => msg.id})
            )

            {:noreply, socket}

          _ ->
            {:noreply, socket}
        end
    end
  end

  def handle_in("typing", %{"state" => state}, socket) when state in ["start", "stop"] do
    broadcast(socket, "typing", %{user_id: socket.assigns[:user_id], state: state})
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:noreply, socket}
end
