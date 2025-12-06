defmodule TpxServerWeb.GroupChannelTest do
  use ExUnit.Case, async: true
  use TpxServer.DataCase, async: true
  import Phoenix.ChannelTest
  alias TpxServer.Accounts
  alias TpxServer.Chat

  @endpoint TpxServerWeb.Endpoint

  test "join and broadcast msg" do
    {:ok, user} = Accounts.register_user(%{username: "ch1", password: "secret"})
    {:ok, group} = Chat.create_group(user.id, %{"name" => "gch"})

    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, user.id)

    {:ok, _, socket} =
      subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})

    _ref = push(socket, "msg", %{"text" => "hello"})
    assert_broadcast "msg", %{"text" => "hello", "at" => at}
    assert is_integer(at)
    leave(socket)
  end

  test "typing start and stop" do
    {:ok, user} = Accounts.register_user(%{username: "ch2", password: "secret"})
    {:ok, group} = Chat.create_group(user.id, %{"name" => "gch2"})
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, user.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})
    uid = user.id
    _ = push(socket, "typing", %{"state" => "start"})
    assert_broadcast "typing", %{user_id: ^uid, state: "start"}
    _ = push(socket, "typing", %{"state" => "stop"})
    assert_broadcast "typing", %{user_id: ^uid, state: "stop"}
    leave(socket)
  end

  test "unknown event no reply" do
    {:ok, user} = Accounts.register_user(%{username: "ch3", password: "secret"})
    {:ok, group} = Chat.create_group(user.id, %{"name" => "gch3"})
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, user.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})
    _ = push(socket, "unknown", %{"x" => 1})
    leave(socket)
  end

  test "no broadcast when group deleted after join" do
    {:ok, user} = Accounts.register_user(%{username: "ch4", password: "secret"})
    {:ok, group} = Chat.create_group(user.id, %{"name" => "gch4"})
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, user.id)
    {:ok, _, socket} = subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})
    {:ok, _} = TpxServer.Repo.delete(group)
    _ = push(socket, "msg", %{"text" => "msg"})
    refute_broadcast "msg", %{"text" => "msg"}
    leave(socket)
  end

  test "join unauthorized without user_id" do
    sock = socket(TpxServerWeb.UserSocket, %{})
    assert {:error, %{reason: "unauthorized"}} =
             subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> Ecto.UUID.generate(), %{})
  end

  test "join forbidden when not a member" do
    {:ok, owner} = Accounts.register_user(%{username: "ch_forb_owner", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "ch_forb_other", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "gch_forb"})

    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, other.id)

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})
  end

  test "join forbidden when banned" do
    {:ok, owner} = Accounts.register_user(%{username: "ch_ban_owner", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "ch_ban_other", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "gch_ban"})
    :ok = Chat.add_member(group, other.id) |> elem(0)
    :ok = Chat.ban_user(group, other.id) |> elem(0)

    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, other.id)

    assert {:error, %{reason: "forbidden"}} =
             subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> group.id, %{})
  end

  test "join not_found" do
    {:ok, user} = Accounts.register_user(%{username: "ch_nf", password: "secret"})
    sock = socket(TpxServerWeb.UserSocket, %{})
    sock = Phoenix.Socket.assign(sock, :user_id, user.id)
    bad_id = Ecto.UUID.generate()

    assert {:error, %{reason: "not_found"}} =
             subscribe_and_join(sock, TpxServerWeb.GroupChannel, "group:" <> bad_id, %{})
  end
end
