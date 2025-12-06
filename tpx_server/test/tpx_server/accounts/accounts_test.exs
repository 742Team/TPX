defmodule TpxServer.AccountsTest do
  use TpxServer.DataCase, async: true
  alias TpxServer.Accounts
  alias TpxServer.Accounts.User

  test "register and authenticate" do
    {:ok, %User{} = user} =
      Accounts.register_user(%{username: "alice", password: "secret", display_name: "Alice"})

    assert user.username == "alice"
    assert is_binary(user.password_hash)

    assert {:ok, auth_user} = Accounts.authenticate("alice", "secret")
    assert auth_user.id == user.id
    assert {:error, :invalid} = Accounts.authenticate("alice", "bad")
    assert {:error, :invalid} = Accounts.authenticate("unknown", "secret")
  end

  test "invalid registration returns changeset errors" do
    {:error, changeset} = Accounts.register_user(%{username: "ab", password: "123"})
    errs = TpxServer.DataCase.errors_on(changeset)
    assert Map.has_key?(errs, :username)
    assert Map.has_key?(errs, :password)
  end
end
