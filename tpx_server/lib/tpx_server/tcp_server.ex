defmodule TpxServer.TCPServer do
  def child_spec(opts \\ []) do
    port = Application.get_env(:tpx_server, :tcp_port, 4040)

    ThousandIsland.child_spec(
      Keyword.merge([port: port, handler_module: TpxServer.TCPHandler], opts)
    )
  end
end
