defmodule TpxServer.Repo do
  use Ecto.Repo,
    otp_app: :tpx_server,
    adapter: Ecto.Adapters.Postgres
end
