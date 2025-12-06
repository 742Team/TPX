defmodule TpxServerWeb.AuthController do
  use TpxServerWeb, :controller
  alias TpxServer.Accounts

  def register(conn, params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        token = Phoenix.Token.sign(TpxServerWeb.Endpoint, "user_auth", user.id)
        json(conn, %{ok: true, token: token, user_id: user.id})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{ok: false, errors: changeset_errors(changeset)})
    end
  end

  def login(conn, %{"username" => u, "password" => p}) do
    case Accounts.authenticate(u, p) do
      {:ok, user} ->
        token = Phoenix.Token.sign(TpxServerWeb.Endpoint, "user_auth", user.id)
        json(conn, %{ok: true, token: token, user_id: user.id})

      {:error, _} ->
        conn |> put_status(401) |> json(%{ok: false})
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
