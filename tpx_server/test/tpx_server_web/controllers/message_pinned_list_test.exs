defmodule TpxServerWeb.MessagePinnedListTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r1 = post(conn, "/auth/register", %{username: "pinl1", password: "secret"})
    %{"token" => tok1, "user_id" => u1} = json_response(conn_r1, 200)
    conn1 = put_req_header(conn, "authorization", "Bearer " <> tok1)
    {:ok, conn: conn1, u1: u1}
  end

  test "list pinned messages in group", %{conn: conn} do
    gid = json_response(post(conn, "/groups", %{name: "gp"}), 200)["id"]

    mid1 =
      json_response(
        post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "x"}}),
        200
      )["id"]

    mid2 =
      json_response(
        post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "y"}}),
        200
      )["id"]

    _ = json_response(post(conn, "/messages/" <> mid1 <> "/pin", %{}), 200)
    _ = json_response(post(conn, "/messages/" <> mid2 <> "/pin", %{}), 200)
    body = json_response(get(conn, "/groups/" <> gid <> "/messages/pinned?limit=50"), 200)
    assert length(body["messages"]) == 2
  end

  test "list pinned messages in dm", %{conn: conn} do
    conn2 = Phoenix.ConnTest.build_conn()

    u2 =
      json_response(post(conn2, "/auth/register", %{username: "pinl2", password: "secret"}), 200)[
        "user_id"
      ]

    did = json_response(post(conn, "/dm", %{user_id: u2}), 200)["id"]

    mid =
      json_response(
        post(conn, "/dm/" <> did <> "/send", %{type: "text", content: %{text: "hello"}}),
        200
      )["id"]

    _ = json_response(post(conn, "/messages/" <> mid <> "/pin", %{}), 200)
    body = json_response(get(conn, "/dm/" <> did <> "/messages/pinned?limit=50"), 200)
    assert length(body["messages"]) == 1
  end
end
