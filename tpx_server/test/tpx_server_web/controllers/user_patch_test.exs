defmodule TpxServerWeb.UserPatchTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r =
      post(conn, "/auth/register", %{username: "eve", password: "secret", display_name: "Eve"})

    %{"token" => token} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token)}
  end

  test "patch photo", %{conn: conn} do
    conn = patch(conn, "/users/me/photo", %{url: "https://cdn/x.png"})
    body = json_response(conn, 200)
    assert body["ok"] == true
    assert body["photo"] == "https://cdn/x.png"
  end

  test "patch background", %{conn: conn} do
    conn = patch(conn, "/users/me/background", %{value: "#fff"})
    body = json_response(conn, 200)
    assert body["ok"] == true
    assert body["background"] == "#fff"
  end

  test "patch status", %{conn: conn} do
    conn = patch(conn, "/users/me/status", %{status: "online"})
    body = json_response(conn, 200)
    assert body["ok"] == true
    assert body["status"] == "online"
  end

  test "patch status invalid returns 422", %{conn: conn} do
    conn = patch(conn, "/users/me/status", %{status: "bad"})
    assert response(conn, 422)
  end

  test "patch display_name", %{conn: conn} do
    conn = patch(conn, "/users/me/display_name", %{display_name: "Eve N."})
    body = json_response(conn, 200)
    assert body["ok"] == true
    assert body["display_name"] == "Eve N."
  end
end
