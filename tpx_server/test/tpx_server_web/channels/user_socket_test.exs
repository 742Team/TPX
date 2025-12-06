defmodule TpxServerWeb.UserSocketTest do
  use ExUnit.Case, async: true
  use TpxServer.DataCase, async: true
  alias TpxServer.Accounts

  test "connect with valid token assigns user_id" do
    {:ok, user} = Accounts.register_user(%{username: "sock_u", password: "secret"})
    token = Phoenix.Token.sign(TpxServerWeb.Endpoint, "user_auth", user.id)
    {:ok, socket} = TpxServerWeb.UserSocket.connect(%{"token" => token}, %Phoenix.Socket{}, %{})
    assert socket.assigns[:user_id] == user.id
  end

  test "connect without token returns ok with no user_id" do
    {:ok, socket} = TpxServerWeb.UserSocket.connect(%{}, %Phoenix.Socket{}, %{})
    assert is_nil(socket.assigns[:user_id])
  end

  test "connect with invalid token returns error" do
    assert :error = TpxServerWeb.UserSocket.connect(%{"token" => "bad"}, %Phoenix.Socket{}, %{})
  end
end
