defmodule TpxServerWeb.Plugs.Auth do
  import Plug.Conn
  alias TpxServer.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <-
           Phoenix.Token.verify(TpxServerWeb.Endpoint, "user_auth", token, max_age: 7 * 24 * 3600),
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      _ -> conn |> send_resp(401, "") |> halt()
    end
  end
end
