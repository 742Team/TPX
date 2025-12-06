defmodule TpxServerWeb.DMController do
  use TpxServerWeb, :controller
  alias TpxServer.Chat

  def create(conn, %{"user_id" => other_id}) do
    me = conn.assigns.current_user

    case Chat.dm_create(me.id, other_id) do
      {:ok, dm} -> json(conn, %{ok: true, id: dm.id})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def send(conn, %{"id" => id, "type" => type} = params) do
    me = conn.assigns.current_user
    content = Map.get(params, "content", %{})

    case Chat.dm_send_message(me.id, id, %{type: type, content: content}) do
      {:ok, msg} -> json(conn, %{ok: true, id: msg.id})
      {:error, :forbidden} -> conn |> put_status(403) |> json(%{ok: false})
      {:error, :blocked} -> conn |> put_status(403) |> json(%{ok: false})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def list(conn, %{"id" => id}) do
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

    msgs = Chat.dm_fetch_messages(id, before, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  def search(conn, %{"id" => id, "q" => q}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.search_dm_messages(id, q, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  def list_pinned(conn, %{"id" => id}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.fetch_pinned_dm_messages(id, limit)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize/1)})
  end

  defp serialize(m) do
    %{
      id: m.id,
      sender_id: m.sender_id,
      dm_id: m.dm_id,
      type: m.type,
      content: m.content,
      inserted_at: m.inserted_at,
      edited_at: m.edited_at,
      deleted: m.deleted,
      pinned: m.pinned,
      pinned_at: m.pinned_at
    }
  end
end
