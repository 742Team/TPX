defmodule TpxServer.Accounts do
  alias TpxServer.Repo
  alias TpxServer.Accounts.User

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate(username, password) do
    user = Repo.get_by(User, username: username)

    case user do
      nil ->
        {:error, :invalid}

      %User{} ->
        if Bcrypt.verify_pass(password, user.password_hash),
          do: {:ok, user},
          else: {:error, :invalid}
    end
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def update_photo(user, url) do
    user
    |> User.profile_changeset(%{photo: url})
    |> Repo.update()
  end

  def update_background(user, value) do
    user
    |> User.profile_changeset(%{background: value})
    |> Repo.update()
  end

  def update_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def update_status(user, status) do
    user
    |> User.status_changeset(%{status: status})
    |> Repo.update()
  end

  def block_user(user, target_id) do
    blocked = Enum.uniq(user.blocked_users ++ [target_id])
    user |> Ecto.Changeset.change(%{blocked_users: blocked}) |> Repo.update()
  end

  def unblock_user(user, target_id) do
    blocked = Enum.filter(user.blocked_users, &(&1 != target_id))
    user |> Ecto.Changeset.change(%{blocked_users: blocked}) |> Repo.update()
  end
end
