defmodule TpxServer.ChatTest do
  use ExUnit.Case, async: true
  use TpxServer.DataCase, async: true
  alias TpxServer.Chat
  alias TpxServer.Accounts

  test "group management and permissions" do
    {:ok, owner} = Accounts.register_user(%{username: "grp_owner", password: "secret"})
    {:ok, user} = Accounts.register_user(%{username: "grp_user", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "g"})

    assert Chat.can_manage?(group, owner.id)
    refute Chat.can_manage?(group, user.id)

    {:ok, group1} = Chat.add_member(group, user.id)
    assert Enum.member?(group1.members, user.id)

    {:ok, group2} = Chat.kick_member(group1, user.id)
    refute Enum.member?(group2.members, user.id)

    {:ok, group3} = Chat.ban_user(group2, user.id)
    assert Enum.member?(group3.banned_users, user.id)

    {:ok, group4} = Chat.unban_user(group3, user.id)
    refute Enum.member?(group4.banned_users, user.id)
  end

  test "send_message forbidden for non-member and banned" do
    {:ok, owner} = Accounts.register_user(%{username: "sm_owner", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "sm_other", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "g2"})

    assert {:error, :forbidden} = Chat.send_message(other.id, group, %{type: "text", content: %{"text" => "x"}})

    {:ok, group1} = Chat.add_member(group, other.id)
    {:ok, _msg} = Chat.send_message(other.id, group1, %{type: "text", content: %{"text" => "y"}})

    {:ok, group2} = Chat.ban_user(group1, other.id)
    assert {:error, :forbidden} = Chat.send_message(other.id, group2, %{type: "text", content: %{"text" => "z"}})
  end

  test "dm_send_message blocked" do
    {:ok, a} = Accounts.register_user(%{username: "dm_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "dm_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)

    {:ok, _m1} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "hi"}})
    {:ok, _} = Accounts.block_user(a, b.id)
    assert {:error, :blocked} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "x"}})
  end

  test "edit and delete message permissions" do
    {:ok, owner} = Accounts.register_user(%{username: "ed_owner", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "ed_other", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "g3"})
    {:ok, msg} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "a"}})

    {:ok, _} = Chat.edit_message(owner.id, msg, %{content: %{"text" => "b"}})
    assert {:error, :forbidden} = Chat.edit_message(other.id, msg, %{content: %{"text" => "c"}})

    {:ok, _} = Chat.delete_message(owner.id, msg)
    assert {:error, :forbidden} = Chat.delete_message(other.id, msg)
  end

  test "pin and unpin in dm permissions" do
    {:ok, a} = Accounts.register_user(%{username: "pin_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "pin_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, msg} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "p"}})

    {:ok, _} = Chat.pin_message(a.id, msg)
    {:ok, _} = Chat.unpin_message(a.id, msg)
    assert {:error, :forbidden} = Chat.pin_message(Ecto.UUID.generate(), msg)
  end

  test "dm pin/unpin forbidden for non-participant" do
    {:ok, a} = Accounts.register_user(%{username: "pin_forb_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "pin_forb_b", password: "secret"})
    {:ok, c} = Accounts.register_user(%{username: "pin_forb_c", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, msg} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "p"}})
    assert {:error, :forbidden} = Chat.pin_message(c.id, msg)
    assert {:error, :forbidden} = Chat.unpin_message(c.id, msg)
  end

  test "group pin/unpin forbidden for non-manager" do
    {:ok, owner} = Accounts.register_user(%{username: "pin_g_owner", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "pin_g_other", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "pg_forb"})
    {:ok, msg} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "x"}})
    assert {:error, :forbidden} = Chat.pin_message(other.id, msg)
    assert {:error, :forbidden} = Chat.unpin_message(other.id, msg)
  end

  test "messages retention prunes older messages" do
    {:ok, owner} = Accounts.register_user(%{username: "ret_owner", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "ret", "messages_retention" => 2})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "a"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "b"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "c"}})
    msgs = Chat.fetch_messages(group.id, nil, 50)
    assert length(msgs) == 2
  end

  test "edit_message returns :deleted for deleted msg" do
    {:ok, owner} = Accounts.register_user(%{username: "ed_del", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "ed_del_g"})
    {:ok, msg} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "x"}})
    {:ok, msg2} = Chat.delete_message(owner.id, msg)
    assert {:error, :deleted} = Chat.edit_message(owner.id, msg2, %{content: %{"text" => "y"}})
  end

  test "edit dm message by sender only" do
    {:ok, a} = Accounts.register_user(%{username: "ed_dm_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "ed_dm_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, msg} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "hi"}})
    assert {:ok, _} = Chat.edit_message(a.id, msg, %{content: %{"text" => "yo"}})
    assert {:error, :forbidden} = Chat.edit_message(b.id, msg, %{content: %{"text" => "no"}})
  end

  test "fetch_messages before_ts and dm_fetch_messages before_ts" do
    {:ok, owner} = Accounts.register_user(%{username: "bf_owner", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "bf"})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "a"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "b"}})
    {:ok, last} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "c"}})
    older = Chat.fetch_messages(group.id, last.inserted_at, 50)
    assert Enum.all?(older, fn m -> NaiveDateTime.compare(m.inserted_at, last.inserted_at) == :lt end)

    {:ok, a} = Accounts.register_user(%{username: "bf_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "bf_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, _} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "1"}})
    {:ok, _} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "2"}})
    {:ok, last_dm} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "3"}})
    older_dm = Chat.dm_fetch_messages(dm.id, last_dm.inserted_at, 50)
    assert Enum.all?(older_dm, fn m -> NaiveDateTime.compare(m.inserted_at, last_dm.inserted_at) == :lt end)
  end

  test "dm_send_message not_found" do
    assert {:error, :not_found} = Chat.dm_send_message(Ecto.UUID.generate(), Ecto.UUID.generate(), %{type: "text", content: %{"text" => "x"}})
  end

  test "retention nil and zero do not prune" do
    {:ok, owner} = Accounts.register_user(%{username: "ret_nz", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "rnz"})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "a"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "b"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "c"}})
    assert length(Chat.fetch_messages(group.id, nil, 50)) == 3

    {:ok, group2} = Chat.update_group(group, %{"messages_retention" => 0})
    {:ok, _} = Chat.send_message(owner.id, group2, %{type: "text", content: %{"text" => "d"}})
    assert length(Chat.fetch_messages(group2.id, nil, 50)) >= 3
  end

  test "delete dm message by sender only" do
    {:ok, a} = Accounts.register_user(%{username: "del_dm_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "del_dm_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, msg} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "hi"}})
    assert {:error, :forbidden} = Chat.delete_message(b.id, msg)
    assert {:ok, _} = Chat.delete_message(a.id, msg)
  end

  test "dm_send_message forbidden for non-participant" do
    {:ok, a} = Accounts.register_user(%{username: "dm_np_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "dm_np_b", password: "secret"})
    {:ok, c} = Accounts.register_user(%{username: "dm_np_c", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    assert {:error, :forbidden} = Chat.dm_send_message(c.id, dm.id, %{type: "text", content: %{"text" => "x"}})
  end

  test "dm_send_message blocked when other blocks sender" do
    {:ok, a} = Accounts.register_user(%{username: "dm_bl_a", password: "secret"})
    {:ok, b} = Accounts.register_user(%{username: "dm_bl_b", password: "secret"})
    {:ok, dm} = Chat.dm_create(a.id, b.id)
    {:ok, _} = Accounts.block_user(b, a.id)
    assert {:error, :blocked} = Chat.dm_send_message(a.id, dm.id, %{type: "text", content: %{"text" => "x"}})
  end

  test "member leaves group and loses permissions" do
    {:ok, owner} = Accounts.register_user(%{username: "lv_owner2", password: "secret"})
    {:ok, user} = Accounts.register_user(%{username: "lv_user2", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "lv2"})
    {:ok, group} = Chat.add_member(group, user.id)
    assert Enum.member?(group.members, user.id)
    {:ok, group2} = Chat.leave_group(group, user.id)
    refute Enum.member?(group2.members, user.id)
    refute Chat.can_manage?(group2, user.id)
  end

  test "promote and demote admin toggles can_manage?" do
    {:ok, owner} = Accounts.register_user(%{username: "adm_owner", password: "secret"})
    {:ok, user} = Accounts.register_user(%{username: "adm_user", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "adm"})
    {:ok, group} = Chat.add_member(group, user.id)
    refute Chat.can_manage?(group, user.id)
    {:ok, group} = Chat.promote_admin(group, user.id)
    assert Chat.can_manage?(group, user.id)
    {:ok, group} = Chat.demote_admin(group, user.id)
    refute Chat.can_manage?(group, user.id)
  end

  test "get_group and fetch_pinned_group_messages empty" do
    assert Chat.get_group(Ecto.UUID.generate()) == nil
    {:ok, owner} = Accounts.register_user(%{username: "pin_empty", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "pempty"})
    assert Chat.fetch_pinned_group_messages(group.id, 50) == []
  end

  test "search functions for group and dm" do
    {:ok, owner} = Accounts.register_user(%{username: "se_own", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "se_o", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "sg"})
    {:ok, _} = Chat.add_member(group, other.id)
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "alpha"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "beta"}})
    {:ok, _} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "alphabet"}})
    res_g = Chat.search_group_messages(group.id, "alpha", 50)
    assert Enum.count(res_g) >= 2

    {:ok, dm} = Chat.dm_create(owner.id, other.id)
    {:ok, _} = Chat.dm_send_message(owner.id, dm.id, %{type: "text", content: %{"text" => "hello world"}})
    {:ok, _} = Chat.dm_send_message(owner.id, dm.id, %{type: "text", content: %{"text" => "world"}})
    res_d = Chat.search_dm_messages(dm.id, "world", 50)
    assert length(res_d) == 2
  end

  test "fetch pinned lists for group and dm" do
    {:ok, owner} = Accounts.register_user(%{username: "pin_g", password: "secret"})
    {:ok, other} = Accounts.register_user(%{username: "pin_d", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "pg"})
    {:ok, m1} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "x"}})
    {:ok, m2} = Chat.send_message(owner.id, group, %{type: "text", content: %{"text" => "y"}})
    {:ok, _} = Chat.pin_message(owner.id, m1)
    {:ok, _} = Chat.pin_message(owner.id, m2)
    gp = Chat.fetch_pinned_group_messages(group.id, 50)
    assert length(gp) == 2

    {:ok, dm} = Chat.dm_create(owner.id, other.id)
    {:ok, md} = Chat.dm_send_message(owner.id, dm.id, %{type: "text", content: %{"text" => "z"}})
    {:ok, _} = Chat.pin_message(owner.id, md)
    dp = Chat.fetch_pinned_dm_messages(dm.id, 50)
    assert length(dp) == 1
  end

  test "owner cannot leave group" do
    {:ok, owner} = Accounts.register_user(%{username: "lv_own", password: "secret"})
    {:ok, group} = Chat.create_group(owner.id, %{"name" => "lv"})
    assert {:error, :owner_cannot_leave} = Chat.leave_group(group, owner.id)
  end
end
