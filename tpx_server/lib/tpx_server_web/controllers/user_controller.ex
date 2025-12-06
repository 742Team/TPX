defmodule TpxServerWeb.UserController do
  use TpxServerWeb, :controller
  alias TpxServer.Accounts

  def me(conn, _params) do
    user = conn.assigns.current_user

    json(conn, %{
      id: user.id,
      username: user.username,
      display_name: user.display_name,
      photo: user.photo,
      background: user.background,
      status: user.status,
      public_key: user.public_key,
      blocked_users: user.blocked_users
    })
  end

  def set_photo(conn, %{"url" => url}) do
    user = conn.assigns.current_user

    case Accounts.update_photo(user, url) do
      {:ok, user} -> json(conn, %{ok: true, photo: user.photo})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def set_background(conn, %{"value" => value}) do
    user = conn.assigns.current_user

    case Accounts.update_background(user, value) do
      {:ok, user} -> json(conn, %{ok: true, background: user.background})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def set_status(conn, %{"status" => status}) do
    user = conn.assigns.current_user

    case Accounts.update_status(user, status) do
      {:ok, user} -> json(conn, %{ok: true, status: user.status})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def set_display_name(conn, %{"display_name" => value}) do
    user = conn.assigns.current_user

    case Accounts.update_profile(user, %{display_name: value}) do
      {:ok, user} -> json(conn, %{ok: true, display_name: user.display_name})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def block(conn, %{"user_id" => target_id}) do
    user = conn.assigns.current_user

    case Accounts.block_user(user, target_id) do
      {:ok, user} -> json(conn, %{ok: true, blocked_users: user.blocked_users})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end

  def unblock(conn, %{"user_id" => target_id}) do
    user = conn.assigns.current_user

    case Accounts.unblock_user(user, target_id) do
      {:ok, user} -> json(conn, %{ok: true, blocked_users: user.blocked_users})
      {:error, _} -> conn |> put_status(422) |> json(%{ok: false})
    end
  end
end
