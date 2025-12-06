defmodule TpxServerWeb.AdminBlockTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "owner", password: "secret"})
    %{"token" => token, "user_id" => owner_id} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token), owner_id: owner_id}
  end

  test "promote admin and block/unblock user", %{conn: conn, owner_id: owner_id} do
    conn_c = post(conn, "/groups", %{name: "g2"})
    %{"id" => group_id} = json_response(conn_c, 200)

    # create target user
    conn2 = Phoenix.ConnTest.build_conn()
    conn_r2 = post(conn2, "/auth/register", %{username: "user2", password: "secret"})
    %{"user_id" => target_id} = json_response(conn_r2, 200)

    # promote admin
    conn_p = post(conn, "/groups/" <> group_id <> "/admins/promote", %{user_id: target_id})
    assert %{"ok" => true} = json_response(conn_p, 200)

    # block
    conn_b = post(conn, "/users/block", %{user_id: target_id})
    body_b = json_response(conn_b, 200)
    assert body_b["ok"] == true
    assert Enum.member?(body_b["blocked_users"], target_id)

    # unblock
    conn_u = post(conn, "/users/unblock", %{user_id: target_id})
    body_u = json_response(conn_u, 200)
    assert body_u["ok"] == true
    refute Enum.member?(body_u["blocked_users"], target_id)
  end
end
