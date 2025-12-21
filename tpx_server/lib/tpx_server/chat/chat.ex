defmodule TpxServer.Chat do
  import Ecto.Query
  alias TpxServer.Repo
  alias TpxServer.Chat.Group
  alias TpxServer.Chat.Message
  alias TpxServer.Chat.DirectMessage
  alias TpxServer.Accounts

  def create_group(owner_id, attrs) do
    attrs =
      Map.merge(%{"owner_id" => owner_id, "members" => [owner_id], "admins" => [owner_id]}, attrs)
      |> maybe_put_join_hash()

    %Group{} |> Group.create_changeset(attrs) |> Repo.insert()
  end

  def get_group(id), do: Repo.get(Group, id)

  def get_group_by_name(name) do
    from(g in Group, where: ilike(g.name, ^name), order_by: [asc: g.inserted_at], limit: 1)
    |> Repo.one()
  end

  def list_user_groups(user_id) do
    from(g in Group,
      where: fragment("? = ANY(?)", type(^user_id, :binary_id), g.members),
      order_by: [asc: g.inserted_at]
    )
    |> Repo.all()
  end

  def update_group(%Group{} = group, attrs) do
    group |> Ecto.Changeset.change(to_atom_keys(attrs)) |> Repo.update()
  end

  def add_member(group, user_id) do
    update_members(group, Enum.uniq(group.members ++ [user_id]))
  end

  def kick_member(group, user_id) do
    update_members(group, Enum.filter(group.members, &(&1 != user_id)))
  end

  def ban_user(group, user_id) do
    banned = Enum.uniq(group.banned_users ++ [user_id])
    members = Enum.filter(group.members, &(&1 != user_id))
    group |> Ecto.Changeset.change(%{banned_users: banned, members: members}) |> Repo.update()
  end

  def unban_user(group, user_id) do
    banned = Enum.filter(group.banned_users, &(&1 != user_id))
    group |> Ecto.Changeset.change(%{banned_users: banned}) |> Repo.update()
  end

  defp update_members(group, members) do
    group |> Ecto.Changeset.change(%{members: members}) |> Repo.update()
  end

  def can_manage?(group, user_id), do: user_id == group.owner_id or user_id in group.admins

  def owner_only?(group, user_id), do: user_id == group.owner_id

  def promote_admin(group, user_id) do
    admins = Enum.uniq(group.admins ++ [user_id])
    group |> Ecto.Changeset.change(%{admins: admins}) |> Repo.update()
  end

  def demote_admin(group, user_id) do
    admins = Enum.filter(group.admins, &(&1 != user_id))
    group |> Ecto.Changeset.change(%{admins: admins}) |> Repo.update()
  end

  def leave_group(group, user_id) do
    if user_id == group.owner_id do
      {:error, :owner_cannot_leave}
    else
      admins = Enum.filter(group.admins, &(&1 != user_id))
      members = Enum.filter(group.members, &(&1 != user_id))
      group |> Ecto.Changeset.change(%{admins: admins, members: members}) |> Repo.update()
    end
  end

  def send_message(sender_id, group, attrs) do
    if sender_id in group.members and sender_id not in group.banned_users do
      case %Message{}
           |> Message.create_changeset(
             Map.merge(attrs, %{sender_id: sender_id, group_id: group.id})
           )
           |> Repo.insert() do
        {:ok, msg} ->
          _ = prune_group_messages(group, group.messages_retention)
          {:ok, msg}

        other ->
          other
      end
    else
      {:error, :forbidden}
    end
  end

  def fetch_messages(group_id, before_ts \\ nil, limit \\ 50) do
    from(m in Message,
      where: m.group_id == ^group_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> maybe_before(before_ts)
    |> Repo.all()
    |> Enum.reverse()
  end

  defp maybe_before(query, nil), do: query
  defp maybe_before(query, before_ts), do: from(m in query, where: m.inserted_at < ^before_ts)

  defp prune_group_messages(_group, nil), do: :ok
  defp prune_group_messages(_group, 0), do: :ok

  defp prune_group_messages(group, retention) when is_integer(retention) and retention > 0 do
    ids =
      from(m in Message,
        where: m.group_id == ^group.id,
        order_by: [desc: m.inserted_at],
        offset: ^retention,
        select: m.id
      )
      |> Repo.all()

    _ = from(m in Message, where: m.id in ^ids) |> Repo.delete_all()
    :ok
  end

  def dm_create(user_a, user_b) do
    {a, b} = sort_pair(user_a, user_b)

    case Repo.get_by(DirectMessage, user_a: a, user_b: b) do
      nil ->
        changeset = DirectMessage.create_changeset(%DirectMessage{}, %{user_a: a, user_b: b})
        case Repo.insert(changeset) do
          {:ok, dm} -> {:ok, dm}
          {:error, _} ->
            case Repo.get_by(DirectMessage, user_a: a, user_b: b) do
              nil -> {:error, :conflict}
              dm -> {:ok, dm}
            end
        end

      dm ->
        {:ok, dm}
    end
  end

  def dm_send_message(sender_id, dm_id, attrs) do
    case Repo.get(DirectMessage, dm_id) do
      nil ->
        {:error, :not_found}

      %DirectMessage{user_a: a, user_b: b} = dm ->
        if sender_id in [a, b] do
          other = if sender_id == a, do: b, else: a

          with %{} = su <- Accounts.get_user(sender_id),
               %{} = ou <- Accounts.get_user(other),
               false <- other in su.blocked_users or sender_id in ou.blocked_users do
            case %Message{}
                 |> Message.create_changeset(
                   Map.merge(attrs, %{sender_id: sender_id, dm_id: dm.id})
                 )
                 |> Repo.insert() do
              {:ok, msg} ->
                _ = Repo.update(Ecto.Changeset.change(dm, last_message_at: msg.inserted_at))
                {:ok, msg}

              other ->
                other
            end
          else
            _ -> {:error, :blocked}
          end
        else
          {:error, :forbidden}
        end
    end
  end

  def dm_fetch_messages(dm_id, before_ts \\ nil, limit \\ 50) do
    from(m in Message,
      where: m.dm_id == ^dm_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> maybe_before(before_ts)
    |> Repo.all()
    |> Enum.reverse()
  end

  def search_group_messages(group_id, q, limit \\ 50) do
    pattern = "%" <> q <> "%"

    from(m in Message,
      where:
        m.group_id == ^group_id and m.type == "text" and
          fragment("?->>'text' ILIKE ?", m.content, ^pattern),
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def search_dm_messages(dm_id, q, limit \\ 50) do
    pattern = "%" <> q <> "%"

    from(m in Message,
      where:
        m.dm_id == ^dm_id and m.type == "text" and
          fragment("?->>'text' ILIKE ?", m.content, ^pattern),
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def fetch_pinned_group_messages(group_id, limit \\ 50) do
    from(m in Message,
      where: m.group_id == ^group_id and m.pinned == true,
      order_by: [desc: m.pinned_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def fetch_pinned_dm_messages(dm_id, limit \\ 50) do
    from(m in Message,
      where: m.dm_id == ^dm_id and m.pinned == true,
      order_by: [desc: m.pinned_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  defp sort_pair(a, b) when a <= b, do: {a, b}
  defp sort_pair(a, b), do: {b, a}

  def get_message(id), do: Repo.get(Message, id)

  def edit_message(_user_id, %Message{deleted: true} = _msg, _attrs), do: {:error, :deleted}

  def edit_message(user_id, %Message{group_id: gid, sender_id: sid} = msg, attrs)
      when is_binary(gid) do
    group = get_group(gid)

    if user_id == sid or can_manage?(group, user_id) do
      changes =
        Map.merge(to_atom_keys(attrs), %{
          edited_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })

      msg |> Ecto.Changeset.change(changes) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def edit_message(user_id, %Message{dm_id: _did, sender_id: sid} = msg, attrs) do
    if user_id == sid do
      changes =
        Map.merge(to_atom_keys(attrs), %{
          edited_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })

      msg |> Ecto.Changeset.change(changes) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def delete_message(user_id, %Message{group_id: gid, sender_id: sid} = msg)
      when is_binary(gid) do
    group = get_group(gid)

    if user_id == sid or can_manage?(group, user_id) do
      msg |> Ecto.Changeset.change(%{deleted: true}) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def delete_message(user_id, %Message{dm_id: _did, sender_id: sid} = msg) do
    if user_id == sid do
      msg |> Ecto.Changeset.change(%{deleted: true}) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def pin_message(user_id, %Message{group_id: gid} = msg) when is_binary(gid) do
    group = get_group(gid)

    if can_manage?(group, user_id) do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      msg |> Ecto.Changeset.change(%{pinned: true, pinned_at: now}) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def pin_message(user_id, %Message{dm_id: did} = msg) when is_binary(did) do
    case Repo.get(DirectMessage, did) do
      nil ->
        {:error, :not_found}

      dm ->
        if user_id in [dm.user_a, dm.user_b] do
          now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          msg |> Ecto.Changeset.change(%{pinned: true, pinned_at: now}) |> Repo.update()
        else
          {:error, :forbidden}
        end
    end
  end

  def unpin_message(user_id, %Message{group_id: gid} = msg) when is_binary(gid) do
    group = get_group(gid)

    if can_manage?(group, user_id) do
      msg |> Ecto.Changeset.change(%{pinned: false, pinned_at: nil}) |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def unpin_message(user_id, %Message{dm_id: did} = msg) when is_binary(did) do
    case Repo.get(DirectMessage, did) do
      nil ->
        {:error, :not_found}

      dm ->
        if user_id in [dm.user_a, dm.user_b] do
          msg |> Ecto.Changeset.change(%{pinned: false, pinned_at: nil}) |> Repo.update()
        else
          {:error, :forbidden}
        end
    end
  end

  defp to_atom_keys(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      Map.put(acc, if(is_binary(k), do: String.to_atom(k), else: k), v)
    end)
  end

  defp maybe_put_join_hash(%{"join_password" => pw} = attrs) when is_binary(pw) and pw != "" do
    Map.put(attrs, "join_password_hash", Bcrypt.hash_pwd_salt(pw))
  end

  defp maybe_put_join_hash(attrs), do: attrs
end
