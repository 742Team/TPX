defmodule TpxServer.TCPHandlerTest do
  use ExUnit.Case, async: false

  test "client_hello and ping/pong" do
    port = Application.get_env(:tpx_server, :tcp_port, 4040)
    {:ok, sock} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, {:active, false}])

    hello =
      Msgpax.pack!(%{"type" => "client_hello", "token" => "x", "version" => "1", "seq" => 1})

    :ok = :gen_tcp.send(sock, hello)
    assert {:ok, data} = :gen_tcp.recv(sock, 0, 2000)
    {:ok, resp} = Msgpax.unpack(data)
    assert resp["type"] == "server_hello"
    assert resp["ok"] == true
    assert is_integer(resp["session_id"]) or is_binary(resp["session_id"])
    assert resp["ack"] == 1

    ping = Msgpax.pack!(%{"type" => "ping", "seq" => 2})
    :ok = :gen_tcp.send(sock, ping)
    assert {:ok, data2} = :gen_tcp.recv(sock, 0, 2000)
    {:ok, resp2} = Msgpax.unpack(data2)
    assert resp2["type"] == "pong"
    assert resp2["ack"] == 2

    :gen_tcp.close(sock)
  end
end
