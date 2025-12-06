defmodule TpxServerWeb.UserControllerTest do
  use TpxServerWeb.ConnCase, async: true

  test "users/me returns profile when authorized", %{conn: conn} do
    conn_r =
      post(conn, "/auth/register", %{
        username: "dave",
        password: "secret",
        display_name: "Dave",
        background: "#000"
      })

    %{"token" => token, "user_id" => user_id} = json_response(conn_r, 200)
    conn = conn |> put_req_header("authorization", "Bearer " <> token)
    conn = get(conn, "/users/me")
    body = json_response(conn, 200)
    assert body["id"] == user_id
    assert body["username"] == "dave"
    assert body["background"] == "#000"
  end

  test "users/me unauthorized without token", %{conn: conn} do
    conn = get(conn, "/users/me")
    assert response(conn, 401)
  end
end
