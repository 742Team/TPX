defmodule TpxServerWeb.GroupLeaveDemoteTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "ownr", password: "secret"})
    %{"token" => token, "user_id" => owner_id} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token), owner_id: owner_id}
  end

  test "demote admin and leave group", %{conn: conn, owner_id: owner_id} do
    conn_c = post(conn, "/groups", %{name: "g3"})
    %{"id" => gid} = json_response(conn_c, 200)

    conn2 = Phoenix.ConnTest.build_conn()
    conn_r2 = post(conn2, "/auth/register", %{username: "adm1", password: "secret"})
    %{"user_id" => admin_id} = json_response(conn_r2, 200)

    _ = post(conn, "/groups/" <> gid <> "/add", %{user_id: admin_id})
    _ = post(conn, "/groups/" <> gid <> "/admins/promote", %{user_id: admin_id})

    conn_d = post(conn, "/groups/" <> gid <> "/admins/demote", %{user_id: admin_id})
    assert %{"ok" => true} = json_response(conn_d, 200)

    # admin leaves
    conn3 =
      put_req_header(
        conn2,
        "authorization",
        json_response(post(conn2, "/auth/login", %{username: "adm1", password: "secret"}), 200)[
          "token"
        ]
        |> then(&("Bearer " <> &1))
      )

    conn_l = post(conn3, "/groups/" <> gid <> "/leave", %{})
    assert %{"ok" => true} = json_response(conn_l, 200)

    # owner cannot leave
    conn_lo = post(conn, "/groups/" <> gid <> "/leave", %{})
    assert response(conn_lo, 403)
  end
end
