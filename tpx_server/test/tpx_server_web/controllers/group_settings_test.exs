defmodule TpxServerWeb.GroupSettingsTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "ownerx", password: "secret"})
    %{"token" => token, "user_id" => owner_id} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token), owner_id: owner_id}
  end

  test "update description/photo and retention owner-only", %{conn: conn, owner_id: owner_id} do
    conn_c = post(conn, "/groups", %{name: "gset"})
    %{"id" => gid} = json_response(conn_c, 200)

    conn_u1 = patch(conn, "/groups/" <> gid, %{description: "desc", photo: "http://x/img.png"})
    assert %{"ok" => true} = json_response(conn_u1, 200)

    conn_u2 = patch(conn, "/groups/" <> gid, %{messages_retention: 1})
    assert %{"ok" => true} = json_response(conn_u2, 200)

    _ = post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "a"}})
    _ = post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "b"}})
    body = json_response(get(conn, "/groups/" <> gid <> "/messages"), 200)
    assert length(body["messages"]) == 1

    conn2 = Phoenix.ConnTest.build_conn()
    conn_r2 = post(conn2, "/auth/register", %{username: "adminx", password: "secret"})
    %{"token" => tok2, "user_id" => u2} = json_response(conn_r2, 200)
    conn2a = put_req_header(conn2, "authorization", "Bearer " <> tok2)
    _ = post(conn, "/groups/" <> gid <> "/add", %{user_id: u2})
    _ = post(conn, "/groups/" <> gid <> "/admins/promote", %{user_id: u2})

    conn_fail = patch(conn2a, "/groups/" <> gid, %{messages_retention: 2})
    assert response(conn_fail, 403)
  end

  test "add and kick member by owner" do
    conn_r = post(build_conn(), "/auth/register", %{username: "own_mgmt", password: "secret"})
    %{"token" => tok} = json_response(conn_r, 200)
    conn = put_req_header(build_conn(), "authorization", "Bearer " <> tok)

    gid = json_response(post(conn, "/groups", %{name: "mgmt"}), 200)["id"]
    conn2 = build_conn()
    u2 = json_response(post(conn2, "/auth/register", %{username: "mem1", password: "secret"}), 200)["user_id"]

    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/add", %{user_id: u2}), 200)
    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/kick", %{user_id: u2}), 200)
  end

  test "ban and unban member by owner" do
    conn_r = post(build_conn(), "/auth/register", %{username: "own_ban", password: "secret"})
    %{"token" => tok} = json_response(conn_r, 200)
    conn = put_req_header(build_conn(), "authorization", "Bearer " <> tok)

    gid = json_response(post(conn, "/groups", %{name: "ban"}), 200)["id"]
    conn2 = build_conn()
    u2 = json_response(post(conn2, "/auth/register", %{username: "mem2", password: "secret"}), 200)["user_id"]

    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/ban", %{user_id: u2}), 200)
    assert %{"ok" => true} = json_response(post(conn, "/groups/" <> gid <> "/unban", %{user_id: u2}), 200)
  end

  test "non-owner cannot manage members" do
    conn_r = post(build_conn(), "/auth/register", %{username: "own_no", password: "secret"})
    %{"token" => tok} = json_response(conn_r, 200)
    conn_owner = put_req_header(build_conn(), "authorization", "Bearer " <> tok)
    gid = json_response(post(conn_owner, "/groups", %{name: "nog"}), 200)["id"]

    conn_u = build_conn()
    %{"token" => tok_u, "user_id" => uid} = json_response(post(conn_u, "/auth/register", %{username: "user_no", password: "secret"}), 200)
    conn_user = put_req_header(conn_u, "authorization", "Bearer " <> tok_u)

    assert response(post(conn_user, "/groups/" <> gid <> "/add", %{user_id: uid}), 403)
    assert response(post(conn_user, "/groups/" <> gid <> "/kick", %{user_id: uid}), 403)
    assert response(post(conn_user, "/groups/" <> gid <> "/ban", %{user_id: uid}), 403)
    assert response(post(conn_user, "/groups/" <> gid <> "/unban", %{user_id: uid}), 403)
  end
end
