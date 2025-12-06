defmodule TpxServerWeb.GroupMessageTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "greg", password: "secret"})
    %{"token" => token, "user_id" => user_id} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token), user_id: user_id}
  end

  test "create group, add member, send and list messages", %{conn: conn, user_id: user_id} do
    conn_c = post(conn, "/groups", %{name: "g1", messages_retention: 2})
    %{"ok" => true, "id" => group_id} = json_response(conn_c, 200)

    # create second user
    conn2 = Phoenix.ConnTest.build_conn()
    conn_r2 = post(conn2, "/auth/register", %{username: "sam", password: "secret"})
    %{"user_id" => user2_id} = json_response(conn_r2, 200)

    # add member
    conn_a = post(conn, "/groups/" <> group_id <> "/add", %{user_id: user2_id})
    assert %{"ok" => true} = json_response(conn_a, 200)

    # send message by owner
    conn_m =
      post(conn, "/messages/send", %{group_id: group_id, type: "text", content: %{text: "hi"}})

    assert %{"ok" => true, "id" => _} = json_response(conn_m, 200)

    # list messages
    conn_l = get(conn, "/groups/" <> group_id <> "/messages")
    body = json_response(conn_l, 200)
    assert body["ok"] == true
    assert length(body["messages"]) >= 1

    assert Enum.any?(body["messages"], fn m ->
             m["type"] == "text" and m["content"]["text"] == "hi"
           end)

    # edit message by owner
    first = hd(body["messages"])
    conn_e = patch(conn, "/messages/" <> first["id"], %{content: %{text: "hi2"}})
    assert %{"ok" => true} = json_response(conn_e, 200)
    conn_l2 = get(conn, "/groups/" <> group_id <> "/messages")
    body2 = json_response(conn_l2, 200)

    assert Enum.any?(body2["messages"], fn m ->
             m["id"] == first["id"] and m["content"]["text"] == "hi2" and
               not is_nil(m["edited_at"])
           end)

    # delete message by owner
    conn_d = delete(conn, "/messages/" <> first["id"])
    assert %{"ok" => true} = json_response(conn_d, 200)
    conn_l3 = get(conn, "/groups/" <> group_id <> "/messages")
    # retention after extra messages
    _ = post(conn, "/messages/send", %{group_id: group_id, type: "text", content: %{text: "hi3"}})
    _ = post(conn, "/messages/send", %{group_id: group_id, type: "text", content: %{text: "hi4"}})
    conn_l_ret = get(conn, "/groups/" <> group_id <> "/messages?limit=50")
    body_ret = json_response(conn_l_ret, 200)
    assert length(body_ret["messages"]) == 2
    body3 = json_response(conn_l3, 200)

    assert Enum.any?(body3["messages"], fn m ->
             m["id"] == first["id"] and m["deleted"] == true
           end)
  end

  test "non-owner cannot edit or delete message", %{conn: conn} do
    gid = json_response(post(conn, "/groups", %{name: "g2"}), 200)["id"]
    mid = json_response(post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "t"}}), 200)["id"]

    conn2 = Phoenix.ConnTest.build_conn()
    %{"token" => tok2} = json_response(post(conn2, "/auth/register", %{username: "otherx", password: "secret"}), 200)
    conn2a = put_req_header(conn2, "authorization", "Bearer " <> tok2)

    assert response(patch(conn2a, "/messages/" <> mid, %{content: %{text: "e"}}), 403)
    assert response(delete(conn2a, "/messages/" <> mid), 403)
  end

  test "admin can edit and delete message", %{conn: conn} do
    %{"id" => gid} = json_response(post(conn, "/groups", %{name: "ga"}), 200)
    %{"user_id" => u2} = json_response(post(build_conn(), "/auth/register", %{username: "adm1", password: "secret"}), 200)
    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/add", %{user_id: u2}), 200)
    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/admins/promote", %{user_id: u2}), 200)
    %{"id" => mid} = json_response(post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "t"}}), 200)

    conn2 = put_req_header(build_conn(), "authorization", "Bearer " <> json_response(post(build_conn(), "/auth/login", %{username: "adm1", password: "secret"}), 200)["token"])
    assert %{"ok" => true} = json_response(patch(conn2, "/messages/" <> mid, %{content: %{text: "e"}}), 200)
    assert %{"ok" => true} = json_response(delete(conn2, "/messages/" <> mid), 200)
  end

  test "invalid message type returns 422", %{conn: conn} do
    %{"id" => gid} = json_response(post(conn, "/groups", %{name: "gtype"}), 200)
    conn_m = post(conn, "/messages/send", %{group_id: gid, type: "bad", content: %{text: "x"}})
    assert response(conn_m, 422)
  end

  test "send to unknown group returns 404", %{conn: conn} do
    bad_gid = Ecto.UUID.generate()
    conn_m = post(conn, "/messages/send", %{group_id: bad_gid, type: "text", content: %{text: "x"}})
    assert response(conn_m, 404)
  end

  test "send forbidden when not a member", %{conn: conn} do
    gid = json_response(post(conn, "/groups", %{name: "g_forb_send"}), 200)["id"]
    conn2 = Phoenix.ConnTest.build_conn()
    %{"token" => tok2} = json_response(post(conn2, "/auth/register", %{username: "mem_forb", password: "secret"}), 200)
    conn2a = put_req_header(conn2, "authorization", "Bearer " <> tok2)
    conn_m = post(conn2a, "/messages/send", %{group_id: gid, type: "text", content: %{text: "x"}})
    assert response(conn_m, 403)
  end
end
