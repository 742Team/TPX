defmodule TpxServerWeb.GroupChannel do
  use Phoenix.Channel
  alias TpxServerWeb.Presence
  alias TpxServer.Chat
  alias TpxServer.Accounts

  def join("group:" <> group_id, _payload, socket) do
    case socket.assigns[:user_id] do
      nil ->
        {:error, %{reason: "unauthorized"}}

      user_id ->
        case Chat.get_group(group_id) do
          nil ->
            {:error, %{reason: "not_found"}}

          group ->
            if user_id in group.members and user_id not in group.banned_users do
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
    "group:" <> group_id = socket.topic

    case Chat.get_group(group_id) do
      nil ->
        {:noreply, socket}

      group ->
        case Chat.send_message(socket.assigns[:user_id], group, %{
               type: "text",
               content: %{"text" => text}
             }) do
          {:ok, msg} ->
            su = Accounts.get_user(socket.assigns[:user_id])
            sender_disp = (su && su.display_name) || nil
            sender_photo = (su && su.photo) || nil
            sender_username = (su && su.username) || nil

            broadcast(
              socket,
              "msg",
              Map.merge(payload, %{
                "at" => System.system_time(:millisecond),
                "id" => msg.id,
                "sender_id" => socket.assigns[:user_id],
                "sender_display_name" => sender_disp,
                "sender_photo" => sender_photo,
                "sender_username" => sender_username
              })
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
