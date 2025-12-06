defmodule TpxServerWeb.AuthControllerTest do
  use TpxServerWeb.ConnCase, async: true

  test "register returns token", %{conn: conn} do
    conn =
      post(conn, "/auth/register", %{username: "bob", password: "secret", display_name: "Bob"})

    assert %{"ok" => true, "token" => token, "user_id" => user_id} = json_response(conn, 200)
    assert is_binary(token)
    assert is_binary(user_id)
  end

  test "login returns token", %{conn: conn} do
    _ = post(conn, "/auth/register", %{username: "carol", password: "secret"})
    conn = post(conn, "/auth/login", %{username: "carol", password: "secret"})
    assert %{"ok" => true, "token" => token} = json_response(conn, 200)
    assert is_binary(token)
  end

  test "login bad password returns 401", %{conn: conn} do
    _ = post(conn, "/auth/register", %{username: "carol2", password: "secret"})
    conn = post(conn, "/auth/login", %{username: "carol2", password: "bad"})
    assert response(conn, 401)
  end

  test "register invalid returns 422", %{conn: conn} do
    conn = post(conn, "/auth/register", %{username: "ab", password: "123"})
    assert response(conn, 422)
  end
end
