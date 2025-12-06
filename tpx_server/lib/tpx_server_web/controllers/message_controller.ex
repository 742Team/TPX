defmodule TpxServerWeb.MessageController do
  use TpxServerWeb, :controller
  alias TpxServer.Chat

  def send_to_group(conn, %{"group_id" => group_id, "type" => type} = params) do
    user = conn.assigns.current_user
    content = Map.get(params, "content", %{})

    case Chat.get_group(group_id) do
      nil ->
        conn |> put_status(404) |> json(%{ok: false})

      group ->
        case Chat.send_message(user.id, group, %{type: type, content: content}) do
          {:ok, msg} -> json(conn, %{ok: true, id: msg.id})
          {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
          {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
        end
    end
  end

  def list_group(conn, %{"id" => id}) do
    before =
      case conn.params["before"] do
        nil -> nil
        ts -> NaiveDateTime.from_iso8601!(ts)
      end

    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.fetch_messages(id, before, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  def search_group(conn, %{"id" => id, "q" => q}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.search_group_messages(id, q, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  def list_group_pinned(conn, %{"id" => id}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.fetch_pinned_group_messages(id, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  defp serialize(m) do
    %{
      id: m.id,
      sender_id: m.sender_id,
      group_id: m.group_id,
      type: m.type,
      content: m.content,
      inserted_at: m.inserted_at,
      edited_at: m.edited_at,
      deleted: m.deleted,
      pinned: m.pinned,
      pinned_at: m.pinned_at
    }
  end

  def edit(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with %{} = msg <- Chat.get_message(id),
         {:ok, updated} <- Chat.edit_message(user.id, msg, Map.take(params, ["content"])) do
      broadcast_update(updated, "message_edited")
      json(conn, %{ok: true, id: updated.id})
    else
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
      {:error, :deleted} -> conn |> put_status(403) |> json(%{ok: false})
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = msg <- Chat.get_message(id),
         {:ok, _} <- Chat.delete_message(user.id, msg) do
      broadcast_update(msg, "message_deleted")
      json(conn, %{ok: true})
    else
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  def pin(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = msg <- Chat.get_message(id),
         {:ok, _} <- Chat.pin_message(user.id, msg) do
      broadcast_update(msg, "message_pinned")
      json(conn, %{ok: true})
    else
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  def unpin(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %{} = msg <- Chat.get_message(id),
         {:ok, _} <- Chat.unpin_message(user.id, msg) do
      broadcast_update(msg, "message_unpinned")
      json(conn, %{ok: true})
    else
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  defp broadcast_update(msg, event) do
    payload = serialize(msg)

    cond do
      msg.group_id -> TpxServerWeb.Endpoint.broadcast("group:" <> msg.group_id, event, payload)
      msg.dm_id -> TpxServerWeb.Endpoint.broadcast("dm:" <> msg.dm_id, event, payload)
      true -> :ok
    end
  end
end
