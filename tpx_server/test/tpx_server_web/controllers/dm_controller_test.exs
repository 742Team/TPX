defmodule TpxServerWeb.DMControllerTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r1 = post(conn, "/auth/register", %{username: "alice1", password: "secret"})
    %{"token" => token1, "user_id" => u1} = json_response(conn_r1, 200)
    conn1 = put_req_header(conn, "authorization", "Bearer " <> token1)

    conn2 = Phoenix.ConnTest.build_conn()
    conn_r2 = post(conn2, "/auth/register", %{username: "bob1", password: "secret"})
    %{"user_id" => u2} = json_response(conn_r2, 200)

    {:ok, conn: conn1, u1: u1, u2: u2}
  end

  test "create dm, send and list", %{conn: conn, u2: u2} do
    conn_c = post(conn, "/dm", %{user_id: u2})
    %{"ok" => true, "id" => dm_id} = json_response(conn_c, 200)

    conn_s = post(conn, "/dm/" <> dm_id <> "/send", %{type: "text", content: %{text: "hello"}})
    assert %{"ok" => true, "id" => _} = json_response(conn_s, 200)

    conn_l = get(conn, "/dm/" <> dm_id <> "/messages")
    body = json_response(conn_l, 200)
    assert body["ok"] == true

    assert Enum.any?(body["messages"], fn m ->
             m["type"] == "text" and m["content"]["text"] == "hello"
           end)
  end

  test "dm send blocked returns 403", %{conn: conn, u2: u2} do
    conn_c = post(conn, "/dm", %{user_id: u2})
    %{"id" => dm_id} = json_response(conn_c, 200)

    # block the other user
    conn_b = post(conn, "/users/block", %{user_id: u2})
    assert %{"ok" => true} = json_response(conn_b, 200)

    conn_s = post(conn, "/dm/" <> dm_id <> "/send", %{type: "text", content: %{text: "x"}})
    assert response(conn_s, 403)
  end

  test "dm send to unknown id returns 404", %{conn: conn} do
    bad_id = Ecto.UUID.generate()
    conn_s = post(conn, "/dm/" <> bad_id <> "/send", %{type: "text", content: %{text: "x"}})
    assert response(conn_s, 404)
  end
end
