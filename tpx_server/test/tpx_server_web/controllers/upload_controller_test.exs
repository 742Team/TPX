defmodule TpxServerWeb.UploadControllerTest do
  use TpxServerWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn_r = post(conn, "/auth/register", %{username: "zoe", password: "secret"})
    %{"token" => token} = json_response(conn_r, 200)
    {:ok, conn: put_req_header(conn, "authorization", "Bearer " <> token)}
  end

  test "upload saves file and returns metadata", %{conn: conn} do
    tmp = Path.join(System.tmp_dir!(), "test_upload.png")
    File.write!(tmp, <<0, 1, 2, 3>>)
    upload = %Plug.Upload{filename: "test.png", path: tmp}
    conn = post(conn, "/upload", %{file: upload})
    body = json_response(conn, 200)
    assert body["ok"] == true
    assert String.contains?(body["url"], "test.png")
    assert is_integer(body["size"]) and body["size"] > 0
  end
end
