defmodule TpxServerWeb.DMController do
  use TpxServerWeb, :controller
  alias TpxServer.Chat
  alias TpxServer.Accounts
  import Ecto.Query

  def create(conn, %{"user_id" => other_id}) do
    me = conn.assigns.current_user

    case Chat.dm_create(me.id, other_id) do
      {:ok, dm} ->
        payload = build_dm_payload(dm, me.id)
        TpxServerWeb.Endpoint.broadcast("user:" <> me.id, "dm_created", payload)
        TpxServerWeb.Endpoint.broadcast("user:" <> other_id, "dm_created", build_dm_payload(dm, other_id))
        json(conn, %{ok: true, id: dm.id})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def create(conn, %{"username" => uname}) do
    me = conn.assigns.current_user
    uname = String.trim_leading(uname, "@")

    case TpxServer.Accounts.get_user_by_username(uname) do
      nil -> conn |> put_status(404) |> json(%{ok: false})
      other ->
        case Chat.dm_create(me.id, other.id) do
          {:ok, dm} ->
            payload = build_dm_payload(dm, me.id)
            TpxServerWeb.Endpoint.broadcast("user:" <> me.id, "dm_created", payload)
            TpxServerWeb.Endpoint.broadcast("user:" <> other.id, "dm_created", build_dm_payload(dm, other.id))
            json(conn, %{ok: true, id: dm.id})
          {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
        end
    end
  end

  def send(conn, %{"id" => id, "type" => type} = params) do
    me = conn.assigns.current_user
    content = Map.get(params, "content", %{})

    case Chat.dm_send_message(me.id, id, %{type: type, content: content}) do
      {:ok, msg} ->
        TpxServerWeb.Endpoint.broadcast(
          "dm:" <> id,
          "message_created",
          serialize_enriched(msg, dm_users_map(id))
        )
        text = Map.get(content, "text")
        if type == "text" and is_binary(text) do
          u = Accounts.get_user(me.id)
          TpxServerWeb.Endpoint.broadcast(
            "dm:" <> id,
            "msg",
            %{
              "text" => text,
              "id" => msg.id,
              "inserted_at" => msg.inserted_at,
              "sender_id" => me.id,
              "sender_display_name" => (u && u.display_name) || nil,
              "sender_photo" => (u && u.photo) || nil,
              "sender_username" => (u && u.username) || nil
            }
          )
          dm = TpxServer.Repo.get(TpxServer.Chat.DirectMessage, id)
          if dm do
            other_id = if me.id == dm.user_a, do: dm.user_b, else: dm.user_a
            TpxServerWeb.Endpoint.broadcast("user:" <> other_id, "dm_notify", %{"id" => id})
          end
        end
        json(conn, %{ok: true, id: msg.id})
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
    users = dm_users_map(id)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize_enriched(&1, users))})
  end

  def search(conn, %{"id" => id, "q" => q}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.search_dm_messages(id, q, limit)
    users = dm_users_map(id)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize_enriched(&1, users))})
  end

  def list_pinned(conn, %{"id" => id}) do
    limit =
      case Integer.parse(Map.get(conn.params, "limit", "50")) do
        {n, _} when n > 0 and n <= 200 -> n
        _ -> 50
      end

    msgs = Chat.fetch_pinned_dm_messages(id, limit)
    users = dm_users_map(id)
    json(conn, %{ok: true, messages: Enum.map(msgs, &serialize_enriched(&1, users))})
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
  defp serialize_enriched(m, users) do
    u = Map.get(users, m.sender_id)
    Map.merge(serialize(m), %{
      sender_username: (u && u.username) || nil,
      sender_display_name: (u && u.display_name) || nil,
      sender_photo: (u && u.photo) || nil
    })
  end
  defp dm_users_map(dm_id) do
    case TpxServer.Repo.get(TpxServer.Chat.DirectMessage, dm_id) do
      nil -> %{}
      dm ->
        ids = [dm.user_a, dm.user_b]
        Enum.reduce(ids, %{}, fn uid, acc ->
          case TpxServer.Accounts.get_user(uid) do
            nil -> acc
            u -> Map.put(acc, uid, u)
          end
        end)
    end
  end
  defp build_dm_payload(dm, viewer_id) do
    other_id = if dm.user_a == viewer_id, do: dm.user_b, else: dm.user_a
    other = TpxServer.Accounts.get_user(other_id)
    %{
      id: dm.id,
      other_id: other_id,
      other_username: other && other.username,
      other_display_name: other && other.display_name,
      other_photo: other && other.photo
    }
  end
  def list_mine(conn, _params) do
    me = conn.assigns.current_user
    dms =
      TpxServer.Repo.all(
        from(d in TpxServer.Chat.DirectMessage,
          where: d.user_a == ^me.id or d.user_b == ^me.id,
          order_by: [desc: d.last_message_at]
        )
      )

    payload =
      Enum.map(dms, fn dm ->
        other_id = if dm.user_a == me.id, do: dm.user_b, else: dm.user_a
        other = TpxServer.Accounts.get_user(other_id)
        %{
          id: dm.id,
          other_id: other_id,
          other_username: other && other.username,
          other_display_name: other && other.display_name,
          other_photo: other && other.photo
        }
      end)

    json(conn, %{ok: true, dms: payload})
  end
end
