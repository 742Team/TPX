defmodule TpxServerWeb.MessagePinTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "own", password: "secret"})
    %{"token" => tok, "user_id" => uid} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> tok), uid: uid}
  end

  test "pin/unpin in group by owner", %{conn: conn} do
    gid = json_response(post(conn, "/groups", %{name: "pg"}), 200)["id"]

    mid =
      json_response(
        post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "x"}}),
        200
      )["id"]

    assert %{"ok" => true} = json_response(post(conn, "/messages/" <> mid <> "/pin", %{}), 200)
    body = json_response(get(conn, "/groups/" <> gid <> "/messages"), 200)
    assert Enum.any?(body["messages"], fn m -> m["id"] == mid and m["pinned"] == true end)
    assert %{"ok" => true} = json_response(post(conn, "/messages/" <> mid <> "/unpin", %{}), 200)
    body2 = json_response(get(conn, "/groups/" <> gid <> "/messages"), 200)
    assert Enum.any?(body2["messages"], fn m -> m["id"] == mid and m["pinned"] == false end)
  end

  test "pin in dm by participant", %{conn: conn} do
    conn2 = Phoenix.ConnTest.build_conn()

    tok2 =
      json_response(post(conn2, "/auth/register", %{username: "user2x", password: "secret"}), 200)[
        "token"
      ]

    u2 =
      json_response(post(conn2, "/auth/register", %{username: "user3x", password: "secret"}), 200)[
        "user_id"
      ]

    conn2a = put_req_header(conn2, "authorization", "Bearer " <> tok2)
    did = json_response(post(conn, "/dm", %{user_id: u2}), 200)["id"]

    mid =
      json_response(
        post(conn, "/dm/" <> did <> "/send", %{type: "text", content: %{text: "hello"}}),
        200
      )["id"]

    assert %{"ok" => true} = json_response(post(conn, "/messages/" <> mid <> "/pin", %{}), 200)
    body = json_response(get(conn, "/dm/" <> did <> "/messages"), 200)
    assert Enum.any?(body["messages"], fn m -> m["id"] == mid and m["pinned"] == true end)
  end

  test "non-owner cannot pin/unpin in group", %{conn: conn} do
    gid = json_response(post(conn, "/groups", %{name: "pg2"}), 200)["id"]
    mid = json_response(post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "x"}}), 200)["id"]

    conn2 = Phoenix.ConnTest.build_conn()
    %{"token" => tok2} = json_response(post(conn2, "/auth/register", %{username: "usrp", password: "secret"}), 200)
    conn2a = put_req_header(conn2, "authorization", "Bearer " <> tok2)

    assert response(post(conn2a, "/messages/" <> mid <> "/pin", %{}), 403)
    assert response(post(conn2a, "/messages/" <> mid <> "/unpin", %{}), 403)
  end
end
