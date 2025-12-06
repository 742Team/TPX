defmodule TpxServerWeb.MessageSearchTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r1 = post(conn, "/auth/register", %{username: "se1", password: "secret"})
    %{"token" => tok1, "user_id" => u1} = json_response(conn_r1, 200)
    conn1 = put_req_header(conn, "authorization", "Bearer " <> tok1)

    conn_r2 = post(conn, "/auth/register", %{username: "se2", password: "secret"})
    %{"user_id" => u2} = json_response(conn_r2, 200)

    {:ok, conn: conn1, u1: u1, u2: u2}
  end

  test "search in group and dm", %{conn: conn, u2: u2} do
    conn_g = post(conn, "/groups", %{name: "sg"})
    %{"id" => gid} = json_response(conn_g, 200)
    _ = post(conn, "/groups/" <> gid <> "/add", %{user_id: u2})

    _ = post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "alpha"}})
    _ = post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "beta"}})
    _ = post(conn, "/messages/send", %{group_id: gid, type: "text", content: %{text: "alphabet"}})

    body_g =
      json_response(get(conn, "/groups/" <> gid <> "/messages/search?q=alpha&limit=50"), 200)

    assert Enum.all?(body_g["messages"], fn m ->
             String.contains?(m["content"]["text"], "alpha")
           end)

    conn_c = post(conn, "/dm", %{user_id: u2})
    %{"id" => did} = json_response(conn_c, 200)
    _ = post(conn, "/dm/" <> did <> "/send", %{type: "text", content: %{text: "hello world"}})
    _ = post(conn, "/dm/" <> did <> "/send", %{type: "text", content: %{text: "world"}})
    body_d = json_response(get(conn, "/dm/" <> did <> "/messages/search?q=world&limit=50"), 200)
    assert length(body_d["messages"]) == 2
  end
end
