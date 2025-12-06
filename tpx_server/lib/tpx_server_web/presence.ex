defmodule TpxServerWeb.Presence do
  use Phoenix.Presence,
    otp_app: :tpx_server,
    pubsub_server: TpxServer.PubSub
end
