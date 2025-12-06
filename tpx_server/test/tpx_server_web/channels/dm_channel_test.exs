defmodule TpxServerWeb.DMChannelTest do
  use ExUnit.Case, async: true
  use TpxServer.DataCase, async: true
  import Phoenix.ChannelTest
  alias TpxServer.Accounts
  alias TpxServer.Chat
  @endpoint TpxServerWeb.Endpoint

  test "join and broadcast msg" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_u1", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_u2", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)

    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)

    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})

    _ref = push(socket, "msg", %{"text" => "hello"})
    assert_broadcast "msg", %{"text" => "hello", "at" => at}
    assert is_integer(at)
    leave(socket)
  end

  test "typing start and stop" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_t1", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_t2", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})
    uid = u1.id
    _ = push(socket, "typing", %{"state" => "start"})
    assert_broadcast "typing", %{user_id: ^uid, state: "start"}
    _ = push(socket, "typing", %{"state" => "stop"})
    assert_broadcast "typing", %{user_id: ^uid, state: "stop"}
    leave(socket)
  end

  test "unknown event no reply" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_u3", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_u4", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})
    _ = push(socket, "unknown", %{"x" => 1})
    leave(socket)
  end

  test "blocked after join does not broadcast msg" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_b1", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_b2", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})
    {:ok, _} = TpxServer.Accounts.block_user(u1, u2.id)
    _ = push(socket, "msg", %{"text" => "blocked"})
    refute_broadcast "msg", %{"text" => "blocked"}
    leave(socket)
  end

  test "no broadcast when dm deleted after join" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_del1", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_del2", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})
    {:ok, _} = TpxServer.Repo.delete(dm)
    _ = push(socket, "msg", %{"text" => "msg"})
    refute_broadcast "msg", %{"text" => "msg"}
    leave(socket)
  end

  test "join forbidden when not participant" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_forb_u1", password: "secret"})
    {:ok, u2} = Accounts.register_user(%{username: "dm_forb_u2", password: "secret"})
    {:ok, u3} = Accounts.register_user(%{username: "dm_forb_u3", password: "secret"})
    {:ok, dm} = Chat.dm_create(u1.id, u2.id)

    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u3.id)

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> dm.id, %{})
  end

  test "join not_found" do
    {:ok, u1} = Accounts.register_user(%{username: "dm_nf_u1", password: "secret"})
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, u1.id)
    bad_id = Ecto.UUID.generate()

    assert {:error, %{reason: "not_found"}} =
             subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> bad_id, %{})
  end

  test "join unauthorized without user_id" do
    sock = socket(TpxServerWeb.UserSocket, %{})
    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(sock, TpxServerWeb.DMChannel, "dm:" <> Ecto.UUID.generate(), %{})
  end
end
