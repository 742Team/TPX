defmodule TpxServerWeb.GroupController do
  use TpxServerWeb, :controller
  alias TpxServer.Chat

  def create(conn, %{"name" => _name} = params) do
    owner = conn.assigns.current_user

    case Chat.create_group(
           owner.id,
           Map.take(params, ["name", "description", "photo", "messages_retention"])
         ) do
      {:ok, group} -> json(conn, %{ok: true, id: group.id})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def add(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.can_manage?(group, user.id),
         {:ok, _} <- Chat.add_member(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def kick(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.can_manage?(group, user.id),
         {:ok, _} <- Chat.kick_member(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def ban(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.can_manage?(group, user.id),
         {:ok, _} <- Chat.ban_user(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def unban(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.can_manage?(group, user.id),
         {:ok, _} <- Chat.unban_user(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def promote_admin(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.can_manage?(group, user.id),
         {:ok, _} <- Chat.promote_admin(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def demote_admin(conn, %{"id" => id, "user_id" => user_id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         true <- Chat.owner_only?(group, user.id),
         {:ok, _} <- Chat.demote_admin(group, user_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(403) |> json(%{ok: false})
    end
  end

  def leave(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id),
         {:ok, _} <- Chat.leave_group(group, user.id) do
      json(conn, %{ok: true})
    else
      {:error, :owner_cannot_leave} -> conn |> put_status(403) |> json(%{ok: false})
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end

  def update_settings(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    with group when not is_nil(group) <- Chat.get_group(id) do
      has_ret = Map.has_key?(params, "messages_retention")
      can_edit = Chat.can_manage?(group, user.id)

      cond do
        has_ret and not Chat.owner_only?(group, user.id) ->
          conn |> put_status(403) |> json(%{ok: false})

        not can_edit ->
          conn |> put_status(403) |> json(%{ok: false})

        true ->
          attrs = Map.take(params, ["description", "photo", "messages_retention"])

          case Chat.update_group(group, attrs) do
            {:ok, _} -> json(conn, %{ok: true})
            {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
          end
      end
    else
      _ -> conn |> put_status(404) |> json(%{ok: false})
    end
  end
end
